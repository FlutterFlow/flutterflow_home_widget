/// Live Activities for a Flutter app, generated from one spec: iOS
/// ActivityKit cards (lock screen and Dynamic Island) and Android Live
/// Updates.
///
/// Build a [LiveActivityApp] and pass it to [generateLiveActivityFiles] for
/// every file the app needs: the `ff_live_activity` plugin package (Dart,
/// Swift, Kotlin) and the iOS widget extension, with each Custom card's
/// layouts drawn natively. [liveActivityPbxprojFragments] adds the extension
/// target to the app's Xcode project.
library;

export 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
export 'src/android/custom_card_templates.dart'
    show
        liveActivityAndroidCustomFiles,
        liveActivityAndroidStandardTimed,
        liveActivityAndroidTapDroppingDrawing,
        liveActivityHasDrawnCustomCards;
export 'src/android/live_update_templates.dart' show liveActivityAndroidFiles;
export 'src/card_height.dart';
export 'src/contract.dart';
export 'src/dart/plugin_package.dart';
export 'src/dart/typed_api.dart';
export 'src/generate.dart';
export 'src/ios/custom_cards.dart';
export 'src/ios/image_store.dart';
export 'src/ios/pbxproj_fragments.dart';
export 'src/ios/swift_templates.dart';
export 'src/json.dart';
export 'src/spec.dart';
export 'src/validate.dart';
