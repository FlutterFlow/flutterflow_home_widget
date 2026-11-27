import 'dart:convert';
import 'dart:io';

import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';
import 'package:test/test.dart';

import 'test_specs.dart';

final _example = liveActivityAppFromJson(
  jsonDecode(File('example/live_activities.json').readAsStringSync())
      as Map<String, Object?>,
);

LiveActivityDefinition _withValues(List<String> keys) => rideCard(
  values: [
    for (final key in keys)
      LiveActivityValue(
        key: key,
        name: key,
        type: LiveActivityValueType.string,
      ),
  ],
);

void main() {
  group('names', () {
    test('a class per activity, numbered when two would share one', () {
      expect(
        liveActivityDartClassNames(
          appWith([
            for (final key in [
              'delivery',
              'la_ride',
              'my-ride',
              'myRide',
              '2fa',
            ])
              fixedCard(LiveActivityTemplate.progress, key: key),
          ]),
        ),
        {
          'delivery': 'DeliveryLiveActivity',
          'la_ride': 'LaRideLiveActivity',
          'my-ride': 'MyRideLiveActivity',
          'myRide': 'MyRideLiveActivity2',
          '2fa': 'LiveActivity2fa',
        },
      );
    });

    test('a parameter per value, never a reserved word or a clash', () {
      expect(
        liveActivityDartValueNames(
          _withValues([
            'status_text',
            'ETA',
            'URL path',
            'class',
            'instanceId',
            'dismissal',
            '3rd',
            '--',
            'statusText',
          ]),
        ),
        {
          'status_text': 'statusText',
          'ETA': 'eta',
          'URL path': 'urlPath',
          'class': 'classValue',
          'instanceId': 'instanceIdValue',
          'dismissal': 'dismissalValue',
          '3rd': 'v3rd',
          '--': 'value',
          'statusText': 'statusText2',
        },
      );
    });

    test('a fixed template\'s parameters are its values', () {
      for (final template in LiveActivityTemplate.values) {
        if (template == LiveActivityTemplate.custom) {
          continue;
        }
        expect(liveActivityDartValueNames(fixedCard(template)).keys, [
          for (final value in template.fixedValues) value.key,
        ]);
      }
    });
  });

  group('library', () {
    final library = liveActivityTypedApiLibrary(_example);

    test('is the plugin package\'s second library', () {
      expect(liveActivityTypedApiFiles(_example).keys, [
        'packages/ff_live_activity/lib/live_activities.dart',
      ]);
      expect(
        kLiveActivityTypedApiImport,
        'package:ff_live_activity/live_activities.dart',
      );
      expect(library, contains("import 'ff_live_activity.dart';"));
      expect(
        generateLiveActivityFiles(_example).keys,
        isNot(contains(kLiveActivityTypedApiPath)),
      );
    });

    test('fills in what the spec fixes', () {
      expect(library, contains('abstract final class DeliveryLiveActivity {'));
      expect(library, contains("static const definitionKey = 'delivery';"));
      for (final argument in [
        "template: 'custom'",
        "accentColor: '#FF2F80ED'",
        "icon: 'assets/images/app_icon.png'",
        "androidChannelName: 'Deliveries'",
        "template: 'progress'",
        "accentColor: '#FF34C759'",
        "androidChannelName: 'Uploads'",
      ]) {
        expect(count(library, '    $argument,'), 1, reason: argument);
      }
    });

    test('types each value, and requires what start needs', () {
      for (final declaration in [
        'required DateTime eta,',
        'String? title,',
        'int? stage,',
        'double? within,',
        'DateTime? sent,',
        'Object? courier,',
      ]) {
        expect(library, contains('    $declaration'), reason: declaration);
      }
      // Only start requires it.
      expect(count(library, 'required DateTime eta,'), 1);
      expect(count(library, '    DateTime? eta,'), 2);
      expect(library, contains("'eta': FFLiveActivity.encodeDateTime(eta),"));
      expect(library, contains("'stage': FFLiveActivity.encodeInt(stage),"));
      expect(library, contains("'courier': FFLiveActivity.image(courier),"));
      expect(library, contains('dismissal: dismissal.wireName,'));
      // A Color value brings dart:ui's Color.
      expect(library, contains("import 'dart:ui' show Color;"));
      expect(library, contains("'tint': FFLiveActivity.encodeColor(tint),"));
      expect(
        liveActivityTypedApiLibrary(
          appWith([fixedCard(LiveActivityTemplate.progress)]),
        ),
        isNot(contains('dart:ui')),
      );
    });

    test('starts with the values\' defaults', () {
      expect(
        library,
        contains(
          '    defaults: {\n'
          "      'title': 'Your order',\n"
          "      'status': 'Preparing',\n"
          "      'stage': '0',\n"
          "      'within': '0.0',\n"
          "      'tint': '#FF2F80ED',\n"
          '    },\n',
        ),
      );
    });

    test('a bar timed from a date without a default starts now', () {
      final lock = NativeLayoutModel(
        LayoutProgress(
            'Bar_1',
            circular: false,
            value: const LayoutFraction.fixed(0),
          )
          ..timedStart = 'v_started'
          ..timedEnd = 'v_eta',
        const [],
      );
      final app = appWith([
        rideCard(
          values: [
            ...rideValues,
            const LiveActivityValue(
              key: 'v_started',
              name: 'started',
              type: LiveActivityValueType.dateTime,
            ),
          ],
          surfaces: {
            LiveActivitySurface.lockScreen: lock,
            LiveActivitySurface.islandExpanded: expandedLayout(),
          },
        ),
      ]);
      final text = liveActivityTypedApiLibrary(app);
      expect(
        text,
        contains(
          "'v_started': DateTime.now().millisecondsSinceEpoch.toString(),",
        ),
      );
      expect(text, contains('    Color? vAccent,'));
      expect(
        text,
        contains("'v_accent': FFLiveActivity.encodeColor(vAccent),"),
      );
    });

    test('quotes what the spec says', () {
      final app = appWith([
        LiveActivityDefinition(
          key: r"it's $1",
          name: 'Two\nlines',
          template: LiveActivityTemplate.progress,
          androidChannelName: r'Price \ $',
        ),
      ]);
      final text = liveActivityTypedApiLibrary(app);
      expect(text, contains(r"static const definitionKey = 'it\'s \$1';"));
      expect(text, contains(r"androidChannelName: 'Price \\ \$',"));
      expect(text, contains('/// Two lines\n'));
    });
  });
}
