/// Home screen widgets for a Flutter app, generated from one spec.
///
/// Build a [HomeWidgetApp] (in Dart, or from JSON with [homeWidgetAppFromJson])
/// and pass it to [generateHomeWidgetFiles] for every file the app needs:
/// the `ff_home_widget` plugin package (Dart, Swift, Kotlin), the iOS widget
/// extension and each layout drawn natively. [homeWidgetPbxprojFragments]
/// adds the extension target to the app's Xcode project.
library;

export 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
export 'src/android/app_widget_templates.dart'
    show homeWidgetAndroidFiles, kHomeWidgetNoChoicesText;
export 'src/contract.dart';
export 'src/dart/plugin_package.dart'
    show
        homeWidgetDartPackageFiles,
        homeWidgetPluginDartLibrary,
        homeWidgetPluginPubspec,
        kHomeWidgetPluginDartPath,
        kHomeWidgetPluginPubspecPath;
export 'src/generate.dart';
export 'src/ios/flutter_project.dart';
export 'src/ios/pbxproj_fragments.dart';
export 'src/ios/swift_templates.dart';
export 'src/json.dart';
export 'src/refresh.dart';
export 'src/spec.dart';
export 'src/validate.dart';
