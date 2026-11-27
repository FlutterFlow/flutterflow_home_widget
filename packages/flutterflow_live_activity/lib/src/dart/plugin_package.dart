import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// Path of the plugin package's pubspec in the generated app.
const kLiveActivityPluginPubspecPath =
    '$kLiveActivityPluginPackagePath/pubspec.yaml';

/// Path of the plugin package's Dart library in the generated app.
const kLiveActivityPluginDartPath =
    '$kLiveActivityPluginPackagePath/lib/$kLiveActivityPluginPackage.dart';

/// The Dart files of the `ff_live_activity` plugin package, path (relative to
/// the app's root) to content: its `pubspec.yaml` and
/// `lib/ff_live_activity.dart`. Names, channel and keys come from
/// `contract.dart`.
///
/// The files depend on the contract and on what the app's Custom cards are:
/// whether it has one ([LiveActivityApp.hasCustomCards]) and the icons they
/// draw. The definition's fields travel as arguments of each call.
Map<String, String> liveActivityDartPackageFiles(LiveActivityApp app) => {
  kLiveActivityPluginPubspecPath: liveActivityPluginPubspec(),
  kLiveActivityPluginDartPath: liveActivityPluginDartLibrary(
    custom: app.hasCustomCards,
    iconCodePoints: liveActivityCardIconCodePoints(app),
  ),
};

/// Every Material Icons code point the layouts of [app]'s Custom cards draw:
/// their icons, the tracker and stage icons of their Stages bars, and the
/// mark of a done stage. The native cards draw them from the app's icon
/// font, and a release build keeps only the glyphs it finds as constants in
/// the Dart code, so the plugin library lists them. Empty without a Custom
/// card that draws one.
Set<int> liveActivityCardIconCodePoints(LiveActivityApp app) {
  final codePoints = <int>{};
  for (final card in app.customCards) {
    for (final (_, model) in card.layouts) {
      for (final node in model.nodes) {
        if (node case LayoutIcon(:final codePoint)) {
          codePoints.add(codePoint);
        }
        if (node case LayoutProgress(:final stages?)) {
          codePoints.addAll([
            LayoutStages.doneCodePoint,
            if (stages.trackerCodePoint != null) stages.trackerCodePoint!,
            for (final stage in stages.stages)
              if (stage.iconCodePoint != null) stage.iconCodePoint!,
          ]);
        }
      }
    }
  }
  return codePoints;
}

/// `pubspec.yaml` of the plugin package. It names the plugin class of both
/// platforms; the Swift and Kotlin sides are generated into the same package.
String liveActivityPluginPubspec() => '''
name: $kLiveActivityPluginPackage
description: FlutterFlow Live Activity (iOS) and Live Update (Android) bridge. Generated with the app; not published.
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
        pluginClass: $kLiveActivityPluginClass
      android:
        package: $kLiveActivityAndroidPackage
        pluginClass: $kLiveActivityPluginClass
''';

/// The constants that keep the cards' icons in the app's icon font; empty
/// when no card draws one, so the library is then what it was.
String _iconsBlock(Set<int> codePoints) {
  if (codePoints.isEmpty) {
    return '';
  }
  final icons = [
    for (final codePoint in codePoints.toList()..sort())
      "  IconData(0x${codePoint.toRadixString(16)}, fontFamily: 'MaterialIcons'),",
  ];
  return '''
import 'package:flutter/widgets.dart' show IconData;

/// The Material Icons the Custom cards draw. Flutter's icon tree shaking
/// keeps only the glyphs it finds as constants, and the native cards draw
/// from the same font, so they are listed here. Nothing in Dart reads the
/// list: the entry-point mark keeps the compiler from dropping it first.
@pragma('vm:entry-point')
const kFFLiveActivityIcons = <IconData>[
${icons.join('\n')}
];
''';
}

/// `lib/ff_live_activity.dart` of the plugin package: class `FFLiveActivity`
/// over the contract's method channel. With [custom] it also carries what a
/// Custom card needs: pictures, defaults and the Boolean and Color encoders.
/// Without it the text is what it was before Custom cards existed.
String liveActivityPluginDartLibrary({
  bool custom = false,
  Set<int> iconCodePoints = const {},
}) => '''
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
${_iconsBlock(iconCodePoints)}
/// Starts, updates and ends a Live Activity (iOS $kLiveActivityMinIosVersion+) or a Live Update
/// (Android: a promoted ongoing notification on Android 16+, an ordinary
/// ongoing notification below that).
///
/// A live activity is named by its `definitionKey`. Pass an `instanceId` to
/// run several cards of one live activity side by side; without it there is
/// one card, and starting again replaces it.
///
/// Values travel as strings. Use [$kLiveActivityEncodeDouble], [$kLiveActivityEncodeInt] and
/// [$kLiveActivityEncodeDateTime] for values that are not text. A null value is left out:
/// on update the card keeps what it showed before.
///${custom ? _customClassDoc : ''}
/// On web, desktop and any device that cannot show the card, every call does
/// nothing and completes normally. No call throws.
class $kLiveActivityDartClass {
  $kLiveActivityDartClass._();

  static const MethodChannel _channel = MethodChannel(
    '$kLiveActivityChannelName',
  );

  static bool get _hasNativeSide =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether the device can show the card right now (OS version, and the
  /// user has not turned Live Activities or notifications off for the app).
  static Future<bool> isSupported() async =>
      await _invoke<bool>('$kLiveActivityMethodIsSupported') ?? false;

  /// Starts the card. Returns false when the device cannot show it.
  static Future<bool> start({
    required String definitionKey,
    required String template,
    String? instanceId,
    String? accentColor,
    String? icon,
    String? androidChannelName,
    Map<String, String?> values = const {},${custom ? _customStartParams : ''}
  }) async =>
      await _invoke<bool>('$kLiveActivityMethodStart', {
        '$kLiveActivityArgDefinitionKey': definitionKey,
        if (_isSet(instanceId)) '$kLiveActivityArgInstanceId': instanceId,
        '$kLiveActivityArgTemplate': template,
        if (_isSet(accentColor)) '$kLiveActivityArgAccentColor': accentColor,
        if (_isSet(icon)) '$kLiveActivityArgIcon': icon,
        if (_isSet(androidChannelName))
          '$kLiveActivityArgAndroidChannelName': androidChannelName,
        '$kLiveActivityArgValues': ${custom ? '{...$kLiveActivityDartArgDefaults, ..._withoutNulls(values)}' : '_withoutNulls(values)'},${custom ? _customImagesEntry : ''}
      }) ??
      false;

  /// Changes the values in [values] on the running card and keeps the rest.
  /// Returns false when no matching card is running.
  static Future<bool> update({
    required String definitionKey,
    String? instanceId,
    Map<String, String?> values = const {},${custom ? _customImagesParam : ''}
  }) async =>
      await _invoke<bool>('$kLiveActivityMethodUpdate', {
        '$kLiveActivityArgDefinitionKey': definitionKey,
        if (_isSet(instanceId)) '$kLiveActivityArgInstanceId': instanceId,
        '$kLiveActivityArgValues': _withoutNulls(values),${custom ? _customImagesEntry : ''}
      }) ??
      false;

  /// Ends the running card. [values] is the last content it shows.
  /// [dismissal] is '$kLiveActivityDismissalImmediate' (remove the card right away, the default) or
  /// '$kLiveActivityDismissalSystemDefault' (leave it until the system removes it). Ending a card that is
  /// not running does nothing.
  static Future<void> end({
    required String definitionKey,
    String? instanceId,
    Map<String, String?> values = const {},${custom ? _customImagesParam : ''}
    String? dismissal,
  }) async {
    final finalValues = _withoutNulls(values);
    await _invoke<void>('$kLiveActivityMethodEnd', {
      '$kLiveActivityArgDefinitionKey': definitionKey,
      if (_isSet(instanceId)) '$kLiveActivityArgInstanceId': instanceId,
      if (finalValues.isNotEmpty) '$kLiveActivityArgValues': finalValues,${custom ? _customEndImagesEntry : ''}
      if (_isSet(dismissal)) '$kLiveActivityArgDismissal': dismissal,
    });
  }

  /// A number as the card reads it: '0.5', '1.0'. Null (left out) for null
  /// and for a value that is not finite.
  static String? $kLiveActivityEncodeDouble(num? value) =>
      value == null || !value.isFinite ? null : value.toDouble().toString();

  /// A whole number as the card reads it: '42'. A fraction is rounded.
  static String? $kLiveActivityEncodeInt(num? value) =>
      value == null || !value.isFinite ? null : value.round().toString();

  /// A point in time as the card reads it: milliseconds since the Unix epoch.
  static String? $kLiveActivityEncodeDateTime(DateTime? value) =>
      value?.millisecondsSinceEpoch.toString();
${custom ? _customHelpers : ''}
  static bool _isSet(String? value) => value != null && value.isNotEmpty;

  static Map<String, String> _withoutNulls(Map<String, String?> values) => {
    for (final entry in values.entries)
      if (entry.value != null) entry.key: entry.value!,
  };

  // Every failure ends here: a platform without the plugin, a native error,
  // an unexpected result type. An action chain that calls this never breaks
  // because the card could not be shown.
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
      debugPrint('$kLiveActivityDartClass.\$method failed: \$e');
      return null;
    }
  }
}
''';

const _customClassDoc = '''

///
/// A Custom card's pictures go in `$kLiveActivityArgImages`, keyed like its values: wrap
/// each one in [$kLiveActivityEncodeImage]. The device shrinks and stores the picture; a
/// picture that cannot be loaded leaves the card's fallback in place.''';

const _customImagesParam = '''

    Map<String, Map<String, Object>?> $kLiveActivityArgImages = const {},''';

const _customStartParams = '''

    Map<String, String> $kLiveActivityDartArgDefaults = const {},$_customImagesParam''';

const _customImagesEntry = '''

        if (_withoutNullImages($kLiveActivityArgImages).isNotEmpty)
          '$kLiveActivityArgImages': _withoutNullImages($kLiveActivityArgImages),''';

// The same entry at the indent of `end`'s argument map.
const _customEndImagesEntry = '''

      if (_withoutNullImages($kLiveActivityArgImages).isNotEmpty)
        '$kLiveActivityArgImages': _withoutNullImages($kLiveActivityArgImages),''';

const _customHelpers = '''

  /// 'true' or 'false'.
  static String? $kLiveActivityEncodeBool(bool? value) => value?.toString();

  /// A colour as the card reads it: '#AARRGGBB'.
  static String? $kLiveActivityEncodeColor(Color? value) =>
      value == null
          ? null
          : '#\${value.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// A picture for one of a Custom card's Image values, from what the app
  /// has: a web address ('$kLiveActivityImageSourceUrl'), a file on the device ('$kLiveActivityImageSourcePath'), an asset of
  /// the app ('$kLiveActivityImageSourceAsset'), or the picture's bytes ('$kLiveActivityImageSourceBytes': a `Uint8List`, or an
  /// uploaded file that has them). Null (left out: the card keeps the picture
  /// it has) for null, empty text and anything else.
  static Map<String, Object>? $kLiveActivityEncodeImage(Object? source) {
    if (source == null) {
      return null;
    }
    if (source is Uint8List) {
      return source.isEmpty ? null : {'$kLiveActivityImageSourceBytes': source};
    }
    if (source is List<int>) {
      return source.isEmpty
          ? null
          : {'$kLiveActivityImageSourceBytes': Uint8List.fromList(source)};
    }
    if (source is String) {
      final text = source.trim();
      final lower = text.toLowerCase();
      if (text.isEmpty) {
        return null;
      }
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        return {'$kLiveActivityImageSourceUrl': text};
      }
      try {
        if (lower.startsWith('data:')) {
          return $kLiveActivityEncodeImage(UriData.parse(text).contentAsBytes());
        }
        if (lower.startsWith('file://')) {
          return {'$kLiveActivityImageSourcePath': Uri.parse(text).toFilePath()};
        }
      } catch (_) {
        return null;
      }
      return text.startsWith('/')
          ? {'$kLiveActivityImageSourcePath': text}
          : {'$kLiveActivityImageSourceAsset': text};
    }
    // An uploaded file (FFUploadedFile) carries its picture in `bytes`.
    try {
      final bytes = (source as dynamic).bytes;
      return bytes is List<int> ? $kLiveActivityEncodeImage(bytes) : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Map<String, Object>> _withoutNullImages(
    Map<String, Map<String, Object>?> images,
  ) => {
    for (final entry in images.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
''';
