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
import 'package:flutterflow_native_layout/layout_json.dart';

/// Thrown when JSON does not describe a valid spec. [path] says where.
class HomeWidgetJsonException implements Exception {
  HomeWidgetJsonException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'HomeWidgetJsonException at $path: $message';
}

/// The app [json] describes.
HomeWidgetApp homeWidgetAppFromJson(Map<String, Object?> json) {
  try {
    return _app(SpecJsonReader(json, r'$'));
  } on NativeLayoutJsonException catch (e) {
    throw HomeWidgetJsonException(e.path, e.message);
  }
}

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
//
// Errors are thrown as the shared reader's `NativeLayoutJsonException`;
// `homeWidgetAppFromJson` rethrows them as a `HomeWidgetJsonException`.

HomeWidgetApp _app(SpecJsonReader json) => HomeWidgetApp(
  iosBundleId: json.req<String>('iosBundleId'),
  iosDeviceFamily: json.opt<String>('iosDeviceFamily') ?? '1',
  routes: switch (json.optChild('routes')) {
    final routes? => HomeWidgetRoutes(
      scheme: routes.opt<String>('scheme') ?? '',
      host: routes.opt<String>('host') ?? '',
      encodeTwice: routes.opt<bool>('encodeTwice') ?? true,
    ),
    null => const HomeWidgetRoutes(scheme: ''),
  },
  widgets: [for (final widget in json.children('widgets')) _widget(widget)],
);

HomeWidgetDefinition _widget(SpecJsonReader json) {
  final values = [
    for (final value in json.children('values'))
      HomeWidgetValue(
        key: value.req<String>('key'),
        name: value.opt<String>('name') ?? value.req<String>('key'),
        type: _valueType(value, 'type'),
        defaultValue: value.opt<String>('default'),
      ),
  ];
  final types = {for (final value in values) value.key: value.type};
  final layoutsJson = json.child('layouts');
  final layouts = <HomeWidgetSize, HomeWidgetLayoutModel>{};
  for (final size in HomeWidgetSize.values) {
    if (layoutsJson.optChild(size.name) case final layout?) {
      layouts[size] = nativeLayoutFromJson(
        layout.json,
        types: types,
        path: layout.path,
        owner: 'widget',
      );
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
    key: json.req<String>('key'),
    name: json.opt<String>('name') ?? '',
    description: json.opt<String>('description') ?? '',
    placeholderText: json.opt<String>('placeholderText') ?? '',
    values: values,
    layouts: layouts,
    refresh: json.optChild('refresh')?.let(_refresh),
    configuration: json.optChild('configuration')?.let(_configuration),
  );
}

HomeWidgetValueType _valueType(SpecJsonReader json, String key) {
  final id = json.req<String>(key);
  for (final type in HomeWidgetValueType.values) {
    if (type.id == id) {
      return type;
    }
  }
  json.fail(
    'expected one of ${HomeWidgetValueType.values.map((t) => t.id).join(', ')}',
    key,
  );
}

HomeWidgetRefreshPlan _refresh(SpecJsonReader json) => HomeWidgetRefreshPlan(
  url: json.req<String>('url'),
  headers: json.strings('headers'),
  intervalMinutes:
      (json.opt<num>('intervalMinutes') ?? kHomeWidgetMinRefreshMinutes)
          .toInt(),
  values: [
    for (final value in json.children('values'))
      FetchedValue(
        value.req<String>('key'),
        _valueType(value, 'type'),
        parseJsonPath(value.req<String>('path')) ??
            value.fail('a widget reads only plain paths: \$.a.b[0]', 'path'),
      ),
  ],
);

HomeWidgetConfiguration _configuration(SpecJsonReader json) =>
    HomeWidgetConfiguration(
      title: json.opt<String>('title') ?? '',
      appChoices: json.opt<bool>('appChoices') ?? false,
      choices: [
        for (final choice in json.children('choices'))
          HomeWidgetChoice(
            id: choice.req<String>('id'),
            name: choice.opt<String>('name') ?? choice.req<String>('id'),
            values: choice.strings('values'),
          ),
      ],
    );
