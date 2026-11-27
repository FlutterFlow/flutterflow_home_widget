import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

Map<String, Object?> _example() =>
    jsonDecode(File('example/live_activities.json').readAsStringSync())
        as Map<String, Object?>;

LiveActivityApp _app([void Function(Map<String, Object?> json)? edit]) {
  final json = _example();
  edit?.call(json);
  return liveActivityAppFromJson(json);
}

Map<String, Object?> _activity(Map<String, Object?> json, [int i = 0]) =>
    (json['activities']! as List<Object?>)[i]! as Map<String, Object?>;

Map<String, Object?> _surfaces(Map<String, Object?> json) =>
    _activity(json)['surfaces']! as Map<String, Object?>;

/// Every text generated from [app], the typed API included.
Map<String, String> _files(LiveActivityApp app) => {
  ...generateLiveActivityFiles(app),
  ...liveActivityTypedApiFiles(app),
  for (final (i, fragment) in liveActivityPbxprojFragments(app).indexed)
    'pbxproj $i': fragment,
  'Info.plist': liveActivityRunnerInfoPlistEntries(app),
};

/// [app] through JSON text and back.
LiveActivityApp _roundTrip(LiveActivityApp app) => liveActivityAppFromJson(
  jsonDecode(jsonEncode(liveActivityAppToJson(app))) as Map<String, Object?>,
);

Matcher _throwsAt(String path, [String? message]) => throwsA(
  isA<LiveActivityJsonException>()
      .having((e) => e.path, 'path', path)
      .having((e) => e.message, 'message', contains(message ?? '')),
);

void main() {
  group('round trip', () {
    test('the example generates the same files after JSON', () {
      final app = _app();
      final back = _roundTrip(app);
      expect(liveActivityAppToJson(back), liveActivityAppToJson(app));
      expect(_files(back), _files(app));
    });

    test('a spec built in Dart generates the same files after JSON', () {
      final app = appWith([
        rideCard(
          surfaces: {
            LiveActivitySurface.lockScreen: lockLayout(
              tap: const LayoutOpenPage('/ride', []),
            ),
            LiveActivitySurface.islandExpanded: expandedLayout(),
            LiveActivitySurface.islandCompactLeading: compactLayout(
              photo: true,
            ),
            LiveActivitySurface.islandMinimal: compactLayout(),
          },
          android: const LiveActivityAndroid(
            presentation: LiveActivityAndroidPresentation.custom,
            slots: {LiveActivityAndroidSlot.title: 'v_driver'},
          ),
          androidDefaults: const {'v_title': 'Your ride', 'v_done': '0.25'},
        ),
        fixedCard(LiveActivityTemplate.etaTimer),
      ], deviceFamily: '"1,2"');
      final back = _roundTrip(app);
      expect(_files(back), _files(app));
      expect(back.activities.first.androidDefaults, {
        'v_title': 'Your ride',
        'v_done': '0.25',
      });
    });

    test('a value read from JSON keeps its type, default and need', () {
      final card = _app().activities.first;
      expect(card.value('eta')!.required, isTrue);
      expect(card.value('stage')!.type, LiveActivityValueType.integer);
      expect(card.value('courier')!.defaultValue, 'assets/images/courier.png');
      expect(card.value('title')!.name, 'Title');
    });

    test('a fixed template is a preset: no values, no layouts', () {
      final upload = _app().activities.last;
      expect(upload.template, LiveActivityTemplate.progress);
      expect(upload.values, isEmpty);
      expect(upload.surfaces, isEmpty);
      expect(upload.accentColor, '#FF34C759');
    });
  });

  group('expanded island', () {
    test('without one, the Lock Screen layout is read for the island', () {
      final app = _app((json) => _surfaces(json).remove('islandExpanded'));
      final card = app.activities.first;
      final lock = card.surfaces[LiveActivitySurface.lockScreen]!;
      final expanded = card.surfaces[LiveActivitySurface.islandExpanded]!;
      expect(identical(lock, expanded), isFalse);
      final title = expanded.nodes.whereType<LayoutTextNode>().first;
      // The dark color, light and dark.
      expect(title.color.color!.light, 0xFFFFFFFF);
      expect(title.color.color!.dark, 0xFFFFFFFF);
      // Writing it leaves it out again.
      final surfaces =
          (liveActivityAppToJson(app)['activities']! as List<Object?>).first!
              as Map<String, Object?>;
      expect(
        (surfaces['surfaces']! as Map<String, Object?>).keys,
        isNot(contains('islandExpanded')),
      );
      expect(_files(_roundTrip(app)), _files(app));
    });

    test('null leaves it empty, and stays null when written', () {
      final app = _app((json) => _surfaces(json)['islandExpanded'] = null);
      final card = app.activities.first;
      expect(
        card.surfaces.keys,
        isNot(contains(LiveActivitySurface.islandExpanded)),
      );
      final json =
          (liveActivityAppToJson(app)['activities']! as List<Object?>).first!
              as Map<String, Object?>;
      final surfaces = json['surfaces']! as Map<String, Object?>;
      expect(surfaces.containsKey('islandExpanded'), isTrue);
      expect(surfaces['islandExpanded'], isNull);
      expect(_files(_roundTrip(app)), _files(app));
    });
  });

  test(
    'androidDefaults are written only when they are not the values\' own',
    () {
      final own = rideCard().androidValueDefaults;
      final same = appWith([rideCard(androidDefaults: own)]);
      final json = jsonEncode(liveActivityAppToJson(same));
      expect(json, isNot(contains('androidDefaults')));
      final other = appWith([
        rideCard(androidDefaults: {...own, 'v_driver': 'Someone'}),
      ]);
      expect(
        jsonEncode(liveActivityAppToJson(other)),
        contains('androidDefaults'),
      );
    },
  );

  group('errors', () {
    test('say where JSON is wrong', () {
      expect(
        () => _app(
          (json) =>
              (_surfaces(json)['lockScreen']! as Map<String, Object?>)['root'] =
                  {'type': 'slider', 'key': 'x'},
        ),
        _throwsAt(r'$.activities[0].surfaces.lockScreen.root.type'),
      );
      expect(
        () => _app(
          (json) =>
              (_surfaces(json)['islandMinimal']!
                  as Map<String, Object?>)['root'] = {
                'type': 'text',
                'key': 'x',
                'value': 'courier',
              },
        ),
        _throwsAt(
          r'$.activities[0].surfaces.islandMinimal.root.value',
          'no value "courier" in the card\'s values',
        ),
      );
    });

    test('the spec version is checked', () {
      expect(
        () => _app((json) => json['specVersion'] = 2),
        _throwsAt(r'$.specVersion', 'version 1'),
      );
      expect(
        () => _app((json) => json.remove('specVersion')),
        _throwsAt(r'$.specVersion', 'missing'),
      );
    });

    test('a misspelt field is an error, not left out', () {
      expect(
        () => _app((json) => _activity(json)['surface'] = {}),
        _throwsAt(r'$.activities[0].surface', 'unknown field'),
      );
      expect(
        () => _app((json) => _surfaces(json)['dynamicIsland'] = {}),
        _throwsAt(r'$.activities[0].surfaces.dynamicIsland', 'unknown field'),
      );
    });

    test('a fixed template has no values, layouts or Android settings', () {
      for (final field in ['values', 'surfaces', 'android']) {
        expect(
          () => _app((json) => _activity(json, 1)[field] = <String, Object?>{}),
          _throwsAt('\$.activities[1].$field', 'only a custom card'),
        );
      }
    });

    test('unknown names of templates, types, surfaces and slots', () {
      expect(
        () => _app((json) => _activity(json)['template'] = 'map'),
        _throwsAt(r'$.activities[0].template', 'etaTimer'),
      );
      expect(
        () => _app(
          (json) =>
              ((_activity(json)['values']! as List<Object?>).first!
                      as Map<String, Object?>)['type'] =
                  'text',
        ),
        _throwsAt(r'$.activities[0].values[0].type', 'dateTime'),
      );
      expect(
        () => _app(
          (json) =>
              _activity(json)['android'] = {
                'slots': {'subtitle': 'status'},
              },
        ),
        _throwsAt(r'$.activities[0].android.slots.subtitle', 'largeIcon'),
      );
    });
  });
}
