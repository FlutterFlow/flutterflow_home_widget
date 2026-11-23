import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Path of the plugin package's pubspec in the generated app.
const kHomeWidgetPluginPubspecPath =
    '$kHomeWidgetPluginPackagePath/pubspec.yaml';

/// Path of the plugin package's Dart library in the generated app.
const kHomeWidgetPluginDartPath =
    '$kHomeWidgetPluginPackagePath/lib/$kHomeWidgetPluginPackage.dart';

/// The Dart files of the `ff_home_widget` plugin package, path (relative to
/// the app's root) to content.
Map<String, String> homeWidgetDartPackageFiles(HomeWidgetApp app) => {
  kHomeWidgetPluginPubspecPath: homeWidgetPluginPubspec(),
  kHomeWidgetPluginDartPath: homeWidgetPluginDartLibrary(app.iconCodePoints),
};

/// `pubspec.yaml` of the plugin package.
String homeWidgetPluginPubspec() =>
    '''
name: $kHomeWidgetPluginPackage
description: FlutterFlow home screen widget bridge (iOS WidgetKit, Android app widgets). Generated with the app; not published.
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.10.0"

dependencies:
  flutter:
    sdk: flutter

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: $kHomeWidgetPluginClass
      android:
        package: $kHomeWidgetAndroidPackage
        pluginClass: $kHomeWidgetPluginClass
''';

/// `lib/ff_home_widget.dart` of the plugin package: class `FFHomeWidget` over
/// the contract's method channel. [iconCodePoints] are the Material Icons the
/// widgets draw: the library holds them as constants so release builds keep
/// their glyphs in the icon font the native widgets draw from.
String homeWidgetPluginDartLibrary([Set<int> iconCodePoints = const {}]) {
  final icons = [
    for (final codePoint in iconCodePoints.toList()..sort())
      "  IconData(0x${codePoint.toRadixString(16)}, fontFamily: 'MaterialIcons'),",
  ];
  return '''
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Color, IconData;

/// The Material Icons the home screen widgets draw. Flutter's icon tree
/// shaking keeps only the glyphs it finds as constants, and the native
/// widgets draw from the same font, so they are listed here. Nothing in Dart
/// reads the list: the pragma keeps release builds from dropping it.
@pragma('vm:entry-point')
const kFFHomeWidgetIcons = <IconData>[
${icons.join('\n')}
];

/// Shows new values on the app's home screen widgets (iOS $kHomeWidgetMinIosVersion+,
/// Android).
///
/// A widget is named by its `definitionKey`. Each [update] replaces what the
/// widget shows, and the widget keeps showing it after the app closes, until
/// the next [update] or [clear].
///
/// Values travel as strings, keyed by parameter key. Use the `encode`
/// helpers for values that are not text. A null value is left out and the
/// widget shows the parameter's default.
///
/// On web, desktop and any device without home screen widgets every call does
/// nothing and completes normally. No call throws.
class $kHomeWidgetDartClass {
  $kHomeWidgetDartClass._();

  static const MethodChannel _channel = MethodChannel(
    '$kHomeWidgetChannelName',
  );

  static bool get _hasNativeSide =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether the device can show home screen widgets.
  static Future<bool> isSupported() async =>
      await _invoke<bool>('$kHomeWidgetMethodIsSupported') ?? false;

  /// Shows [values] on every copy of the widget on the home screen. Returns
  /// false when they could not be stored.
  ///
  /// With a [choiceId], the values show only on the copies showing that
  /// choice, over the values every copy shares. A choice that isn't set in
  /// FlutterFlow is added to the picker, named [choiceName] (else its id).
  static Future<bool> update({
    required String definitionKey,
    Map<String, String?> values = const {},
    String? choiceId,
    String? choiceName,
  }) async =>
      await _invoke<bool>('$kHomeWidgetMethodUpdate', {
        '$kHomeWidgetArgDefinitionKey': definitionKey,
        '$kHomeWidgetArgValues': {
          for (final entry in values.entries)
            if (entry.value != null) entry.key: entry.value!,
        },
        if (choiceId != null && choiceId.isNotEmpty)
          '$kHomeWidgetArgChoiceId': choiceId,
        if (choiceName != null && choiceName.isNotEmpty)
          '$kHomeWidgetArgChoiceName': choiceName,
      }) ??
      false;

  /// Removes the stored values: the widget goes back to its placeholder text,
  /// and the choices the app added leave the picker. With a [choiceId], only
  /// that choice's values go, and it leaves the picker.
  static Future<void> clear({
    required String definitionKey,
    String? choiceId,
  }) async {
    await _invoke<void>('$kHomeWidgetMethodClear', {
      '$kHomeWidgetArgDefinitionKey': definitionKey,
      if (choiceId != null && choiceId.isNotEmpty)
        '$kHomeWidgetArgChoiceId': choiceId,
    });
  }

  /// A number as the widget reads it: '0.5', '1.0'. Null (left out) for null
  /// and for a value that is not finite.
  static String? encodeDouble(num? value) =>
      value == null || !value.isFinite ? null : value.toDouble().toString();

  /// A whole number as the widget reads it: '42'. A fraction is rounded.
  static String? encodeInt(num? value) =>
      value == null || !value.isFinite ? null : value.round().toString();

  /// 'true' or 'false'.
  static String? encodeBool(bool? value) => value?.toString();

  /// A point in time as the widget reads it: milliseconds since the Unix
  /// epoch.
  static String? encodeDateTime(DateTime? value) =>
      value?.millisecondsSinceEpoch.toString();

  /// A colour as the widget reads it: '#AARRGGBB'.
  static String? encodeColor(Color? value) => value == null
      ? null
      : '#\${value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  // Every failure ends here: a platform without the plugin, a native error,
  // an unexpected result type. An action chain that calls this never breaks
  // because the widget could not be updated.
  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (!_hasNativeSide) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      debugPrint('$kHomeWidgetDartClass.\$method failed: \$e');
      return null;
    }
  }
}
''';
}
