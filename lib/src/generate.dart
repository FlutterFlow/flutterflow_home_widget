import 'package:flutterflow_home_widget/src/android/app_widget_templates.dart';
import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/dart/plugin_package.dart';
import 'package:flutterflow_home_widget/src/ios/pbxproj_fragments.dart';
import 'package:flutterflow_home_widget/src/ios/swift_templates.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Every file [app]'s home screen widgets need, path (relative to the app's
/// root) to content: the `ff_home_widget` plugin package under
/// `packages/ff_home_widget/` (its Dart API, its iOS and Android sides) and
/// the iOS widget extension under `ios/HomeWidget/`.
///
/// The app still needs, on its side: a path dependency on the plugin package
/// in its pubspec, the extension target in its Xcode project
/// ([homeWidgetPbxprojFragments]), and the keychain group in the Runner's
/// Info.plist and entitlements ([homeWidgetRunnerInfoPlistEntries],
/// [homeWidgetRunnerEntitlementEntries]).
Map<String, String> generateHomeWidgetFiles(HomeWidgetApp app) => {
  ...homeWidgetDartPackageFiles(app),
  ...homeWidgetIosFiles(app),
  ...homeWidgetAndroidFiles(app),
};

/// The entries the app's `ios/Runner/Info.plist` needs: the shared keychain
/// group, so the plugin knows it with the team prefix. Goes inside the
/// top-level `<dict>`.
String homeWidgetRunnerInfoPlistEntries(HomeWidgetApp app) =>
    '''
    <key>$kHomeWidgetKeychainGroupInfoPlistKey</key>
    <string>${app.keychainGroup}</string>
''';

/// The entries the app's `ios/Runner/Runner.entitlements` needs: the app's
/// own keychain group first (so its default group does not change), then
/// the group it shares with the widget extension. Goes inside the top-level
/// `<dict>`.
String homeWidgetRunnerEntitlementEntries(HomeWidgetApp app) =>
    '''

	<key>keychain-access-groups</key>
	<array>
		<string>${app.appKeychainGroup}</string>
		<string>${app.keychainGroup}</string>
	</array>''';
