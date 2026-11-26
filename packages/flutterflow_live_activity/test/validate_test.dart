import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

typedef _Json = Map<String, Object?>;

/// The example spec, edited by [edit].
LiveActivityApp _example([void Function(_Json json)? edit]) {
  final json =
      jsonDecode(File('example/live_activities.json').readAsStringSync())
          as _Json;
  edit?.call(json);
  return liveActivityAppFromJson(json);
}

_Json _card(_Json json) =>
    (json['activities']! as List<Object?>).first! as _Json;

List<Object?> _values(_Json json) => _card(json)['values']! as List<Object?>;

_Json _surfaces(_Json json) => _card(json)['surfaces']! as _Json;

_Json _lock(_Json json) => _surfaces(json)['lockScreen']! as _Json;

/// The column of the Lock Screen card: its children are the top row, the
/// Stages bar and the count-up text.
List<Object?> _content(_Json json) =>
    (((_lock(json)['root']! as _Json)['child']! as _Json)['children']!
        as List<Object?>);

/// The node of the Lock Screen card at [i] of [_content].
_Json _node(_Json json, int i) => _content(json)[i]! as _Json;

_Json _stages(_Json json) => _node(json, 1)['stages']! as _Json;

List<String> _problems(LiveActivityApp app) => [
  for (final problem in validateLiveActivityApp(app)) problem.toString(),
];

/// The problems of the example edited by [edit].
List<String> _of(void Function(_Json json) edit) => _problems(_example(edit));

const _at = 'activities[0] ("delivery")';
const _lockAt = '$_at.surfaces.lockScreen';

void main() {
  test('the example has no problems', () {
    expect(_problems(_example()), isEmpty);
  });

  group('app', () {
    test('version, bundle id and activities', () {
      expect(
        _problems(
          LiveActivityApp(
            iosBundleId: ' ',
            iosDeviceFamily: '1',
            routes: const LiveActivityRoutes(scheme: 'rides'),
            activities: const [],
            specVersion: 2,
          ),
        ),
        [
          'specVersion: is 2; this package generates version 1.',
          'iosBundleId: is empty. The Live Activity extension is named after '
              'it.',
          'activities: is empty.',
        ],
      );
    });

    test('keys need different native names; class names may clash', () {
      final problems = _problems(
        appWith([
          fixedCard(LiveActivityTemplate.progress, key: 'my_ride'),
          fixedCard(LiveActivityTemplate.progress, key: 'my-ride'),
          fixedCard(LiveActivityTemplate.progress, key: 'myRide'),
        ]),
      );
      expect(problems, [
        contains(
          'activities[1] ("my-ride"): has the native name of '
          '"my_ride"',
        ),
        'warning: activities[1] ("my-ride"): has the Dart class name of '
            '"my_ride", so it is MyRideLiveActivity2 in the typed API.',
        'warning: activities[2] ("myRide"): has the Dart class name of '
            '"my_ride", so it is MyRideLiveActivity3 in the typed API.',
      ]);
    });

    test('accent color and icon', () {
      expect(
        _of((json) {
          _card(json)['accentColor'] = '#2F80ED';
          _card(json)['icon'] = 'images/icon.png';
        }),
        [
          '$_at.accentColor: is "#2F80ED", not #AARRGGBB.',
          startsWith('$_at.icon: shows "images/icon.png".'),
        ],
      );
    });

    test('a fixed template has no values, layouts or Android settings', () {
      final problems = _problems(
        appWith([
          LiveActivityDefinition(
            key: 'la_order',
            name: 'Order',
            template: LiveActivityTemplate.progress,
            values: rideValues,
            surfaces: {LiveActivitySurface.lockScreen: lockLayout()},
            android: const LiveActivityAndroid(
              presentation: LiveActivityAndroidPresentation.custom,
            ),
            androidDefaults: const {},
          ),
        ]),
      );
      expect(problems, [
        for (final field in [
          'values',
          'surfaces',
          'android',
          'androidDefaults',
        ])
          'activities[0] ("la_order").$field: is set, but the progress '
              'template has its own values and views. Only a custom card '
              'uses it.',
      ]);
    });
  });

  group('values', () {
    test('at most 24, and at most 4 images', () {
      expect(
        _of(
          (json) => _values(json).addAll([
            for (var i = 0; i < 13; i++) {'key': 'text$i', 'type': 'string'},
            for (var i = 0; i < 4; i++)
              {'key': 'photo$i', 'type': 'image', 'default': 'assets/p.png'},
          ]),
        ),
        containsAll([
          '$_at.values: has 25 values. A card holds at most 24.',
          '$_at.values: has 5 image values. A card holds at most 4.',
        ]),
      );
    });

    test('keys, defaults and Dart names', () {
      expect(
        _of(
          (json) => _values(json).addAll([
            {'key': 'title', 'type': 'string'},
            {'key': 'count', 'type': 'integer', 'default': '1.5'},
            {'key': 'shown', 'type': 'boolean', 'default': 'yes'},
            {'key': 'shade', 'type': 'color', 'default': 'red'},
            {'key': 'van', 'type': 'image', 'default': 'https://x.com/v.png'},
            {'key': 'eta_time', 'type': 'string'},
            {'key': 'etaTime', 'type': 'string'},
          ]),
        ),
        [
          '$_at.values: has "title" twice.',
          '$_at.values "count": has a default that is not a integer (1.5).',
          '$_at.values "shown": has a default that is not a boolean (yes).',
          '$_at.values "shade": has a default that is not a color (red).',
          startsWith(
            '$_at.values "van": has a default that is not an asset of the '
            'app: https://x.com/v.png.',
          ),
          'warning: $_at.values "etaTime": has the Dart name of "eta_time", '
              'so it is etaTime2 in the typed API.',
        ],
      );
    });
  });

  group('layouts', () {
    test('the Lock Screen and the expanded island are needed', () {
      expect(_of((json) => _surfaces(json)['islandExpanded'] = null), [
        '$_at.surfaces: has no islandExpanded layout. iOS cannot show the '
            'card without it.',
      ]);
    });

    test('at most 80 nodes', () {
      expect(
        _of(
          (json) =>
              _surfaces(json)['islandMinimal'] = {
                'root': {
                  'type': 'stack',
                  'key': 'many',
                  'children': [
                    for (var i = 0; i < 80; i++)
                      {'type': 'icon', 'key': 'i$i', 'codePoint': 0xe558},
                  ],
                },
              },
        ),
        [
          '$_at.surfaces.islandMinimal: has 81 nodes. A card layout holds at '
              'most 80.',
        ],
      );
    });

    test('node keys', () {
      expect(
        _of((json) {
          _node(json, 2)['key'] = 'titleText';
          _content(json).add({'type': 'text', 'key': '', 'text': 'Hi'});
        }),
        [
          '$_lockAt node "titleText": has the key of another node in the '
              'layout.',
          '$_lockAt node "": needs a key with letters or digits.',
        ],
      );
    });

    test('what a node reads must be of its type', () {
      expect(
        _of((json) {
          _node(json, 2)
            ..['value'] = 'status'
            ..['visibleIf'] = 'title'
            ..['color'] = {'value': 'title'};
          _content(json).addAll([
            {
              'type': 'progress',
              'key': 'p1',
              'value': {'value': 'status'},
            },
            {
              'type': 'progress',
              'key': 'p3',
              'value': 0,
              'timed': {'start': 'sent', 'end': 'stage'},
            },
            {
              'type': 'image',
              'key': 'pic',
              'value': 'courier',
              'asset': 'images/courier.png',
            },
            {'type': 'image', 'key': 'pic2', 'asset': ''},
          ]);
        }),
        [
          '$_lockAt node "since" visibleIf: reads "title" as boolean, but it '
              'is a string.',
          '$_lockAt node "since": reads "status" as dateTime, but it is a '
              'string.',
          '$_lockAt node "since" color: reads "title" as color, but it is a '
              'string.',
          '$_lockAt node "p1": reads "status" as integer or double, but it is '
              'a string.',
          '$_lockAt node "p3" timed end: reads "stage" as dateTime, but it is '
              'a integer.',
          startsWith('$_lockAt node "pic": shows "images/courier.png".'),
          startsWith('$_lockAt node "pic2": shows "".'),
          startsWith('$_lockAt: needs at least '),
        ],
      );
    });

    test('a bar fills from 0 to 1, between both dates when timed', () {
      final lock = NativeLayoutModel(
        LayoutProgress(
          'Bar_1',
          circular: false,
          value: const LayoutFraction.fixed(1.5),
        )..timedStart = 'v_eta',
        const [],
      );
      expect(
        _problems(
          appWith([
            rideCard(
              surfaces: {
                LiveActivitySurface.lockScreen: lock,
                LiveActivitySurface.islandExpanded: expandedLayout(),
              },
              android: const LiveActivityAndroid(
                presentation: LiveActivityAndroidPresentation.custom,
              ),
            ),
          ]),
        ),
        [
          'activities[0] ("la_ride").surfaces.lockScreen node "Bar_1": shows '
              '1.5, outside 0 to 1.',
          'activities[0] ("la_ride").surfaces.lockScreen node "Bar_1": fills '
              'between two dates: set both, start and end.',
        ],
      );
    });

    test('a value no layout knows, read from a layout built in Dart', () {
      final lock = NativeLayoutModel(
        LayoutTextNode(
          'Text_1',
          const LayoutParamText('v_nope', LayoutValueType.string),
        ),
        const [LayoutIssue('Text_1', 'Its font is not drawn on a card.')],
      );
      expect(
        _problems(
          appWith([
            rideCard(
              surfaces: {
                LiveActivitySurface.lockScreen: lock,
                LiveActivitySurface.islandExpanded: expandedLayout(),
              },
              android: const LiveActivityAndroid(
                presentation: LiveActivityAndroidPresentation.custom,
              ),
            ),
          ]),
        ),
        [
          'activities[0] ("la_ride").surfaces.lockScreen node "Text_1": Its '
              'font is not drawn on a card.',
          'activities[0] ("la_ride").surfaces.lockScreen node "Text_1": reads '
              '"v_nope", which is not one of the card\'s values.',
        ],
      );
    });
  });

  group('stages', () {
    test('2 to 6 stages, of integer and double values', () {
      expect(
        _of((json) {
          final stages =
              _stages(json)
                ..['current'] = 'within'
                ..['progress'] = 'stage';
          (stages['items']! as List<Object?>).addAll([
            for (var i = 0; i < 4; i++) {'key': 's$i', 'label': 'S$i'},
          ]);
        }),
        [
          '$_lockAt node "stages": has 7 stages. A bar has 2 to 6.',
          '$_lockAt node "stages" current stage: reads "within" as integer, '
              'but it is a double.',
          '$_lockAt node "stages" progress in the stage: reads "stage" as '
              'double, but it is a integer.',
        ],
      );
    });

    test('a ring, stage keys and labels', () {
      expect(
        _of((json) {
          _node(json, 1)['circular'] = true;
          _stages(json)['items'] = [
            {'key': 'a', 'label': ''},
            {
              'key': 'a',
              'label': {'value': 'stage'},
            },
          ];
        }),
        [
          '$_lockAt node "stages": is a ring. Only a linear bar can be drawn '
              'as stages.',
          '$_lockAt node "stages": has the stage "a" twice.',
          '$_lockAt node "stages" stage "a" label: reads "stage" as string, '
              'but it is a integer.',
          'warning: $_lockAt node "stages": Stage 1 has no label. Name it, or '
              'hide the labels.',
        ],
      );
    });

    test('a bar of one stage', () {
      expect(
        _of(
          (json) =>
              _stages(json)['items'] = [
                {'key': 'a', 'label': 'A'},
              ],
        ),
        ['$_lockAt node "stages": has 1 stages. A bar has 2 to 6.'],
      );
    });
  });

  group('taps', () {
    test('a tap only opens a page of the app', () {
      expect(
        _of((json) {
          json['routes'] = {'scheme': ''};
          final expanded = _surfaces(json)['islandExpanded']! as _Json;
          expanded['tap'] = {
            'openPage': 'orders',
            'params': [
              {'name': 'id', 'value': 'courier'},
            ],
          };
          (expanded['root']! as _Json)['tap'] = {'toggle': 'title'};
        }),
        [
          '$_at.surfaces.islandExpanded.tap: opens a page, but the app has no '
              'route scheme.',
          '$_at.surfaces.islandExpanded.tap: opens "orders", which does not '
              'start with "/".',
          '$_at.surfaces.islandExpanded.tap param "id": reads "courier" as '
              'string or integer or double or boolean or dateTime or color, '
              'but it is a image.',
          '$_at.surfaces.islandExpanded node "ex" tap: is a button. A card '
              'has no buttons: a tap can only open a page.',
        ],
      );
    });
  });

  group('height', () {
    test('a card taller than its surface is cut off', () {
      expect(_of((json) => (_lock(json)['root']! as _Json)['height'] = 200), [
        '$_lockAt: is 200 points tall. iOS shows 160: what is below that is '
            'cut off.',
      ]);
      expect(
        _of(
          (json) =>
              _content(json).add({'type': 'box', 'key': 'tall', 'height': 120}),
        ),
        [
          startsWith('$_lockAt: needs at least '),
          // The tall box is drawn, and so are the others.
        ],
      );
    });

    test('one that may be cut off is a warning', () {
      // Without the late notice the card fits; with it, it may not.
      expect(
        _of((json) {
          _values(json).add({'key': 'late', 'type': 'boolean'});
          _content(json).add({
            'type': 'text',
            'key': 'lateNotice',
            'text': 'Running late',
            'fontSize': 30,
            'visibleIf': 'late',
          });
        }),
        [startsWith('warning: $_lockAt: is about ')],
      );
    });
  });

  group('android', () {
    test('slots and defaults name values of the right type', () {
      expect(
        _of((json) {
          _card(json)['android'] = {
            'presentation': 'custom',
            'slots': {'title': 'stage', 'text': 'nope'},
          };
          _card(json)['androidDefaults'] = {'nope': 'x'};
        }),
        [
          '$_at.android.slots.title: shows "stage", a integer; this part '
              'shows a string.',
          '$_at.android.slots.text: shows "nope", which is not one of the '
              'card\'s values.',
          '$_at.androidDefaults: has a default for "nope", which is not one '
              'of the card\'s values.',
        ],
      );
    });

    test('a drawn card that opens a page is a standard one on Android', () {
      expect(_of((json) => _lock(json)['tap'] = {'openPage': '/orders'}), [
        'warning: $_at.android: draws the Lock Screen layout, but its node '
            '"card" (or the layout) opens a page on tap. A drawn Live '
            'Update cannot be tapped, so Android shows the standard one '
            'instead.',
      ]);
    });

    test('the standard Live Update says what it leaves out', () {
      expect(_of((json) => _card(json).remove('android')), [
        'warning: $_at.android: uses the standard Live Update, which has '
            'places for a title, a text, a bar, a countdown and one picture. '
            'It does not show "sent". Stage labels and icons are not '
            'drawn. Name the values its parts show (android.slots), or draw '
            'the card (android.presentation: custom).',
      ]);
    });
  });
}
