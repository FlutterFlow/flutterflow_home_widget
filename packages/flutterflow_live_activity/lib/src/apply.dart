/// Writes an app's Live Activities into a Flutter app on disk.
library;

import 'dart:io';

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/dart/typed_api.dart';
import 'package:flutterflow_live_activity/src/generate.dart';
import 'package:flutterflow_live_activity/src/ios/flutter_project.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// Adds [app]'s Live Activities to the Flutter app at [appDir] (made by
/// `flutter create`, with `ios/` and `android/`):
///
/// - writes every generated file ([generateLiveActivityFiles]) and the
///   typed API ([liveActivityTypedApiFiles]);
/// - adds the `ff_live_activity` path dependency to `pubspec.yaml`;
/// - adds the Live Activity extension target to the Xcode project, and its
///   entries to the Runner's Info.plist; when a card has an Image value,
///   the keychain group to the Runner's entitlements.
///
/// Android needs nothing else: the plugin's manifest (its permissions) is
/// merged into the app's. Running it again rewrites only the files that
/// changed and leaves the rest as it is. Nothing is written when the
/// project cannot take the extension ([LiveActivityProjectException]), or
/// when `iosBundleId` does not match the Runner's bundle id in every build
/// configuration ([checkRunnerBundleId]). What cannot be checked, such as a
/// Runner id that is a build setting, goes to [onWarning].
/// Returns the paths it wrote, relative to [appDir].
List<String> applyLiveActivities(
  String appDir,
  LiveActivityApp app, {
  void Function(String warning)? onWarning,
}) {
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

  // Everything is worked out before anything is written, so a project
  // that cannot take the extension is left as it was.
  final files = {
    ...generateLiveActivityFiles(app),
    ...liveActivityTypedApiFiles(app),
    'pubspec.yaml': _withPluginDependency(read('pubspec.yaml')),
  };
  if (Directory('$appDir/ios').existsSync()) {
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
    final project = read(pbxproj);
    checkRunnerBundleId(project, app).forEach(onWarning ?? (_) {});
    files[pbxproj] = addLiveActivityTarget(project, app);
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
  return written;
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
