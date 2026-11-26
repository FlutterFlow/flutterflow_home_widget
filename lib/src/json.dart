/// The JSON form of a [HomeWidgetApp], for tools that write the spec rather
/// than build it in Dart. `doc/spec.md` describes every field.
///
/// Colors are `#AARRGGBB` (or `#RRGGBB`, opaque), or `{"light": …, "dark":
/// …}` for a color with a dark-mode value. A paint (a fill or text color) is
/// a color or `{"value": key}`, a Color value of the widget. Lengths are a
/// number of points, `"fill"` or `"fit"` (the default).
///
/// Layouts are read and written by `flutterflow_native_layout`
/// ([nativeLayoutFromJson], [nativeLayoutToJson]), which Live Activity cards
/// share.
library;

import 'package:flutterflow_home_widget/src/refresh.dart';
import 'package:flutterflow_home_widget/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// Thrown when JSON does not describe a valid spec. [path] says where.
class HomeWidgetJsonException implements Exception {
  HomeWidgetJsonException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'HomeWidgetJsonException at $path: $message';
}

/// The app [json] describes.
HomeWidgetApp homeWidgetAppFromJson(Map<String, Object?> json) =>
    _Reader(json, r'$').app();

/// [app] as JSON. `homeWidgetAppFromJson(homeWidgetAppToJson(app))`
/// generates the same files as [app].
Map<String, Object?> homeWidgetAppToJson(HomeWidgetApp app) => {
  'iosBundleId': app.iosBundleId,
  'iosDeviceFamily': app.iosDeviceFamily,
  'routes': {
    'scheme': app.routes.scheme,
    'host': app.routes.host,
    'encodeTwice': app.routes.encodeTwice,
  },
  'widgets': [for (final widget in app.widgets) _widgetToJson(widget)],
};

Map<String, Object?> _widgetToJson(HomeWidgetDefinition widget) => {
  'key': widget.key,
  'name': widget.name,
  if (widget.description.isNotEmpty) 'description': widget.description,
  if (widget.placeholderText.isNotEmpty)
    'placeholderText': widget.placeholderText,
  'values': [
    for (final value in widget.values)
      {
        'key': value.key,
        'name': value.name,
        'type': value.type.id,
        if (value.defaultValue != null) 'default': value.defaultValue,
      },
  ],
  'layouts': {
    for (final (size, layout) in widget.sizedLayouts)
      size.name: nativeLayoutToJson(layout),
  },
  if (widget.refresh case final refresh?)
    'refresh': {
      'url': refresh.url,
      if (refresh.headers.isNotEmpty) 'headers': refresh.headers,
      'intervalMinutes': refresh.intervalMinutes,
      'values': [
        for (final value in refresh.values)
          {
            'key': value.key,
            'type': value.type.id,
            'path': _jsonPathString(value.path),
          },
      ],
    },
  if (widget.configuration case final configuration?)
    'configuration': {
      if (configuration.title.isNotEmpty) 'title': configuration.title,
      'choices': [
        for (final choice in configuration.choices)
          {'id': choice.id, 'name': choice.name, 'values': choice.values},
      ],
      'appChoices': configuration.appChoices,
    },
};

String _jsonPathString(List<JsonStep> path) => [
  r'$',
  for (final step in path)
    switch (step) {
      JsonKey(:final name) =>
        RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(name) ? '.$name' : "['$name']",
      JsonIndex(:final index) => '[$index]',
    },
].join();

// --- Reading ----------------------------------------------------------------

class _Reader {
  _Reader(this.json, this.path);

  final Map<String, Object?> json;
  final String path;

  Never fail(String message, [String? key]) =>
      throw HomeWidgetJsonException(key == null ? path : '$path.$key', message);

  T? opt<T>(String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (T == double && value is num) {
      return value.toDouble() as T;
    }
    if (value is! T) {
      fail('expected ${_typeName<T>()}, got ${value.runtimeType}', key);
    }
    return value as T;
  }

  T req<T>(String key) => opt<T>(key) ?? fail('missing ${_typeName<T>()}', key);

  _Reader child(String key) =>
      _Reader(req<Map<String, Object?>>(key), '$path.$key');

  _Reader? optChild(String key) => json[key] == null ? null : child(key);

  List<_Reader> children(String key) {
    final list = opt<List<Object?>>(key) ?? const [];
    return [
      for (var i = 0; i < list.length; i++)
        if (list[i] case final Map<String, Object?> item)
          _Reader(item, '$path.$key[$i]')
        else
          fail('expected an object', '$key[$i]'),
    ];
  }

  E enumValue<E extends Enum>(String key, List<E> values, E fallback) {
    final name = opt<String>(key);
    if (name == null) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    fail('expected one of ${values.map((v) => v.name).join(', ')}', key);
  }

  HomeWidgetApp app() => HomeWidgetApp(
    iosBundleId: req<String>('iosBundleId'),
    iosDeviceFamily: opt<String>('iosDeviceFamily') ?? '1',
    routes: switch (optChild('routes')) {
      final routes? => HomeWidgetRoutes(
        scheme: routes.opt<String>('scheme') ?? '',
        host: routes.opt<String>('host') ?? '',
        encodeTwice: routes.opt<bool>('encodeTwice') ?? true,
      ),
      null => const HomeWidgetRoutes(scheme: ''),
    },
    widgets: [for (final widget in children('widgets')) widget.widget()],
  );

  HomeWidgetDefinition widget() {
    final values = [
      for (final value in children('values'))
        HomeWidgetValue(
          key: value.req<String>('key'),
          name: value.opt<String>('name') ?? value.req<String>('key'),
          type: value.valueType('type'),
          defaultValue: value.opt<String>('default'),
        ),
    ];
    final types = {for (final value in values) value.key: value.type};
    final layoutsJson = child('layouts');
    final layouts = <HomeWidgetSize, HomeWidgetLayoutModel>{};
    for (final size in HomeWidgetSize.values) {
      if (layoutsJson.optChild(size.name) case final layout?) {
        layouts[size] = layout.layout(types);
      }
    }
    for (final key in layoutsJson.json.keys) {
      if (!HomeWidgetSize.values.any((size) => size.name == key)) {
        layoutsJson.fail(
          'unknown size; expected one of '
          '${HomeWidgetSize.values.map((s) => s.name).join(', ')}',
          key,
        );
      }
    }
    return HomeWidgetDefinition(
      key: req<String>('key'),
      name: opt<String>('name') ?? '',
      description: opt<String>('description') ?? '',
      placeholderText: opt<String>('placeholderText') ?? '',
      values: values,
      layouts: layouts,
      refresh: optChild('refresh')?.refresh(),
      configuration: optChild('configuration')?.configuration(),
    );
  }

  HomeWidgetValueType valueType(String key) {
    final id = req<String>(key);
    for (final type in HomeWidgetValueType.values) {
      if (type.id == id) {
        return type;
      }
    }
    fail(
      'expected one of ${HomeWidgetValueType.values.map((t) => t.id).join(', ')}',
      key,
    );
  }

  HomeWidgetRefreshPlan refresh() => HomeWidgetRefreshPlan(
    url: req<String>('url'),
    headers: {
      for (final MapEntry(:key, :value)
          in (opt<Map<String, Object?>>('headers') ?? const {}).entries)
        key: value is String
            ? value
            : fail('expected a string', 'headers.$key'),
    },
    intervalMinutes:
        (opt<num>('intervalMinutes') ?? kHomeWidgetMinRefreshMinutes).toInt(),
    values: [
      for (final value in children('values'))
        FetchedValue(
          value.req<String>('key'),
          value.valueType('type'),
          parseJsonPath(value.req<String>('path')) ??
              value.fail('a widget reads only plain paths: \$.a.b[0]', 'path'),
        ),
    ],
  );

  HomeWidgetConfiguration configuration() => HomeWidgetConfiguration(
    title: opt<String>('title') ?? '',
    appChoices: opt<bool>('appChoices') ?? false,
    choices: [
      for (final choice in children('choices'))
        HomeWidgetChoice(
          id: choice.req<String>('id'),
          name: choice.opt<String>('name') ?? choice.req<String>('id'),
          values: {
            for (final MapEntry(:key, :value)
                in (choice.opt<Map<String, Object?>>('values') ?? const {})
                    .entries)
              key: value is String
                  ? value
                  : choice.fail('expected a string', 'values.$key'),
          },
        ),
    ],
  );

  HomeWidgetLayoutModel layout(Map<String, HomeWidgetValueType> types) {
    try {
      return nativeLayoutFromJson(
        json,
        types: types,
        path: path,
        owner: 'widget',
      );
    } on NativeLayoutJsonException catch (e) {
      throw HomeWidgetJsonException(e.path, e.message);
    }
  }
}

String _typeName<T>() => switch (T) {
  const (String) => 'a string',
  const (bool) => 'true or false',
  const (double) || const (num) => 'a number',
  const (List<Object?>) => 'a list',
  const (Map<String, Object?>) => 'an object',
  _ => '$T',
};
