import 'package:flutterflow_live_activity/src/android/live_update_templates.dart';
import 'package:flutterflow_live_activity/src/dart/plugin_package.dart';
import 'package:flutterflow_live_activity/src/ios/image_store.dart';
import 'package:flutterflow_live_activity/src/ios/swift_templates.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// Every file [app]'s Live Activities need, path (relative to the app's root)
/// to content: the `ff_live_activity` plugin package under
/// `packages/ff_live_activity/` (its Dart API, its iOS and Android sides) and
/// the iOS widget extension under `ios/LiveActivity/`.
///
/// The app still needs, on its side: a path dependency on the plugin package
/// in its pubspec, the extension target in its Xcode project
/// ([liveActivityPbxprojFragments]), the entries of its
/// `ios/Runner/Info.plist` ([liveActivityRunnerInfoPlistEntries]) and, when a
/// card has an Image value, the shared keychain group in its entitlements
/// ([LiveActivityApp.keychainGroup]).
Map<String, String> generateLiveActivityFiles(LiveActivityApp app) => {
  ...liveActivityDartPackageFiles(app),
  ...liveActivityIosFiles(app),
  ...liveActivityAndroidFiles(app),
};

/// The entries Live Activities add to `ios/Runner/Info.plist`
/// (`NSSupportsLiveActivities`), as plist XML that goes inside the top-level
/// `<dict>`.
///
/// Without the key ActivityKit refuses every start request. It needs no
/// entitlement and no capability.
const kLiveActivityRunnerInfoPlistEntries = '''
    <key>NSSupportsLiveActivities</key>
    <true/>
''';

/// [kLiveActivityRunnerInfoPlistEntries] and, when a Custom card has an
/// Image value, the keychain group the app shares with the extension, so
/// the plugin knows it with the team prefix.
String liveActivityRunnerInfoPlistEntries(LiveActivityApp app) =>
    kLiveActivityRunnerInfoPlistEntries +
    liveActivityKeychainGroupInfoPlistEntry(app);
