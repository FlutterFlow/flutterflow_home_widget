/// Writes an app's Live Activities into a Flutter app on disk.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/dart/typed_api.dart';
import 'package:flutterflow_live_activity/src/generate.dart';
import 'package:flutterflow_live_activity/src/ios/flutter_project.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// Where `apply` records the files it generated, relative to the app: every
/// path with the SHA-256 of the content it wrote. Keep it with the app's
/// sources; `apply` reads it to tell what it wrote from what you did.
const kLiveActivityManifestPath = '.flutterflow_live_activity_manifest.json';

/// Adds [app]'s Live Activities to the Flutter app at [appDir] (made by
/// `flutter create`, with `ios/` and `android/`):
///
/// - writes every generated file ([generateLiveActivityFiles]) and the
///   typed API ([liveActivityTypedApiFiles]);
/// - adds the `ff_live_activity` path dependency to `pubspec.yaml`;
/// - adds the Live Activity extension target to the Xcode project, and its
///   entries to the Runner's Info.plist; when a card has an Image value,
///   the keychain group to the Runner's entitlements;
/// - records the generated files in [kLiveActivityManifestPath].
///
/// Android needs nothing else: the plugin's manifest (its permissions) is
/// merged into the app's. Running it again rewrites only the files that
/// changed and leaves the rest as it is.
///
/// A file the previous run recorded that the spec no longer generates (the
/// files of a Custom card taken out of the spec) is deleted, with the
/// Xcode entries that compile it, and its folders when they end up empty
/// ([onRemoved] gets its path). It is deleted only when its content is still
/// what was recorded: a file changed since is left where it is, with its
/// Xcode entries, and goes to [onWarning]. Without a manifest (an app
/// applied before there was one) or with one that cannot be read nothing is
/// deleted. Files `apply` only edits (`pubspec.yaml`, `project.pbxproj`,
/// `Info.plist`, `Runner.entitlements`) are never deleted, and only the
/// Xcode entries of a deleted file are taken out of them.
///
/// Nothing is written or deleted when the project cannot take the extension
/// ([LiveActivityProjectException]), or when `iosBundleId` does not match
/// the Runner's bundle id in every build configuration
/// ([checkRunnerBundleId]). What cannot be checked, such as a Runner id
/// that is a build setting, goes to [onWarning].
/// Returns the paths it wrote, relative to [appDir].
List<String> applyLiveActivities(
  String appDir,
  LiveActivityApp app, {
  void Function(String warning)? onWarning,
  void Function(String path)? onRemoved,
}) {
  final warn = onWarning ?? (_) {};
  final written = <String>[];
  void write(String path, String content) {
    final file = File('$appDir/$path');
    if (file.existsSync() && file.readAsStringSync() == content) {
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    written.add(path);
  }

  String read(String path) {
    final file = File('$appDir/$path');
    if (!file.existsSync()) {
      throw LiveActivityProjectException('$appDir has no $path.');
    }
    return file.readAsStringSync();
  }

  // Everything is worked out before anything is written or deleted, so a
  // project that cannot take the extension is left as it was.
  final generated = {
    ...generateLiveActivityFiles(app),
    ...liveActivityTypedApiFiles(app),
  };
  final stale = _staleFiles(appDir, generated.keys.toSet(), warn);
  final files = {
    ...generated,
    'pubspec.yaml': _withPluginDependency(read('pubspec.yaml')),
  };
  if (Directory('$appDir/ios').existsSync()) {
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
    final project = read(pbxproj);
    checkRunnerBundleId(project, app).forEach(warn);
    files[pbxproj] = addLiveActivityTarget(
      project,
      app,
      removedFiles: stale.remove.toSet(),
      keptFiles: stale.keep.keys.toSet(),
    );
    const infoPlist = 'ios/Runner/Info.plist';
    files[infoPlist] = addLiveActivityInfoPlistEntries(read(infoPlist), app);
    if (app.hasImageValues) {
      const entitlements = 'ios/$kLiveActivityRunnerEntitlementsPath';
      final existing = File('$appDir/$entitlements');
      files[entitlements] = liveActivityRunnerEntitlements(
        existing.existsSync() ? existing.readAsStringSync() : null,
        app,
      );
    }
  }
  for (final MapEntry(:key, :value) in files.entries) {
    write(key, value);
  }
  for (final path in stale.remove) {
    final file = File('$appDir/$path');
    if (file.existsSync()) {
      file.deleteSync();
      onRemoved?.call(path);
    }
    _deleteEmptyFolders(appDir, path);
  }
  write(kLiveActivityManifestPath, _manifestJson(generated, stale.keep));
  return written;
}

/// The files the manifest lists that [current] does not: [remove] (paths,
/// to delete: unchanged since written or already gone) and [keep] (path to
/// the recorded hash: changed since, so left alone).
({List<String> remove, Map<String, String> keep}) _staleFiles(
  String appDir,
  Set<String> current,
  void Function(String warning) warn,
) {
  final remove = <String>[];
  final keep = <String, String>{};
  final manifest = File('$appDir/$kLiveActivityManifestPath');
  if (!manifest.existsSync()) {
    return (remove: remove, keep: keep);
  }
  final Map<String, String> recorded;
  try {
    final json = jsonDecode(manifest.readAsStringSync());
    recorded = {
      for (final MapEntry(:key, :value)
          in ((json as Map<String, Object?>)['files'] as Map<String, Object?>)
              .entries)
        key: value as String,
    };
  } on Object {
    warn(
      '$kLiveActivityManifestPath cannot be read, so no file of an earlier '
      'apply was removed.',
    );
    return (remove: remove, keep: keep);
  }
  for (final MapEntry(key: path, value: hash) in recorded.entries) {
    if (current.contains(path)) {
      continue;
    }
    if (!_isOwned(path)) {
      warn(
        '$kLiveActivityManifestPath lists "$path", which is not a generated '
        'file; ignored.',
      );
      continue;
    }
    final file = File('$appDir/$path');
    if (FileSystemEntity.isLinkSync(file.path)) {
      keep[path] = hash;
      warn('$path is a link, not a file apply wrote; left in place.');
    } else if (!file.existsSync()) {
      remove.add(path);
    } else if (_sha256(file.readAsBytesSync()) == hash) {
      remove.add(path);
    } else {
      keep[path] = hash;
      warn('$path changed since it was generated; left in place.');
    }
  }
  return (remove: remove, keep: keep);
}

/// The folders `apply` owns: it only ever deletes files in them.
const _ownedFolders = [
  'ios/$kLiveActivityIosExtensionTarget/',
  'packages/$kLiveActivityPluginPackage/',
];

/// Whether [path] is a relative path that stays inside a folder `apply`
/// owns, so a manifest that lists anything else (`pubspec.yaml`, a path
/// outside the app) never gets it deleted.
bool _isOwned(String path) =>
    _ownedFolders.any(path.startsWith) &&
    !path.contains('\\') &&
    !path.split('/').any((part) => part.isEmpty || part == '.' || part == '..');

String _sha256(List<int> bytes) => sha256.convert(bytes).toString();

/// The manifest: the hash of every generated file, and of the changed
/// files still left in place (so they are reported until you remove them).
String _manifestJson(Map<String, String> generated, Map<String, String> kept) {
  final hashes = {
    for (final MapEntry(:key, :value) in generated.entries)
      key: _sha256(utf8.encode(value)),
    ...kept,
  };
  final sorted = Map.fromEntries(
    hashes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  return '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'files': sorted})}\n';
}

/// Deletes the folders [path] was in, innermost first, while they are empty.
/// Never [appDir], and never a folder with anything in it.
void _deleteEmptyFolders(String appDir, String path) {
  var parts = path.split('/')..removeLast();
  while (parts.isNotEmpty) {
    final dir = Directory('$appDir/${parts.join('/')}');
    if (!dir.existsSync() || dir.listSync().isNotEmpty) {
      return;
    }
    dir.deleteSync();
    parts = parts..removeLast();
  }
}

/// [pubspec] with the plugin package as a path dependency.
String _withPluginDependency(String pubspec) {
  if (RegExp(
    '^  $kLiveActivityPluginPackage:',
    multiLine: true,
  ).hasMatch(pubspec)) {
    return pubspec;
  }
  final match = RegExp(
    r'^dependencies:\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw LiveActivityProjectException('pubspec.yaml has no dependencies.');
  }
  return '${pubspec.substring(0, match.end)}\n'
      '  $kLiveActivityPluginPackage:\n'
      '    path: $kLiveActivityPluginPackagePath'
      '${pubspec.substring(match.end)}';
}
