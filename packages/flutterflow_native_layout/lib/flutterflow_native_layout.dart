/// The layout model native home screen widgets and Live Activities are drawn
/// from, its two emitters (SwiftUI for iOS, RemoteViews for Android), the
/// escaping they share, and the Swift and Kotlin run time their generated
/// code calls, as source text.
///
/// Pure Dart: no Flutter, no I/O. A tool builds a [NativeLayoutModel] from
/// its own spec or design, then writes each platform's code with
/// [swiftLayoutView] and [remoteViewsLayout], and puts the run time
/// ([nativeLayoutSwiftBuildingBlocks], [nativeLayoutKotlinViews] and the
/// constants next to them) in the extension or module once.
///
/// A spec written as JSON reads and writes its layouts with the functions of
/// `package:flutterflow_native_layout/layout_json.dart`.
library;

export 'src/android/kotlin_runtime.dart';
export 'src/escape.dart';
export 'src/ios/swift_runtime.dart';
export 'src/ios/swift_runtime_timed.dart';
export 'src/layout/layout_model.dart';
export 'src/layout/remote_views_emitter.dart';
export 'src/layout/stage_label_colors.dart';
export 'src/layout/swiftui_emitter.dart';
