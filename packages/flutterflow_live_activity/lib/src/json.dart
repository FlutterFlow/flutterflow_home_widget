/// The JSON form of a [LiveActivityApp], for tools that write the spec rather
/// than build it in Dart. The package's README describes every field.
///
/// Layouts are the layout JSON of `flutterflow_native_layout`
/// ([nativeLayoutFromJson]), the same as a home screen widget's, with the
/// forms only a card draws. Colors are `#AARRGGBB`.
library;

import 'dart:convert';

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:flutterflow_native_layout/layout_json.dart';

/// Thrown when JSON does not describe a valid spec. `path` says where
/// (`$.activities[0].surfaces.lockScreen.root.type`).
typedef LiveActivityJsonException = NativeLayoutJsonException;

/// What the Dynamic Island draws on: black, in light mode too.
const _kIslandBlack = LayoutColor.same(0xFF000000);

/// The app [json] describes.
///
/// A Custom card without an `islandExpanded` layout draws its `lockScreen`
/// layout there, in its dark colors (the island is black); `"islandExpanded":
/// null` leaves the expanded island empty instead.
LiveActivityApp liveActivityAppFromJson(Map<String, Object?> json) =>
    _app(SpecJsonReader(json, r'$'));

/// [app] as JSON. `liveActivityAppFromJson(liveActivityAppToJson(app))`
/// generates the same files as [app].
///
/// What the reader fills in is left out: an `islandExpanded` layout that is
/// the `lockScreen` one read for the island, `androidDefaults` that are the
/// values' own defaults, and stage specs that are what the bars draw.
Map<String, Object?> liveActivityAppToJson(LiveActivityApp app) => {
  'specVersion': app.specVersion,
  'iosBundleId': app.iosBundleId,
  'iosDeviceFamily': app.iosDeviceFamily,
  'routes': {
    'scheme': app.routes.scheme,
    'host': app.routes.host,
    'encodeTwice': app.routes.encodeTwice,
  },
  'activities': [
    for (final activity in app.activities) _activityToJson(activity),
  ],
};

/// The layout type a card value is drawn as; null for an image, which no
/// text shows.
LayoutValueType? _layoutType(LiveActivityValueType type) => switch (type) {
  LiveActivityValueType.string => LayoutValueType.string,
  LiveActivityValueType.integer => LayoutValueType.integer,
  LiveActivityValueType.double => LayoutValueType.double,
  LiveActivityValueType.boolean => LayoutValueType.boolean,
  LiveActivityValueType.dateTime => LayoutValueType.dateTime,
  LiveActivityValueType.color => LayoutValueType.color,
  LiveActivityValueType.image => null,
};

Map<String, LayoutValueType> _layoutTypes(List<LiveActivityValue> values) => {
  for (final value in values)
    if (_layoutType(value.type) case final type?) value.key: type,
};

// --- Writing ----------------------------------------------------------------

Map<String, Object?> _activityToJson(LiveActivityDefinition activity) {
  final android = activity.android;
  final androidDefaults = activity.androidDefaults;
  return {
    'key': activity.key,
    'name': activity.name,
    if (activity.description.isNotEmpty) 'description': activity.description,
    'template': activity.template.wireName,
    if (activity.accentColor case final accentColor?)
      'accentColor': accentColor,
    if (activity.icon case final icon?) 'icon': icon,
    if (activity.androidChannelName.isNotEmpty)
      'androidChannelName': activity.androidChannelName,
    if (activity.values.isNotEmpty)
      'values': [
        for (final value in activity.values)
          {
            'key': value.key,
            'name': value.name,
            'type': value.type.name,
            if (value.defaultValue case final defaultValue?)
              'default': defaultValue,
            if (value.required) 'required': true,
          },
      ],
    if (activity.surfaces.isNotEmpty) 'surfaces': _surfacesToJson(activity),
    if (android.presentation != LiveActivityAndroidPresentation.standard ||
        android.slots.isNotEmpty)
      'android': {
        if (android.presentation != LiveActivityAndroidPresentation.standard)
          'presentation': android.presentation.name,
        if (android.slots.isNotEmpty)
          'slots': {
            for (final MapEntry(key: slot, :value) in android.slots.entries)
              slot.name: value,
          },
      },
    if (androidDefaults != null &&
        !_sameEntries(androidDefaults, _ownDefaults(activity)))
      'androidDefaults': androidDefaults,
  };
}

/// The defaults Android draws when the card gives none of its own: see
/// [LiveActivityDefinition.androidValueDefaults].
Map<String, String> _ownDefaults(LiveActivityDefinition activity) =>
    LiveActivityDefinition(
      key: activity.key,
      template: activity.template,
      values: activity.values,
    ).androidValueDefaults;

/// Whether [a] and [b] have the same entries in the same order (the order
/// generated code lists them in).
bool _sameEntries(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) {
    return false;
  }
  final x = a.entries.toList();
  final y = b.entries.toList();
  for (var i = 0; i < x.length; i++) {
    if (x[i].key != y[i].key || x[i].value != y[i].value) {
      return false;
    }
  }
  return true;
}

Map<String, Object?> _surfacesToJson(LiveActivityDefinition activity) {
  final surfaces = activity.surfaces;
  final lock = surfaces[LiveActivitySurface.lockScreen];
  final expanded = surfaces[LiveActivitySurface.islandExpanded];
  final lockJson = lock == null ? null : nativeLayoutToJson(lock);
  final expandedJson = expanded == null ? null : nativeLayoutToJson(expanded);
  // The reader draws the Lock Screen layout on the expanded island when the
  // JSON has none for it: say so only when that is not what the card has.
  final readerFillsExpanded =
      activity.isCustom &&
      lockJson != null &&
      expandedJson != null &&
      _readForIsland(lockJson, activity) == jsonEncode(expandedJson);
  final json = <String, Object?>{};
  for (final surface in LiveActivitySurface.values) {
    switch (surface) {
      case LiveActivitySurface.lockScreen:
        if (lockJson != null) {
          json[surface.name] = lockJson;
        }
      case LiveActivitySurface.islandExpanded:
        if (expandedJson != null && !readerFillsExpanded) {
          json[surface.name] = expandedJson;
        } else if (expandedJson == null && lockJson != null) {
          // Without this the reader would fill it.
          json[surface.name] = null;
        }
      default:
        if (surfaces[surface] case final layout?) {
          json[surface.name] = nativeLayoutToJson(layout);
        }
    }
  }
  return json;
}

/// [lockJson] read back as the expanded island's layout, as JSON; null when
/// it does not read.
String? _readForIsland(
  Map<String, Object?> lockJson,
  LiveActivityDefinition activity,
) {
  try {
    return jsonEncode(
      nativeLayoutToJson(
        _readLayout(
          jsonDecode(jsonEncode(lockJson)) as Map<String, Object?>,
          r'$',
          _layoutTypes(activity.values),
          LiveActivitySurface.islandExpanded,
          darkColors: true,
        ),
      ),
    );
  } on NativeLayoutJsonException {
    return null;
  }
}

// --- Reading ----------------------------------------------------------------

NativeLayoutModel _readLayout(
  Map<String, Object?> json,
  String path,
  Map<String, LayoutValueType> types,
  LiveActivitySurface surface, {
  bool darkColors = false,
}) => nativeLayoutFromJson(
  json,
  types: types,
  path: path,
  owner: 'card',
  card: true,
  darkColors: darkColors,
  behind: surface.isIsland ? _kIslandBlack : null,
);

LiveActivityApp _app(SpecJsonReader json) {
  json.only(const {
    'specVersion',
    'iosBundleId',
    'iosDeviceFamily',
    'routes',
    'activities',
  });
  final version = json.req<num>('specVersion');
  if (version != kLiveActivitySpecVersion) {
    json.fail(
      'this package reads spec version $kLiveActivitySpecVersion',
      'specVersion',
    );
  }
  final routes = json.optChild('routes');
  routes?.only(const {'scheme', 'host', 'encodeTwice'});
  return LiveActivityApp(
    specVersion: version.toInt(),
    iosBundleId: json.req<String>('iosBundleId'),
    iosDeviceFamily: json.opt<String>('iosDeviceFamily') ?? '1',
    routes:
        routes == null
            ? const LiveActivityRoutes(scheme: '')
            : LiveActivityRoutes(
              scheme: routes.opt<String>('scheme') ?? '',
              host: routes.opt<String>('host') ?? '',
              encodeTwice: routes.opt<bool>('encodeTwice') ?? true,
            ),
    activities: [
      for (final activity in json.children('activities')) _activity(activity),
    ],
  );
}

LiveActivityDefinition _activity(SpecJsonReader json) {
  json.only(const {
    'key',
    'name',
    'description',
    'template',
    'accentColor',
    'icon',
    'androidChannelName',
    'values',
    'surfaces',
    'android',
    'androidDefaults',
  });
  final key = json.req<String>('key');
  final wireName = json.req<String>('template');
  final template =
      LiveActivityTemplate.values
          .where((t) => t.wireName == wireName)
          .firstOrNull;
  if (template == null) {
    json.fail(
      'expected one of '
          '${LiveActivityTemplate.values.map((t) => t.wireName).join(', ')}',
      'template',
    );
  }
  if (!template.isCustom) {
    for (final field in ['values', 'surfaces', 'android', 'androidDefaults']) {
      if (json.json.containsKey(field)) {
        json.fail(
          'a fixed template has its own values and views; only a custom card '
          'has $field',
          field,
        );
      }
    }
  }
  final values = [for (final value in json.children('values')) _value(value)];
  return LiveActivityDefinition(
    key: key,
    name: json.opt<String>('name') ?? key,
    description: json.opt<String>('description') ?? '',
    template: template,
    accentColor: json.opt<String>('accentColor'),
    icon: json.opt<String>('icon'),
    androidChannelName: json.opt<String>('androidChannelName') ?? '',
    values: values,
    surfaces: switch (json.optChild('surfaces')) {
      final surfaces? => _surfaces(surfaces, _layoutTypes(values)),
      null => const {},
    },
    android: switch (json.optChild('android')) {
      final android? => _android(android),
      null => const LiveActivityAndroid(),
    },
    androidDefaults:
        json.json['androidDefaults'] == null
            ? null
            : json.strings('androidDefaults'),
  );
}

LiveActivityValue _value(SpecJsonReader json) {
  json.only(const {'key', 'name', 'type', 'default', 'required'});
  final key = json.req<String>('key');
  final type = json.req<String>('type');
  return LiveActivityValue(
    key: key,
    name: json.opt<String>('name') ?? key,
    type:
        LiveActivityValueType.values.where((t) => t.name == type).firstOrNull ??
        json.fail(
          'expected one of '
              '${LiveActivityValueType.values.map((t) => t.name).join(', ')}',
          'type',
        ),
    defaultValue: json.opt<String>('default'),
    required: json.opt<bool>('required') ?? false,
  );
}

Map<LiveActivitySurface, NativeLayoutModel> _surfaces(
  SpecJsonReader json,
  Map<String, LayoutValueType> types,
) {
  json.only({for (final surface in LiveActivitySurface.values) surface.name});
  final surfaces = <LiveActivitySurface, NativeLayoutModel>{
    for (final surface in LiveActivitySurface.values)
      if (json.optChild(surface.name) case final layout?)
        surface: _readLayout(layout.json, layout.path, types, surface),
  };
  // No expanded island layout: the Lock Screen one, read for the island.
  // A second model, as the generators change the expanded one in place.
  const expanded = LiveActivitySurface.islandExpanded;
  if (!json.json.containsKey(expanded.name)) {
    if (json.optChild(LiveActivitySurface.lockScreen.name) case final lock?) {
      surfaces[expanded] = _readLayout(
        lock.json,
        lock.path,
        types,
        expanded,
        darkColors: true,
      );
    }
  }
  return surfaces;
}

LiveActivityAndroid _android(SpecJsonReader json) {
  json.only(const {'presentation', 'slots'});
  return LiveActivityAndroid(
    presentation: json.enumValue(
      'presentation',
      LiveActivityAndroidPresentation.values,
      LiveActivityAndroidPresentation.standard,
    ),
    slots: {
      for (final MapEntry(:key, :value) in json.strings('slots').entries)
        LiveActivityAndroidSlot.values
                    .where((slot) => slot.name == key)
                    .firstOrNull ??
                json.fail(
                  'unknown slot; expected one of '
                      '${LiveActivityAndroidSlot.values.map((s) => s.name).join(', ')}',
                  'slots.$key',
                ):
            value,
    },
  );
}
