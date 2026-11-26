/// What an app's home screen widgets are: the input of every generator in
/// this package.
///
/// A [HomeWidgetApp] names the app's native identifiers and lists its
/// [HomeWidgetDefinition]s. Each definition has its values, its choices, an
/// optional refresh plan and one [HomeWidgetLayoutModel] per size. Nothing
/// here knows where the spec came from: FlutterFlow builds it from a project,
/// other tools write it as JSON (see `json.dart`).
library;

import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/refresh.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// A widget size. The first three are Home Screen sizes (iOS and Android),
/// the last three Lock Screen sizes (iOS 16 and later only).
enum HomeWidgetSize {
  small('small', 'Small'),
  medium('medium', 'Medium'),
  large('large', 'Large'),
  accessoryCircular('circular', 'Circular'),
  accessoryRectangular('rectangular', 'Rectangular'),
  accessoryInline('inline', 'Inline');

  const HomeWidgetSize(this.tag, this.label);

  /// Lower-case name, used in generated type and resource names.
  final String tag;

  /// The name people see for the size.
  final String label;

  /// Whether this is a Lock Screen size (iOS only).
  bool get isLockScreen => index >= HomeWidgetSize.accessoryCircular.index;
}

/// The type of a widget value: the layout core's [LayoutValueType], so a
/// value's type is the type its layout reads. Every value travels to the
/// widget as a string; [HomeWidgetValueTypeWire.encoder] is the plugin's
/// helper that writes it (null: sent as is).
typedef HomeWidgetValueType = LayoutValueType;

/// What a home screen widget's spec and plugin say of each value type.
extension HomeWidgetValueTypeWire on LayoutValueType {
  /// The type's name in JSON.
  String get id => name;

  /// Static helper of the Dart plugin class that encodes a value of this type
  /// into its wire string; null for text.
  String? get encoder => switch (this) {
    LayoutValueType.string => null,
    LayoutValueType.integer => 'encodeInt',
    LayoutValueType.double => 'encodeDouble',
    LayoutValueType.boolean => 'encodeBool',
    LayoutValueType.dateTime => 'encodeDateTime',
    LayoutValueType.color => 'encodeColor',
  };

  /// Whether the value is a number.
  bool get isNumber =>
      this == LayoutValueType.integer || this == LayoutValueType.double;
}

/// One value a widget shows, set by the app (or a refresh, or a button).
class HomeWidgetValue {
  const HomeWidgetValue({
    required this.key,
    required this.name,
    required this.type,
    this.defaultValue,
  });

  /// The key the app sends the value under.
  final String key;

  /// The value's name, for people.
  final String name;
  final HomeWidgetValueType type;

  /// What the widget shows until a value is sent, as the wire string the app
  /// would send for it (see [HomeWidgetValueType]); null for nothing.
  final String? defaultValue;
}

/// A choice of a configurable widget: a person picks one for each copy they
/// place, and the copy shows [values] over the widget's own.
class HomeWidgetChoice {
  const HomeWidgetChoice({
    required this.id,
    required this.name,
    this.values = const {},
  });

  final String id;
  final String name;

  /// Values by value key (wire strings).
  final Map<String, String> values;
}

/// The choices a person picks from when placing a widget.
class HomeWidgetConfiguration {
  const HomeWidgetConfiguration({
    this.title = '',
    this.choices = const [],
    this.appChoices = false,
  });

  /// What the picker calls a choice; empty for "Choice".
  final String title;

  /// The choices set at build time.
  final List<HomeWidgetChoice> choices;

  /// Whether the app adds choices at run time (an update with a choice id).
  final bool appChoices;
}

/// One home screen widget: what it is called, its values, and how it draws
/// each of its sizes.
class HomeWidgetDefinition {
  const HomeWidgetDefinition({
    required this.key,
    required this.name,
    this.description = '',
    this.placeholderText = '',
    this.values = const [],
    required this.layouts,
    this.refresh,
    this.configuration,
  });

  /// The key the app's updates name the widget by. It also names the
  /// widget's native types, so it must stay the same across builds: Android
  /// identifies a placed widget by its provider class.
  final String key;

  /// The name in the widget gallery; empty for "Widget".
  final String name;
  final String description;

  /// What the widget shows before the app first sends it values; empty for a
  /// default text.
  final String placeholderText;
  final List<HomeWidgetValue> values;

  /// How the widget draws each of its sizes. A size it has no layout for is
  /// not offered.
  final Map<HomeWidgetSize, HomeWidgetLayoutModel> layouts;

  /// How the widget fetches its own values; null when only the app sets them.
  final HomeWidgetRefreshPlan? refresh;
  final HomeWidgetConfiguration? configuration;

  /// [layouts] in size order.
  List<(HomeWidgetSize, HomeWidgetLayoutModel)> get sizedLayouts => [
    for (final size in HomeWidgetSize.values)
      if (layouts[size] case final layout?) (size, layout),
  ];

  /// The Home Screen layouts: what Android draws (it has no Lock Screen
  /// widgets).
  List<(HomeWidgetSize, HomeWidgetLayoutModel)> get homeScreenLayouts => [
    for (final entry in sizedLayouts)
      if (!entry.$1.isLockScreen) entry,
  ];

  /// The name the widget shows in the gallery and picker.
  String get displayName => name.trim().isEmpty ? 'Widget' : name.trim();

  /// What the widget shows before the app first updates it.
  String get placeholder => placeholderText.trim().isEmpty
      ? 'Open the app to see this widget.'
      : placeholderText.trim();

  /// The default of each value that has one, by value key.
  Map<String, String> get defaultValues => {
    for (final value in values)
      if (value.defaultValue != null) value.key: value.defaultValue!,
  };

  /// Whether a person picks a choice for each copy they place.
  bool get isConfigurable =>
      configuration != null &&
      (configuration!.choices.isNotEmpty || configuration!.appChoices);

  /// What the picker calls a choice: the configuration's title, else
  /// "Choice".
  String get choiceTitle {
    final title = configuration?.title.trim() ?? '';
    return title.isEmpty ? 'Choice' : title;
  }

  /// The values [choice] sets, keeping only this widget's own values.
  Map<String, String> choiceValues(HomeWidgetChoice choice) {
    final keys = {for (final value in values) value.key};
    return {
      for (final MapEntry(:key, :value) in choice.values.entries)
        if (keys.contains(key)) key: value,
    };
  }

  /// [key] as part of a Swift or Kotlin identifier.
  String get nativeKey => identifierPart(key);

  /// Swift struct of the widget (`FFHomeWidget_ab12CD34`).
  String get swiftType => 'FFHomeWidget_$nativeKey';

  /// Kotlin class of the widget's AppWidgetProvider. Android names a placed
  /// widget by this class, so it depends on the key only: renaming or
  /// reordering widgets keeps the ones already on home screens.
  String get androidProviderClass => 'FFHomeWidgetProvider_$nativeKey';

  /// Android resource name suffix. Resource names are lower case, so each
  /// upper case letter of the key becomes `_` plus the letter: two keys that
  /// differ only in case still get two resources.
  String get androidResourceKey => nativeKey
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .toLowerCase();
}

/// Where a tap that opens a page goes: the app's deep link scheme and host.
class HomeWidgetRoutes {
  const HomeWidgetRoutes({
    required this.scheme,
    this.host = '',
    this.encodeTwice = true,
  });

  /// The URL scheme the app handles (`myapp`).
  final String scheme;

  /// The host of its links; empty for none.
  final String host;

  /// Whether a parameter is percent-encoded twice on iOS: once for the route
  /// and once more for the link, which the app's link handling decodes. A
  /// link a separate dynamic links SDK delivers is decoded once.
  final bool encodeTwice;
}

/// An app's home screen widgets and the native identifiers they need.
class HomeWidgetApp {
  const HomeWidgetApp({
    required this.iosBundleId,
    this.iosDeviceFamily = '1',
    this.routes = const HomeWidgetRoutes(scheme: ''),
    required this.widgets,
  });

  /// The app's iOS bundle id. The widget extension is `<id>.HomeWidgets`.
  final String iosBundleId;

  /// The extension's `TARGETED_DEVICE_FAMILY`: `1` (iPhone) or `1,2`
  /// (iPhone and iPad), as the app's. Quotes are added where needed.
  final String iosDeviceFamily;
  final HomeWidgetRoutes routes;

  /// The widgets, in gallery order, each key once.
  final List<HomeWidgetDefinition> widgets;

  /// The keychain access group the app and the widget extension share, as
  /// the entitlements and Info.plist files spell it (Xcode expands the
  /// prefix). The values the app sends are stored in it.
  String get keychainGroup =>
      '\$(AppIdentifierPrefix)$iosBundleId.$kHomeWidgetKeychainGroupSuffix';

  /// The app's own keychain group. It stays the app's first (default) group,
  /// so items the app writes elsewhere keep landing where they always did.
  String get appKeychainGroup => '\$(AppIdentifierPrefix)$iosBundleId';

  /// The widgets Android offers: those with a Home Screen layout.
  List<HomeWidgetDefinition> get androidWidgets => [
    for (final widget in widgets)
      if (widget.homeScreenLayouts.isNotEmpty) widget,
  ];

  /// The widget with [key], if any.
  HomeWidgetDefinition? widget(String key) {
    for (final widget in widgets) {
      if (widget.key == key) {
        return widget;
      }
    }
    return null;
  }

  /// Every Material Icons code point the widgets draw. The app keeps them in
  /// its icon font: release builds drop the glyphs Dart code does not use,
  /// and the native widgets draw from that font.
  Set<int> get iconCodePoints => {
    for (final widget in widgets)
      for (final (_, layout) in widget.sizedLayouts)
        for (final node in layout.nodes)
          if (node case LayoutIcon(:final codePoint)) codePoint,
  };
}
