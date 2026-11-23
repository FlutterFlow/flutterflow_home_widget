import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_home_widget/flutterflow_home_widget.dart';
import 'package:test/test.dart';

Map<String, Object?> _example() =>
    jsonDecode(File('example/widgets.json').readAsStringSync())
        as Map<String, Object?>;

HomeWidgetApp _app([void Function(Map<String, Object?> json)? edit]) {
  final json = _example();
  edit?.call(json);
  return homeWidgetAppFromJson(json);
}

Map<String, Object?> _widget(Map<String, Object?> json) =>
    (json['widgets']! as List<Object?>).first! as Map<String, Object?>;

Map<String, Object?> _layout(Map<String, Object?> json, String size) =>
    (_widget(json)['layouts']! as Map<String, Object?>)[size]!
        as Map<String, Object?>;

void main() {
  group('JSON', () {
    test('round trips without changing a generated file', () {
      final app = _app();
      final back = homeWidgetAppFromJson(
        jsonDecode(jsonEncode(homeWidgetAppToJson(app)))
            as Map<String, Object?>,
      );
      expect(generateHomeWidgetFiles(back), generateHomeWidgetFiles(app));
      expect(
        jsonEncode(homeWidgetAppToJson(back)),
        jsonEncode(homeWidgetAppToJson(app)),
      );
    });

    test('reads colors, lengths, taps and bound values', () {
      final water = _app().widget('water')!;
      expect(water.layouts.keys, [
        HomeWidgetSize.small,
        HomeWidgetSize.medium,
        HomeWidgetSize.accessoryCircular,
        HomeWidgetSize.accessoryInline,
      ]);
      final medium = water.layouts[HomeWidgetSize.medium]!;
      final add = medium.nodes.whereType<LayoutBox>().firstWhere(
        (n) => n.nodeKey == 'add',
      );
      expect(add.width.points, 44);
      expect(add.tap, isA<LayoutStep>().having((t) => t.max, 'max', 20));
      final glasses = medium.nodes.whereType<LayoutTextNode>().firstWhere(
        (n) => n.nodeKey == 'glasses',
      );
      expect(
        glasses.content,
        isA<LayoutParamText>().having(
          (t) => t.type,
          'type',
          HomeWidgetValueType.integer,
        ),
      );
      expect(glasses.color.paramKey, 'accent');
      final card = medium.root! as LayoutBox;
      expect(card.background!.color!.light, 0xFFFFFFFF);
      expect(card.background!.color!.dark, 0xFF101418);
      expect(_app().iconCodePoints, {0xe145, 0xe798});
    });

    test('says where JSON is wrong', () {
      expect(
        () => _app(
          (json) =>
              _layout(json, 'small')['root'] = {'type': 'slider', 'key': 'x'},
        ),
        throwsA(
          isA<HomeWidgetJsonException>().having(
            (e) => e.path,
            'path',
            r'$.widgets[0].layouts.small.root.type',
          ),
        ),
      );
      expect(
        () => _app((json) => _widget(json)['layouts'] = {'huge': {}}),
        throwsA(isA<HomeWidgetJsonException>()),
      );
      expect(
        () => _app(
          (json) => _layout(json, 'small')['root'] = {
            'type': 'text',
            'key': 't',
            'value': 'nope',
          },
        ),
        throwsA(
          isA<HomeWidgetJsonException>().having(
            (e) => e.message,
            'message',
            contains('no value "nope"'),
          ),
        ),
      );
    });
  });

  group('validation', () {
    test('the example has no problems', () {
      expect(validateHomeWidgetApp(_app()), isEmpty);
    });

    List<String> problems(void Function(Map<String, Object?> json) edit) => [
      for (final problem in validateHomeWidgetApp(_app(edit)))
        problem.toString(),
    ];

    test('a value bound to the wrong type', () {
      expect(
        problems((json) {
          final medium = _layout(json, 'medium');
          final row = (medium['root']! as Map)['child']! as Map;
          final add = (row['children']! as List).last as Map;
          add['tap'] = {'toggle': 'glasses'};
        }),
        [contains('reads "glasses" as boolean, but it is a integer')],
      );
    });

    test('a page opened by an element of the small size', () {
      expect(
        problems((json) {
          final small = _layout(json, 'small');
          final column = (small['root']! as Map)['child']! as Map;
          ((column['children']! as List).first as Map)['tap'] = {
            'openPage': '/water',
          };
        }),
        [contains('opens one page for the whole widget')],
      );
    });

    test('more than one line on the inline Lock Screen', () {
      expect(
        problems(
          (json) => _layout(json, 'accessoryInline')['root'] = {
            'type': 'column',
            'key': 'c',
            'children': [
              {'type': 'text', 'key': 'a', 'text': 'A'},
              {'type': 'text', 'key': 'b', 'text': 'B'},
            ],
          },
        ),
        [contains('shows one line')],
      );
    });

    test('defaults, refresh and choices', () {
      expect(
        problems((json) {
          final widget = _widget(json);
          ((widget['values']! as List).first as Map)['default'] = 'three';
          widget['refresh'] = {
            'url': 'https://example.com/water.json',
            'intervalMinutes': 5,
            'values': [
              {'key': 'status', 'type': 'integer', 'path': r'$.status'},
            ],
          };
          widget['configuration'] = {
            'choices': [
              {
                'id': 'home',
                'name': 'Home',
                'values': {'missing': 'x'},
              },
            ],
          };
        }),
        [
          contains('has a default that is not a integer (three)'),
          contains('fetches every 5 minutes'),
          contains('fetches a integer into a string value'),
          contains('sets "missing", which is not a value'),
        ],
      );
    });
  });

  group('generated files', () {
    final files = generateHomeWidgetFiles(_app());

    test('the plugin, the extension and the Android side', () {
      expect(
        files.keys,
        containsAll([
          'packages/ff_home_widget/pubspec.yaml',
          'packages/ff_home_widget/lib/ff_home_widget.dart',
          'ios/HomeWidget/HomeWidgetBundle.swift',
          'ios/HomeWidget/HomeWidgetLayouts.swift',
          'packages/ff_home_widget/android/src/main/AndroidManifest.xml',
          'packages/ff_home_widget/android/src/main/res/xml/ff_home_widget_info_water.xml',
        ]),
      );
      expect(
        files['ios/HomeWidget/HomeWidgetBundle.swift'],
        contains('struct FFHomeWidget_water: Widget'),
      );
      // Android has no Lock Screen widgets: only the two Home Screen sizes.
      expect(
        files.keys.where((k) => k.contains('/res/layout/hw_layout_water_')),
        hasLength(2),
      );
      expect(
        files['ios/HomeWidget/HomeWidgetLayouts.swift'],
        contains('let kFFRouteScheme = "demo"'),
      );
    });

    test('the plugin keeps the icons only the widgets draw', () {
      expect(
        files['packages/ff_home_widget/lib/ff_home_widget.dart'],
        contains(
          "@pragma('vm:entry-point')\n"
          'const kFFHomeWidgetIcons = <IconData>[\n'
          "  IconData(0xe145, fontFamily: 'MaterialIcons'),\n"
          "  IconData(0xe798, fontFamily: 'MaterialIcons'),\n",
        ),
      );
    });

    test('quotes a device family with a comma', () {
      String family(String value) => homeWidgetPbxprojFragmentsFor(
        bundleId: 'a.b',
        targetDeviceFamily: value,
      )[16];
      expect(family('1,2'), contains('TARGETED_DEVICE_FAMILY = "1,2";'));
      expect(family('"1,2"'), contains('TARGETED_DEVICE_FAMILY = "1,2";'));
      expect(family('1'), contains('TARGETED_DEVICE_FAMILY = 1;'));
    });
  });
}
