/// Writes an app's home screen widgets into a Flutter app on disk.
library;

import 'dart:io';

import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/generate.dart';
import 'package:flutterflow_home_widget/src/ios/flutter_project.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Adds [app]'s home screen widgets to the Flutter app at [appDir] (made by
/// `flutter create`, with `ios/` and `android/`):
///
/// - writes every generated file ([generateHomeWidgetFiles]);
/// - adds the `ff_home_widget` path dependency to `pubspec.yaml`;
/// - adds the widget extension target to the Xcode project, and the
///   keychain group to the Runner's Info.plist and entitlements.
///
/// Android needs nothing else: the plugin's manifest is merged into the
/// app's. Running it again rewrites the generated files and leaves the rest
/// as it is. Returns the paths it wrote, relative to [appDir].
List<String> applyHomeWidgets(String appDir, HomeWidgetApp app) {
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
      throw HomeWidgetProjectException('$appDir has no $path.');
    }
    return file.readAsStringSync();
  }

  for (final MapEntry(:key, :value) in generateHomeWidgetFiles(app).entries) {
    write(key, value);
  }
  write('pubspec.yaml', _withPluginDependency(read('pubspec.yaml')));
  if (Directory('$appDir/ios').existsSync()) {
    const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
    write(pbxproj, addHomeWidgetTarget(read(pbxproj), app));
    const infoPlist = 'ios/Runner/Info.plist';
    write(infoPlist, addHomeWidgetInfoPlistEntries(read(infoPlist), app));
    const entitlements = 'ios/$kHomeWidgetRunnerEntitlementsPath';
    final existing = File('$appDir/$entitlements');
    write(
      entitlements,
      homeWidgetRunnerEntitlements(
        existing.existsSync() ? existing.readAsStringSync() : null,
        app,
      ),
    );
  }
  return written;
}

/// [pubspec] with the plugin package as a path dependency.
String _withPluginDependency(String pubspec) {
  if (RegExp(
    '^  $kHomeWidgetPluginPackage:',
    multiLine: true,
  ).hasMatch(pubspec)) {
    return pubspec;
  }
  final match = RegExp(
    r'^dependencies:\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw HomeWidgetProjectException('pubspec.yaml has no dependencies.');
  }
  return '${pubspec.substring(0, match.end)}\n'
      '  $kHomeWidgetPluginPackage:\n'
      '    path: $kHomeWidgetPluginPackagePath'
      '${pubspec.substring(match.end)}';
}
