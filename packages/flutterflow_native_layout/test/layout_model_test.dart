import 'dart:io';

import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:test/test.dart';

import 'test_layouts.dart';

void main() {
  test('HomeWidgetLayoutModel is the same class', () {
    final HomeWidgetLayoutModel model = NativeLayoutModel(null, const []);
    expect(model, isA<NativeLayoutModel>());
    expect(HomeWidgetLayoutModel(null, const []).nodes, isEmpty);
  });

  test('an issue is about a property unless it says otherwise', () {
    expect(const LayoutIssue('Text_1', 'x').kind, LayoutIssueKind.property);
    expect(
      const LayoutIssue('Text_1', 'x', kind: LayoutIssueKind.icon).kind,
      LayoutIssueKind.icon,
    );
  });

  test('only a date counts down, or up when it says so', () {
    const countdown = LayoutParamText('p', LayoutValueType.dateTime);
    const countUp = LayoutParamText(
      'p',
      LayoutValueType.dateTime,
      countUp: true,
    );
    expect(countdown.isCountdown, isTrue);
    expect(countdown.isCountUp, isFalse);
    expect(countUp.isCountdown, isFalse);
    expect(countUp.isCountUp, isTrue);
    for (final type in LayoutValueType.values) {
      if (type == LayoutValueType.dateTime) continue;
      expect(LayoutParamText('p', type, countUp: true).isCountUp, isFalse);
      expect(LayoutParamText('p', type).isCountdown, isFalse);
    }
  });

  group('a layout', () {
    final model = everyNode(
      tap: const LayoutOpenPage('/ride/:id', [
        LayoutRouteParam.value('id', 'p_ride', LayoutRouteFormat.text),
      ]),
    );

    test('reads every value its nodes and taps name', () {
      expect(
        model.paramKeys,
        containsAll([
          'p_driver',
          'p_ends',
          'p_photo',
          'p_done',
          'p_stage',
          'p_ride',
        ]),
      );
    });

    test('knows its Image values, Stages bars and taps', () {
      expect(model.imageParamKeys, {'p_photo'});
      expect(model.stageBars.single.nodeKey, 'Stages_1');
      expect(model.openPages.single.path, '/ride/:id');
    });

    test('timed progress needs both dates', () {
      final bar = LayoutProgress(
        'Bar_1',
        circular: false,
        value: const LayoutFraction.fixed(0.5),
      );
      expect(bar.isTimed, isFalse);
      bar.timedStart = 'p_start';
      expect(bar.isTimed, isFalse);
      bar.timedEnd = 'p_end';
      expect(bar.isTimed, isTrue);
      expect(
        NativeLayoutModel(bar, const []).paramKeys,
        containsAll(['p_start', 'p_end']),
      );
    });
  });

  test('stage labels without a colour of their own read on what is '
      'behind them', () {
    LayoutStages stagesOver(LayoutPaint? fill) {
      final bar = everyNode().stageBars.single;
      final stages =
          bar.stages!
            ..themedLabelColor = const LayoutColor(0xFF14181B, 0xFFFFFFFF)
            ..themedUpcomingLabelColor = const LayoutColor(
              0xFF57636C,
              0xFF95A1AC,
            );
      final box =
          LayoutBox('Container_1')
            ..background = fill
            ..child = bar;
      fitStageLabelColors(
        NativeLayoutModel(box, const []),
        behind: const LayoutColor.same(0xFF000000),
      );
      return stages;
    }

    // Over the black island: light in both modes.
    expect(stagesOver(null).labelColor.light, 0xFFFFFFFF);
    expect(stagesOver(null).labelColor.dark, 0xFFFFFFFF);
    // Over a box that is white in both modes: dark in both.
    final onWhite = stagesOver(
      const LayoutPaint.fixed(LayoutColor.same(0xFFFFFFFF)),
    );
    expect(onWhite.labelColor.light, 0xFF14181B);
    expect(onWhite.labelColor.dark, 0xFF14181B);
  });

  test('the library is pure Dart: no Flutter, no I/O, no other package', () {
    final allowed = RegExp(
      r'''^(?:import|export|part)\s+'(dart:(?:core|math|convert|collection)|package:flutterflow_native_layout/|src/)''',
    );
    final directive = RegExp(r'^(?:import|export|part)\s', multiLine: true);
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
    expect(files.length, greaterThanOrEqualTo(9));
    for (final file in files) {
      for (final line in file.readAsLinesSync()) {
        if (!directive.hasMatch(line)) continue;
        // Kotlin and Swift imports inside the generated source text.
        if (!line.contains("'")) continue;
        expect(allowed.hasMatch(line), isTrue, reason: '${file.path}: $line');
      }
    }
  });
}
