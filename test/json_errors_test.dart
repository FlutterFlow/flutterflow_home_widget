import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_home_widget/flutterflow_home_widget.dart';
import 'package:test/test.dart';

typedef _Edit = void Function(Map<String, Object?> app, Map<String, Object?> w);

Map<String, Object?> _base() {
  final app =
      jsonDecode(File('example/widgets.json').readAsStringSync())
          as Map<String, Object?>;
  final w = (app['widgets']! as List<Object?>).first! as Map<String, Object?>;
  w['refresh'] = {
    'url': 'https://example.com/a',
    'headers': <String, Object?>{'X-Key': 'k'},
    'intervalMinutes': 30,
    'values': [
      {'key': 'glasses', 'type': 'integer', 'path': r'$.a.b[0]'},
    ],
  };
  w['configuration'] = {
    'title': 'Pick',
    'appChoices': true,
    'choices': [
      {
        'id': 'one',
        'name': 'One',
        'values': <String, Object?>{'glasses': '1'},
      },
    ],
  };
  return app;
}

Map<String, Object?> _at(Object? o) => o! as Map<String, Object?>;

/// Every message a user can see for invalid JSON, as `toString()` prints it.
/// These must not change when the reader changes.
final _cases = <String, ({_Edit edit, String message})>{
  'app is not an object': (
    edit: (app, w) => app['widgets'] = [1],
    message: r'HomeWidgetJsonException at $.widgets[0]: expected an object',
  ),
  'missing bundle id': (
    edit: (app, w) => app.remove('iosBundleId'),
    message: r'HomeWidgetJsonException at $.iosBundleId: missing a string',
  ),
  'bundle id wrong type': (
    edit: (app, w) => app['iosBundleId'] = 3,
    message:
        r'HomeWidgetJsonException at $.iosBundleId: expected a string, got int',
  ),
  'routes wrong type': (
    edit: (app, w) => app['routes'] = [],
    message:
        r'HomeWidgetJsonException at $.routes: expected an object, got List<dynamic>',
  ),
  'encodeTwice wrong type': (
    edit: (app, w) => _at(app['routes'])['encodeTwice'] = 'yes',
    message:
        r'HomeWidgetJsonException at $.routes.encodeTwice: expected true or false, got String',
  ),
  'widgets wrong type': (
    edit: (app, w) => app['widgets'] = 'x',
    message:
        r'HomeWidgetJsonException at $.widgets: expected a list, got String',
  ),
  'widget missing key': (
    edit: (app, w) => w.remove('key'),
    message: r'HomeWidgetJsonException at $.widgets[0].key: missing a string',
  ),
  'value missing key': (
    edit: (app, w) => _at((w['values']! as List).first).remove('key'),
    message:
        r'HomeWidgetJsonException at $.widgets[0].values[0].key: missing a string',
  ),
  'value unknown type': (
    edit: (app, w) => _at((w['values']! as List).first)['type'] = 'blob',
    message:
        r'HomeWidgetJsonException at $.widgets[0].values[0].type: expected one of string, integer, double, boolean, dateTime, color',
  ),
  'value missing type': (
    edit: (app, w) => _at((w['values']! as List).first).remove('type'),
    message:
        r'HomeWidgetJsonException at $.widgets[0].values[0].type: missing a string',
  ),
  'layouts missing': (
    edit: (app, w) => w.remove('layouts'),
    message:
        r'HomeWidgetJsonException at $.widgets[0].layouts: missing an object',
  ),
  'layouts unknown size': (
    edit: (app, w) => _at(w['layouts'])['huge'] = {},
    message:
        r'HomeWidgetJsonException at $.widgets[0].layouts.huge: unknown size; expected one of small, medium, large, accessoryCircular, accessoryRectangular, accessoryInline',
  ),
  'layout root type': (
    edit: (app, w) => _at(_at(w['layouts'])['small'])['root'] = {
      'type': 'slider',
      'key': 'x',
    },
    message:
        r'HomeWidgetJsonException at $.widgets[0].layouts.small.root.type: unknown node type; expected box, row, column, stack, text, image, icon, spacer, divider or progress',
  ),
  'layout text unknown value': (
    edit: (app, w) => _at(_at(w['layouts'])['small'])['root'] = {
      'type': 'text',
      'key': 't',
      'value': 'nope',
    },
    message:
        r'HomeWidgetJsonException at $.widgets[0].layouts.small.root.value: '
        'no value "nope" in the widget\'s values',
  ),
  'layout bad color': (
    edit: (app, w) => _at(_at(w['layouts'])['small'])['root'] = {
      'type': 'text',
      'key': 't',
      'text': 'x',
      'color': 'red',
    },
    message:
        r'HomeWidgetJsonException at $.widgets[0].layouts.small.root.color: expected "#AARRGGBB" or "#RRGGBB"',
  ),
  'refresh missing url': (
    edit: (app, w) => _at(w['refresh']).remove('url'),
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.url: missing a string',
  ),
  'refresh header not a string': (
    edit: (app, w) => _at(_at(w['refresh'])['headers'])['X-Key'] = 1,
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.headers.X-Key: expected a string',
  ),
  'refresh interval wrong type': (
    edit: (app, w) => _at(w['refresh'])['intervalMinutes'] = 'soon',
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.intervalMinutes: expected a number, got String',
  ),
  'refresh value bad path': (
    edit: (app, w) =>
        _at((_at(w['refresh'])['values']! as List).first)['path'] = r'$..a',
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.values[0].path: a widget reads only plain paths: $.a.b[0]',
  ),
  'refresh value item not an object': (
    edit: (app, w) => _at(w['refresh'])['values'] = ['x'],
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.values[0]: expected an object',
  ),
  'refresh value bad type': (
    edit: (app, w) =>
        _at((_at(w['refresh'])['values']! as List).first)['type'] = 'x',
    message:
        r'HomeWidgetJsonException at $.widgets[0].refresh.values[0].type: expected one of string, integer, double, boolean, dateTime, color',
  ),
  'configuration choice missing id': (
    edit: (app, w) =>
        _at((_at(w['configuration'])['choices']! as List).first).remove('id'),
    message:
        r'HomeWidgetJsonException at $.widgets[0].configuration.choices[0].id: missing a string',
  ),
  'configuration choice value not a string': (
    edit: (app, w) =>
        _at((_at(w['configuration'])['choices']! as List).first)['values'] = {
          'glasses': 2,
        },
    message:
        r'HomeWidgetJsonException at $.widgets[0].configuration.choices[0].values.glasses: expected a string',
  ),
  'configuration appChoices wrong type': (
    edit: (app, w) => _at(w['configuration'])['appChoices'] = 'yes',
    message:
        r'HomeWidgetJsonException at $.widgets[0].configuration.appChoices: expected true or false, got String',
  ),
};

void main() {
  test('the base JSON reads', () {
    expect(() => homeWidgetAppFromJson(_base()), returnsNormally);
  });

  group('error messages and paths', () {
    for (final MapEntry(:key, :value) in _cases.entries) {
      test(key, () {
        final app = _base();
        final w =
            (app['widgets']! as List<Object?>).first! as Map<String, Object?>;
        value.edit(app, w);
        Object? thrown;
        try {
          homeWidgetAppFromJson(app);
        } on Object catch (e) {
          thrown = e;
        }
        if (Platform.environment.containsKey('PIN_PRINT')) {
          // ignore: avoid_print
          print('PIN|$key|$thrown|${thrown.runtimeType}');
        }
        expect(thrown, isA<HomeWidgetJsonException>());
        expect(thrown.toString(), value.message);
      });
    }
  });
}
