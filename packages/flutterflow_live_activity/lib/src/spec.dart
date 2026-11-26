/// What an app's Live Activities are: the input of every generator in this
/// package.
///
/// A [LiveActivityApp] names the app's native identifiers and lists its
/// [LiveActivityDefinition]s. A definition uses one of the fixed templates
/// (hand-written views; the app sends the template's values) or is a Custom
/// card: its own [LiveActivityValue]s and one [NativeLayoutModel] per
/// [LiveActivitySurface] it is designed for. Nothing here knows where the
/// spec came from.
library;

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// The version of the spec this package reads. Raised when a field changes
/// meaning; a spec of another version is not read.
const kLiveActivitySpecVersion = 1;

/// Where a Live Activity is drawn on iOS. Android draws only the Lock Screen
/// layout.
enum LiveActivitySurface {
  /// The Lock Screen card, and the banner on a phone without a Dynamic
  /// Island.
  lockScreen('lockScreen', 371, 160),

  /// The expanded Dynamic Island, under the sensor row.
  islandExpanded('expanded', 371, 122),

  /// The compact island, left of the sensors.
  islandCompactLeading('compactLeading', 52, 36),

  /// The compact island, right of the sensors.
  islandCompactTrailing('compactTrailing', 52, 36),

  /// The minimal island, when two apps share it.
  islandMinimal('minimal', 36, 36);

  const LiveActivitySurface(this.swiftName, this.width, this.height);

  /// The surface's part of a card view's Swift name (`FFCard_<key>_<this>`).
  final String swiftName;

  /// The size the surface is designed at, in points, on the 393 pt iPhones.
  /// The Lock Screen and the expanded island fit their height to the
  /// card, up to [height]; the others always have this size.
  final double width;
  final double height;

  /// Whether the surface is on the Dynamic Island, which is black whatever
  /// the phone's mode: its layouts are drawn in the dark colour scheme.
  bool get isIsland => this != lockScreen;
}

/// The type of a Custom card's value. Every value but an image travels to
/// the card as a string in the `values` map; an image travels in the
/// `images` argument (see `kLiveActivityArgImages`).
enum LiveActivityValueType {
  string,
  integer,
  double,
  boolean,
  dateTime,
  color,
  image;

  /// Static helper of the Dart plugin class that encodes a value of this
  /// type into its wire string; null for text (sent as is) and for an
  /// image (not in the `values` map).
  ///
  /// - Integer: decimal (`42`). Double: Dart `double.toString()` (`0.5`).
  /// - Boolean: `true` or `false`.
  /// - DateTime: milliseconds since the Unix epoch, decimal.
  /// - Color: `#AARRGGBB`, upper case.
  ///
  /// The same strings home screen widgets send, so the shared layout code
  /// reads both.
  String? get encoder => switch (this) {
    string || image => null,
    integer => kLiveActivityEncodeInt,
    double => kLiveActivityEncodeDouble,
    boolean => kLiveActivityEncodeBool,
    dateTime => kLiveActivityEncodeDateTime,
    color => kLiveActivityEncodeColor,
  };
}

/// One value of a Custom card, set by the app on start, update and end.
class LiveActivityValue {
  const LiveActivityValue({
    required this.key,
    this.name = '',
    required this.type,
    this.defaultValue,
    this.required = false,
  });

  /// The key the app sends the value under. Layouts read it by this key.
  final String key;

  /// The value's name, for people.
  final String name;
  final LiveActivityValueType type;

  /// What the card shows until the app sends the value, as the wire string
  /// the app would send for it; null for nothing. For an image, the asset
  /// path of the picture drawn until the app sends one (`assets/images/...`).
  final String? defaultValue;

  /// Whether the app must set the value on start: it has no default to fall
  /// back on.
  final bool required;
}

/// How Android shows a Custom card.
enum LiveActivityAndroidPresentation {
  /// The system's standard Live Update, filled from the card's values (see
  /// [LiveActivityAndroidSlot]).
  standard,

  /// The card's Lock Screen layout, drawn as the notification's custom view.
  /// A layout that cannot be drawn there (one with a tap) falls back to
  /// [standard].
  custom,
}

/// The parts of a standard Android Live Update a card value can fill.
enum LiveActivityAndroidSlot {
  title(LiveActivityValueType.string),
  text(LiveActivityValueType.string),
  progress(LiveActivityValueType.double),
  countdown(LiveActivityValueType.dateTime),
  shortText(LiveActivityValueType.string),
  largeIcon(LiveActivityValueType.image);

  const LiveActivityAndroidSlot(this.valueType);

  /// The type of card value the part takes.
  final LiveActivityValueType valueType;
}

/// How a Custom card shows on Android.
class LiveActivityAndroid {
  const LiveActivityAndroid({
    this.presentation = LiveActivityAndroidPresentation.standard,
    this.slots = const {},
  });

  final LiveActivityAndroidPresentation presentation;

  /// The value key each part of the standard Live Update shows, for the
  /// parts the card names one for. A named value the card does not have
  /// leaves the part empty. A part not named takes a default: see
  /// [LiveActivityDefinition.androidSlotValues].
  final Map<LiveActivityAndroidSlot, String> slots;
}

/// One Live Activity the app can start: a fixed template, or a Custom card
/// with its values and layouts.
class LiveActivityDefinition {
  const LiveActivityDefinition({
    required this.key,
    this.name = '',
    this.description = '',
    required this.template,
    this.accentColor,
    this.icon,
    this.androidChannelName = '',
    this.values = const [],
    this.surfaces = const {},
    this.android = const LiveActivityAndroid(),
    this.androidDefaults,
  });

  /// The key the app's start, update and end calls name the activity by. A
  /// Custom card's native types are named after it, so it must stay the
  /// same across builds.
  final String key;

  /// The activity's name, for people.
  final String name;
  final String description;
  final LiveActivityTemplate template;

  /// `#AARRGGBB`; null for the template's default accent. Sent by the app
  /// with each start.
  final String? accentColor;

  /// The asset path of the card's icon (`assets/images/...`); null for the
  /// app icon. Sent by the app with each start.
  final String? icon;

  /// The name of the Android notification channel, shown in the system
  /// settings; empty for a default. Sent by the app with each start.
  final String androidChannelName;

  /// A Custom card's values, in order. Empty for a fixed template, whose
  /// values are the template's ([LiveActivityTemplate.fixedValues]).
  final List<LiveActivityValue> values;

  /// A Custom card's layouts, by surface. A surface it has no layout for is
  /// drawn from its values and icon (the compact and minimal island), or
  /// not at all. An island layout is read for the island: its colours are
  /// the dark ones.
  ///
  /// The generators drop the top widget's fill of the
  /// [LiveActivitySurface.islandExpanded] layout (the island is black), so
  /// that model must not be shared with another surface.
  final Map<LiveActivitySurface, NativeLayoutModel> surfaces;

  final LiveActivityAndroid android;

  /// The defaults the Android side draws, by value key, when they are not
  /// the values' own: Android then fills a value the app did not send from
  /// this table. Null: each value's [LiveActivityValue.defaultValue] that is
  /// not empty (images aside).
  final Map<String, String>? androidDefaults;

  /// Whether the card is drawn from its own layouts.
  bool get isCustom => template.isCustom;

  /// The value with key [key]; null for an empty key or one the card does
  /// not have.
  LiveActivityValue? value(String key) {
    if (key.isEmpty) {
      return null;
    }
    for (final value in values) {
      if (value.key == key) {
        return value;
      }
    }
    return null;
  }

  /// The card's values of [type], in order.
  Iterable<LiveActivityValue> valuesOfType(LiveActivityValueType type) =>
      values.where((value) => value.type == type);

  /// The card's Image values, in order.
  List<LiveActivityValue> get imageValues =>
      valuesOfType(LiveActivityValueType.image).toList();

  /// The layouts, in surface order.
  List<(LiveActivitySurface, NativeLayoutModel)> get layouts => [
    for (final surface in LiveActivitySurface.values)
      if (surfaces[surface] case final model?) (surface, model),
  ];

  /// Whether a layout of the card has a node that passes [test].
  bool anyNode(bool Function(LayoutNode node) test) =>
      surfaces.values.any((model) => model.nodes.any(test));

  /// The value each part of the standard Android Live Update shows. A part
  /// the card names a value for ([LiveActivityAndroid.slots]) shows that
  /// value, if the card has it. A part not named takes a default: the first
  /// String value is the title, the second the text, the first Double the
  /// progress, the first DateTime the countdown and the first Image the
  /// picture. The chip text has no default. Parts with nothing to show are
  /// left out.
  Map<LiveActivityAndroidSlot, LiveActivityValue> get androidSlotValues {
    LiveActivityValue? nth(LiveActivityValueType type, int index) =>
        valuesOfType(type).elementAtOrNull(index);
    LiveActivityValue? fallback(LiveActivityAndroidSlot slot) => switch (slot) {
      LiveActivityAndroidSlot.title => nth(LiveActivityValueType.string, 0),
      LiveActivityAndroidSlot.text => nth(LiveActivityValueType.string, 1),
      LiveActivityAndroidSlot.progress => nth(LiveActivityValueType.double, 0),
      LiveActivityAndroidSlot.countdown => nth(
        LiveActivityValueType.dateTime,
        0,
      ),
      LiveActivityAndroidSlot.shortText => null,
      LiveActivityAndroidSlot.largeIcon => nth(LiveActivityValueType.image, 0),
    };
    final slots = android.slots;
    return {
      for (final slot in LiveActivityAndroidSlot.values)
        if (slots.containsKey(slot) ? value(slots[slot]!) : fallback(slot)
            case final value?)
          slot: value,
    };
  }

  /// The default of each value the iOS card draws, by value key: every value
  /// with a default but an Image, whose default the image node draws.
  Map<String, String> get iosDefaults => {
    for (final value in values)
      if (value.defaultValue case final defaultValue?)
        if (value.type != LiveActivityValueType.image) value.key: defaultValue,
  };

  /// The default of each value Android draws, by value key.
  Map<String, String> get androidValueDefaults =>
      androidDefaults ??
      {
        for (final value in values)
          if (value.defaultValue case final defaultValue?)
            if (value.type != LiveActivityValueType.image &&
                defaultValue.isNotEmpty)
              value.key: defaultValue,
      };

  /// The asset each Image value draws until the app sends a picture, by
  /// value key: Android's fallback for the value.
  Map<String, String> get imageFallbacks => {
    for (final value in imageValues)
      if (value.defaultValue case final defaultValue?) value.key: defaultValue,
  };

  /// [key] as part of a Swift or Kotlin identifier.
  String get nativeKey => identifierPart(key);
}

/// Where a tap that opens a page goes: the app's deep link scheme and host.
class LiveActivityRoutes {
  const LiveActivityRoutes({
    required this.scheme,
    this.host = '',
    this.encodeTwice = true,
  });

  /// The URL scheme the app handles (`myapp`).
  final String scheme;

  /// The host of its links; empty for none.
  final String host;

  /// Whether a route value is percent-encoded twice on iOS: the app's router
  /// decodes a link once before it reads the values, unless a separate link
  /// service delivers the link itself.
  final bool encodeTwice;
}

/// An app's Live Activities and the native identifiers they need.
class LiveActivityApp {
  const LiveActivityApp({
    this.specVersion = kLiveActivitySpecVersion,
    required this.iosBundleId,
    this.iosDeviceFamily = '1',
    this.routes = const LiveActivityRoutes(scheme: ''),
    required this.activities,
  });

  /// The version of the spec ([kLiveActivitySpecVersion]).
  final int specVersion;

  /// The app's iOS bundle id. The widget extension is `<id>.LiveActivity`.
  final String iosBundleId;

  /// The extension's `TARGETED_DEVICE_FAMILY`: `1` (iPhone) or `1,2`
  /// (iPhone and iPad), as the app's. The project file has it quoted,
  /// whether or not it comes quoted.
  final String iosDeviceFamily;
  final LiveActivityRoutes routes;

  /// The activities, each key once.
  final List<LiveActivityDefinition> activities;

  /// The Custom cards, in order.
  List<LiveActivityDefinition> get customCards =>
      activities.where((activity) => activity.isCustom).toList();

  /// Whether a card is drawn from its own layouts: the app then gets the
  /// cards' views and the plugin their API (pictures, defaults).
  bool get hasCustomCards => activities.any((activity) => activity.isCustom);

  /// The Custom cards that have an Image value.
  List<LiveActivityDefinition> get imageCards =>
      customCards.where((card) => card.imageValues.isNotEmpty).toList();

  /// Whether a Custom card has an Image value: the app and the extension
  /// then share a keychain group the pictures are stored in.
  bool get hasImageValues => imageCards.isNotEmpty;

  /// The app's own keychain group, as entitlements spell it (Xcode fills in
  /// the prefix).
  String get appKeychainGroup => liveActivityAppKeychainGroup(iosBundleId);

  /// The keychain group the app shares with the Live Activity extension.
  String get keychainGroup => liveActivityKeychainGroup(iosBundleId);
}

/// Last part of the keychain access group the app shares with the Live
/// Activity extension: `<team id>.<bundle id>.<this>`.
const kLiveActivityKeychainGroupSuffix = 'liveactivity';

/// The keychain group of the app with bundle id [iosBundleId], as the
/// entitlements and Info.plist files spell it (Xcode expands the prefix).
String liveActivityAppKeychainGroup(String iosBundleId) =>
    '\$(AppIdentifierPrefix)$iosBundleId';

/// The keychain access group the app with bundle id [iosBundleId] shares
/// with its Live Activity extension.
String liveActivityKeychainGroup(String iosBundleId) =>
    '${liveActivityAppKeychainGroup(iosBundleId)}.'
    '$kLiveActivityKeychainGroupSuffix';
