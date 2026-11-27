/// The wire contract between the three halves of a generated Live Activity:
/// the Dart API of the local `ff_live_activity` plugin package, its Swift side
/// (plugin + widget extension) and its Kotlin side.
///
/// This file is the single source of truth. The Dart, Swift and Kotlin
/// generators interpolate these constants; none of them spells a channel name,
/// a method name or a key as its own literal.
///
/// Wire shape: every method call carries one flat map. Template values travel
/// in a nested `Map<String, String>` under [kLiveActivityArgValues], because
/// the ActivityKit content state is `values: [String: String]` (no App Group,
/// about 4 KB). Each value is encoded as a string, see [LiveActivityWireType].
///
/// A Custom card ([LiveActivityTemplate.custom]) has no fixed contract: its
/// values are the card's own, keyed by the value's key and encoded by type
/// (`LiveActivityValueType.encoder`). Its pictures (Image values) travel
/// beside the values, under [kLiveActivityArgImages], and never in the 4 KB
/// state. See "Custom cards" below.
library;

// --- Plugin package -------------------------------------------------------

/// Name of the local plugin package, written to `packages/ff_live_activity`
/// in the generated app and added to its pubspec as a path dependency.
const kLiveActivityPluginPackage = 'ff_live_activity';

/// Directory of the plugin package, relative to the generated app's root.
const kLiveActivityPluginPackagePath = 'packages/$kLiveActivityPluginPackage';

/// The pubspec dependency entry of the generated app, in the same
/// `name: value` form `allDependencies` returns.
const kLiveActivityPluginPubspecDependency =
    '$kLiveActivityPluginPackage: \n    path: $kLiveActivityPluginPackagePath';

/// Dart class the generated action code calls (`FFLiveActivity.start(...)`).
const kLiveActivityDartClass = 'FFLiveActivity';

/// Dart library the generated action code imports.
const kLiveActivityDartImport =
    'package:$kLiveActivityPluginPackage/$kLiveActivityPluginPackage.dart';

/// Plugin class name, the same on iOS (Swift) and Android (Kotlin). The
/// plugin's pubspec names it as `pluginClass` for both platforms.
const kLiveActivityPluginClass = 'FFLiveActivityPlugin';

/// Kotlin package of the Android plugin class.
const kLiveActivityAndroidPackage = 'io.flutterflow.live_activity';

/// The folder of the plugin's Kotlin sources under `kotlin/`: its package as
/// a path.
final kLiveActivityAndroidKotlinDir = kLiveActivityAndroidPackage.replaceAll(
  '.',
  '/',
);

/// Swift type of the ActivityKit attributes. The plugin and the widget
/// extension each carry a copy; both are emitted from one template.
const kLiveActivityAttributesType = 'FFLiveActivityAttributes';

/// Name of the iOS widget-extension target and of its folder under `ios/`.
/// Its bundle id is the app's bundle id plus `.` plus this name.
const kLiveActivityIosExtensionTarget = 'LiveActivity';

/// Lowest iOS version that shows the activity (ActivityContent API). The
/// extension target's deployment target; the plugin returns false below it.
const kLiveActivityMinIosVersion = '16.2';

// --- Method channel ---------------------------------------------------------

const kLiveActivityChannelName = 'flutterflow/live_activity';

/// Returns `bool`: whether the device can show the activity right now.
const kLiveActivityMethodIsSupported = 'isSupported';

/// Returns `bool`: false when the device cannot show the activity.
const kLiveActivityMethodStart = 'start';

/// Returns `bool`: false when no matching activity is running.
const kLiveActivityMethodUpdate = 'update';

/// Returns nothing. Ending an activity that is not running is not an error.
const kLiveActivityMethodEnd = 'end';

const kLiveActivityMethods = [
  kLiveActivityMethodIsSupported,
  kLiveActivityMethodStart,
  kLiveActivityMethodUpdate,
  kLiveActivityMethodEnd,
];

// --- Argument keys ----------------------------------------------------------

/// `String`, required on start / update / end: the key of the activity's
/// definition (`LiveActivityDefinition.key`).
const kLiveActivityArgDefinitionKey = 'definitionKey';

/// `String`, optional on start / update / end: tells apart several running
/// cards of one definition. Absent or empty means the definition's single
/// default card: start then replaces the running one.
const kLiveActivityArgInstanceId = 'instanceId';

/// `String`, required on start: one of [LiveActivityTemplate.wireName].
const kLiveActivityArgTemplate = 'template';

/// `String`, optional on start: `#AARRGGBB`, upper case. Absent means the
/// template's default accent.
const kLiveActivityArgAccentColor = 'accentColor';

/// `String`, optional on start: the Flutter asset path of the card's icon.
/// Absent means the app icon.
const kLiveActivityArgIcon = 'icon';

/// `String`, optional on start: Android notification channel name shown in
/// system settings. Ignored on iOS.
const kLiveActivityArgAndroidChannelName = 'androidChannelName';

/// `Map<String, String>`: the template's values. Required on start (all of
/// the template's keys that are set), optional on update (only the keys that
/// change; the others keep their value) and on end (the final content).
const kLiveActivityArgValues = 'values';

/// `String`, optional on end: [kLiveActivityDismissalImmediate] or
/// [kLiveActivityDismissalSystemDefault]. Absent means
/// [kLiveActivityDismissalDefault].
const kLiveActivityArgDismissal = 'dismissal';

/// Argument keys per method, in the order generators emit them.
const kLiveActivityMethodArguments = <String, List<String>>{
  kLiveActivityMethodIsSupported: [],
  kLiveActivityMethodStart: [
    kLiveActivityArgDefinitionKey,
    kLiveActivityArgInstanceId,
    kLiveActivityArgTemplate,
    kLiveActivityArgAccentColor,
    kLiveActivityArgIcon,
    kLiveActivityArgAndroidChannelName,
    kLiveActivityArgValues,
  ],
  kLiveActivityMethodUpdate: [
    kLiveActivityArgDefinitionKey,
    kLiveActivityArgInstanceId,
    kLiveActivityArgValues,
  ],
  kLiveActivityMethodEnd: [
    kLiveActivityArgDefinitionKey,
    kLiveActivityArgInstanceId,
    kLiveActivityArgValues,
    kLiveActivityArgDismissal,
  ],
};

// --- Custom cards -----------------------------------------------------------

/// Wire value of [kLiveActivityArgTemplate] for a Custom card. The native
/// side picks the card's design by [kLiveActivityArgDefinitionKey].
const kLiveActivityCustomTemplateName = 'custom';

/// `Map<String, Map<String, Object>>`, optional on start / update / end of a
/// Custom card: the pictures of the card's Image values, keyed by value key.
/// Each entry holds exactly one of the four `kLiveActivityImageSource*` keys.
///
/// The plugin gets the bytes, shrinks them, stores the file and writes the
/// stored name into the card's values under the same key, so the state only
/// pays for a name. A key that is absent keeps the picture the card has (on
/// start: the value's default asset, which is built into the native code and
/// never sent). The argument is absent when no picture is sent.
const kLiveActivityArgImages = 'images';

/// `String`: an `http://` or `https://` address the plugin downloads.
const kLiveActivityImageSourceUrl = 'url';

/// `String`: the absolute path of a file on the device.
const kLiveActivityImageSourcePath = 'path';

/// `Uint8List`: the encoded picture itself (PNG, JPEG, ...).
const kLiveActivityImageSourceBytes = 'bytes';

/// `String`: a Flutter asset key (`assets/images/boat.png`).
const kLiveActivityImageSourceAsset = 'asset';

const kLiveActivityImageSources = [
  kLiveActivityImageSourceUrl,
  kLiveActivityImageSourcePath,
  kLiveActivityImageSourceBytes,
  kLiveActivityImageSourceAsset,
];

/// Argument keys per method for a Custom card, in the order generators emit
/// them: [kLiveActivityMethodArguments] with [kLiveActivityArgImages] after
/// the values. A fixed template never sends the extra key.
final kLiveActivityCustomMethodArguments = <String, List<String>>{
  for (final entry in kLiveActivityMethodArguments.entries)
    entry.key: [
      for (final key in entry.value) ...[
        key,
        if (key == kLiveActivityArgValues) kLiveActivityArgImages,
      ],
    ],
};

/// Static helpers of [kLiveActivityDartClass] that encode a typed value into
/// its wire string. The app wraps every non-string value in one.
const kLiveActivityEncodeDouble = 'encodeDouble';
const kLiveActivityEncodeInt = 'encodeInt';
const kLiveActivityEncodeDateTime = 'encodeDateTime';

/// The two encoders only a Custom card's values need (a fixed template has
/// no Boolean or Color value). Generated only when the app has a Custom
/// card.
const kLiveActivityEncodeBool = 'encodeBool';
const kLiveActivityEncodeColor = 'encodeColor';

/// Static helper of `FFLiveActivity` that turns what an app has for a
/// picture (an address, a file path, an asset key, bytes, an uploaded file)
/// into one entry of [kLiveActivityArgImages].
const kLiveActivityEncodeImage = 'image';

/// Dart-only argument of `FFLiveActivity.start` for a Custom card: the
/// defaults of the card's values, as wire strings. The plugin's Dart side
/// sends each one the action left out (or whose value was null), so a card
/// always starts with every value it has a default for. It is merged into
/// [kLiveActivityArgValues] before the call and never crosses the channel.
const kLiveActivityDartArgDefaults = 'defaults';

// --- End dismissal ----------------------------------------------------------

const kLiveActivityDismissalImmediate = 'immediate';
const kLiveActivityDismissalSystemDefault = 'default';

/// What an end call with no dismissal sends, and what the native side
/// assumes when the argument is absent.
const kLiveActivityDismissalDefault = kLiveActivityDismissalImmediate;

// --- Template values --------------------------------------------------------

/// How a value is written into the `values` string map.
enum LiveActivityWireType {
  /// The string as is.
  string,

  /// Dart `double.toString()`: decimal point, no grouping (`0.5`, `1.0`).
  /// Swift reads it with `Double(_:)`, Kotlin with `toDouble()`.
  double,

  /// Decimal integer (`42`, `-1`).
  int,

  /// A `DateTime` as milliseconds since the Unix epoch (UTC), as a decimal
  /// integer (`1794225600000`).
  epochMillis,
}

/// One value of a fixed template: its key in the `values` map and its string
/// encoding.
class LiveActivityTemplateValue {
  const LiveActivityTemplateValue(this.key, this.type);

  /// Key in the `values` map (`statusText`).
  final String key;

  final LiveActivityWireType type;
}

const kLiveActivityValueTitle = 'title';
const kLiveActivityValueStatusText = 'statusText';
const kLiveActivityValueProgress = 'progress';
const kLiveActivityValueEndTime = 'endTime';
const kLiveActivityValueStartTime = 'startTime';
const kLiveActivityValueHomeName = 'homeName';
const kLiveActivityValueHomeScore = 'homeScore';
const kLiveActivityValueAwayName = 'awayName';
const kLiveActivityValueAwayScore = 'awayScore';
const kLiveActivityValuePosition = 'position';
const kLiveActivityValueEstimatedWaitMinutes = 'estimatedWaitMinutes';

/// Wire values of [kLiveActivityArgTemplate], one per [LiveActivityTemplate].
const kLiveActivityProgressTemplateName = 'progress';
const kLiveActivityEtaTimerTemplateName = 'etaTimer';
const kLiveActivityScoreTemplateName = 'score';
const kLiveActivityQueueStatusTemplateName = 'queueStatus';

/// What draws a Live Activity: one of four fixed templates, whose views are
/// written by hand and whose values are fixed, or [custom], a card drawn
/// from its own layouts with its own values.
enum LiveActivityTemplate {
  /// A title, a status line and a progress bar.
  progress(kLiveActivityProgressTemplateName, [
    LiveActivityTemplateValue(
      kLiveActivityValueTitle,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueStatusText,
      LiveActivityWireType.string,
    ),
    // 0 to 1.
    LiveActivityTemplateValue(
      kLiveActivityValueProgress,
      LiveActivityWireType.double,
    ),
  ]),

  /// A title, a status line and a countdown to an end time.
  etaTimer(kLiveActivityEtaTimerTemplateName, [
    LiveActivityTemplateValue(
      kLiveActivityValueTitle,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueStatusText,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueEndTime,
      LiveActivityWireType.epochMillis,
    ),
    // Optional: the card shows a progress bar when present.
    LiveActivityTemplateValue(
      kLiveActivityValueStartTime,
      LiveActivityWireType.epochMillis,
    ),
  ]),

  /// Two sides, each with a name and a score, and a status line.
  score(kLiveActivityScoreTemplateName, [
    LiveActivityTemplateValue(
      kLiveActivityValueHomeName,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueHomeScore,
      LiveActivityWireType.int,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueAwayName,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueAwayScore,
      LiveActivityWireType.int,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueStatusText,
      LiveActivityWireType.string,
    ),
  ]),

  /// A position in a queue with an estimated wait.
  queueStatus(kLiveActivityQueueStatusTemplateName, [
    LiveActivityTemplateValue(
      kLiveActivityValueTitle,
      LiveActivityWireType.string,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValuePosition,
      LiveActivityWireType.int,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueEstimatedWaitMinutes,
      LiveActivityWireType.int,
    ),
    LiveActivityTemplateValue(
      kLiveActivityValueStatusText,
      LiveActivityWireType.string,
    ),
  ]),

  /// A card drawn from its own layouts, with its own values.
  custom(kLiveActivityCustomTemplateName, []);

  const LiveActivityTemplate(this.wireName, this.fixedValues);

  /// Wire value of [kLiveActivityArgTemplate].
  final String wireName;

  /// The values of a fixed template, in the order generators emit them.
  /// Empty for [custom], whose values are the card's own.
  final List<LiveActivityTemplateValue> fixedValues;

  /// Whether the card is drawn from its own layouts.
  bool get isCustom => this == custom;
}
