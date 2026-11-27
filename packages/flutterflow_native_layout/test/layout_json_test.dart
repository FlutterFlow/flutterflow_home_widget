import 'dart:convert';

import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:flutterflow_native_layout/layout_json.dart';
import 'package:test/test.dart';

import 'test_layouts.dart';

const _types = {
  'p_driver': LayoutValueType.string,
  'p_ends': LayoutValueType.dateTime,
  'p_started': LayoutValueType.dateTime,
  'p_done': LayoutValueType.double,
  'p_stage': LayoutValueType.integer,
  'p_label': LayoutValueType.string,
};

/// [model] through JSON text and back.
NativeLayoutModel _roundTrip(
  NativeLayoutModel model, {
  bool card = true,
  LayoutColor? behind,
}) => nativeLayoutFromJson(
  jsonDecode(jsonEncode(nativeLayoutToJson(model))) as Map<String, Object?>,
  types: _types,
  card: card,
  behind: behind,
);

/// Everything both emitters write for [model].
String _drawn(NativeLayoutModel model) {
  final android = remoteViewsLayout(
    'card',
    model,
    rootMode: const LayoutRootMode(fitHeight: true, background: false),
  );
  return [
    swiftLayoutView(
      'Card',
      model,
      rootMode: const LayoutRootMode(fitHeight: true, background: false),
    ),
    android.xml,
    android.binder,
    jsonEncode(android.drawables),
    for (final MapEntry(:key, :value) in android.colors.entries)
      '$key ${value.light} ${value.dark}',
  ].join('\n');
}

Map<String, Object?> _json(String text) =>
    jsonDecode(text) as Map<String, Object?>;

void main() {
  group('round trip', () {
    test('a layout of nearly every node draws the same after JSON', () {
      final model = everyNode(tap: const LayoutOpenPage('/rides', []));
      final back = _roundTrip(model);
      expect(_drawn(back), _drawn(model));
      expect(nativeLayoutToJson(back), nativeLayoutToJson(model));
    });

    test('card forms: count-up text, image value, timed bar, stages', () {
      final bar =
          LayoutProgress(
              'Bar_1',
              circular: false,
              value: const LayoutFraction.fixed(0),
            )
            ..timedStart = 'p_started'
            ..timedEnd = 'p_ends';
      final stages = LayoutProgress(
          'Stages_1',
          circular: false,
          value: const LayoutFraction.fixed(0),
        )
        ..stages =
            (LayoutStages(
                stages: const [
                  LayoutStage('a', LayoutStaticText('A'), null),
                  LayoutStage(
                    'b',
                    LayoutParamText('p_label', LayoutValueType.string),
                    0xe558,
                  ),
                ],
                currentParamKey: 'p_stage',
                upcomingColor: const LayoutColor(0xFFE0E3E7, 0xFF2B3238),
                labelColor: const LayoutColor(0xFF14181B, 0xFFFFFFFF),
                upcomingLabelColor: const LayoutColor(0xFF57636C, 0xFF95A1AC),
              )
              ..themedLabelColor = const LayoutColor(0xFF14181B, 0xFFFFFFFF)
              ..themedUpcomingLabelColor = const LayoutColor(
                0xFF57636C,
                0xFF95A1AC,
              )
              ..progressParamKey = 'p_done'
              ..trackerCodePoint = 0xe558
              ..labelSize = 12);
      final column = LayoutFlex('Column_1', horizontal: false)
        ..items.addAll([
          LayoutTextNode(
            'Since',
            const LayoutParamText(
              'p_started',
              LayoutValueType.dateTime,
              countUp: true,
            ),
          ),
          LayoutImage('Photo', '', paramKey: 'p_photo'),
          bar,
          stages,
        ]);
      final model = NativeLayoutModel(
        column,
        const [],
        stagesSpecs: [
          const LayoutStagesSpec(
            labels: ['A', 'b'],
            labelParamKeys: ['', 'p_label'],
            currentParamKey: 'p_stage',
            progressParamKey: 'p_done',
            trackerCodePoint: 0xe558,
            doneArgb: null,
            upcomingArgb: null,
            hideLabels: false,
          ),
        ],
      );
      final json = nativeLayoutToJson(model);
      final text = jsonEncode(json);
      expect(text, contains('"countUp":true'));
      expect(text, contains('"timed":{"start":"p_started","end":"p_ends"}'));
      expect(text, isNot(contains('"preferredLabelColor"')));
      expect(text, contains('"stagesSpecs"'));
      final back = _roundTrip(model);
      expect(_drawn(back), _drawn(model));
      expect(nativeLayoutToJson(back), json);
      expect(back.stagesSpecs.single.doneArgb, isNull);
      final image = back.nodes.whereType<LayoutImage>().single;
      expect(image.paramKey, 'p_photo');
      expect(image.assetPath, '');
    });

    test('stage specs that are what the bar draws are left out', () {
      final json = _json(
        '''
{"root": {"type": "progress", "key": "s", "value": 0, "color": "#FF2F80ED",
  "stages": {"current": "p_stage", "items": [
    {"key": "a", "label": "A"}, {"key": "b", "label": {"value": "p_label"}}]}}}''',
      );
      final model = nativeLayoutFromJson(json, types: _types, card: true);
      final spec = model.stagesSpecs.single;
      expect(spec.labels, ['A', 'b']);
      expect(spec.labelParamKeys, ['', 'p_label']);
      expect(spec.doneArgb, 0xFF2F80ED);
      // No upcoming color: the bar's track.
      expect(spec.upcomingArgb, 0xFFE0E3E7);
      expect(nativeLayoutToJson(model), isNot(contains('stagesSpecs')));
    });
  });

  group('reading', () {
    test('a label without a color of its own reads on what is behind', () {
      final json = _json('''
{"root": {"type": "progress", "key": "s", "value": 0,
  "stages": {"current": "p_stage", "preferredLabelColor": "#FF333333",
    "items": [{"key": "a", "label": "A"}, {"key": "b", "label": "B"}]}}}''');
      final onLight = nativeLayoutFromJson(json, types: _types, card: true);
      final onBlack = nativeLayoutFromJson(
        json,
        types: _types,
        card: true,
        behind: const LayoutColor.same(0xFF000000),
      );
      LayoutStages stagesOf(NativeLayoutModel model) =>
          model.stageBars.single.stages!;
      expect(stagesOf(onLight).labelColor.light, 0xFF333333);
      // Dark grey on black does not read: the light default takes over.
      expect(stagesOf(onBlack).labelColor.light, 0xFFFFFFFF);
    });

    test('dark colors: every color takes its dark value', () {
      final json = _json('''
{"root": {"type": "text", "key": "t", "text": "Hi",
  "color": {"light": "#FF000000", "dark": "#FFFFFFFF"}}}''');
      final text =
          nativeLayoutFromJson(json, types: _types, darkColors: true).root!
              as LayoutTextNode;
      expect(text.color.color!.light, 0xFFFFFFFF);
      expect(text.color.color!.dark, 0xFFFFFFFF);
    });

    test('a home screen widget layout cannot use what only a card draws', () {
      for (final (node, key) in [
        (
          '{"type": "text", "key": "t", "value": "p_ends", "countUp": true}',
          'countUp',
        ),
        ('{"type": "image", "key": "i", "value": "p_photo"}', 'value'),
        ('{"type": "progress", "key": "p", "value": 0, "timed": {}}', 'timed'),
        (
          '{"type": "progress", "key": "p", "value": 0, "stages": {}}',
          'stages',
        ),
      ]) {
        expect(
          () => nativeLayoutFromJson(_json('{"root": $node}'), types: _types),
          throwsA(
            isA<NativeLayoutJsonException>().having(
              (e) => e.path,
              'path',
              '\$.root.$key',
            ),
          ),
          reason: node,
        );
      }
    });

    test('says where JSON is wrong', () {
      expect(
        () => nativeLayoutFromJson(
          _json(
            '{"root": {"type": "row", "key": "r", "children": ['
            '{"type": "text", "key": "t", "value": "nope"}]}}',
          ),
          types: _types,
          owner: 'card',
          path: r'$.surfaces.lockScreen',
        ),
        throwsA(
          isA<NativeLayoutJsonException>()
              .having(
                (e) => e.path,
                'path',
                r'$.surfaces.lockScreen.root.children[0].value',
              )
              .having(
                (e) => e.message,
                'message',
                'no value "nope" in the card\'s values',
              ),
        ),
      );
    });
  });
}
