import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:test/test.dart';

import 'test_layouts.dart';

String _swift(
  LayoutNode root, {
  SwiftCountdownStyle countdown = SwiftCountdownStyle.fitted,
  LayoutRootMode rootMode = LayoutRootMode.widget,
}) => swiftLayoutView(
  'V',
  NativeLayoutModel(root, const []),
  countdown: countdown,
  rootMode: rootMode,
);

LayoutProgress _timedBar({bool circular = false}) =>
    LayoutProgress(
        'Bar_1',
        circular: circular,
        value: const LayoutFraction.fixed(0),
      )
      ..timedStart = 'p_start'
      ..timedEnd = 'p_end';

void main() {
  group('countdown', () {
    test('fitted (the default): a centred or end-aligned countdown says '
        'where it sits', () {
      expect(
        _swift(countdownText()),
        contains('FFCountdownText(end: values.date("p_ends")).font('),
      );
      expect(
        _swift(countdownText(align: LayoutTextAlign.center)),
        contains(
          'FFCountdownText(end: values.date("p_ends"), alignment: .center).font(',
        ),
      );
      expect(
        _swift(countdownText(align: LayoutTextAlign.end)),
        contains(
          'FFCountdownText(end: values.date("p_ends"), alignment: .trailing).font(',
        ),
      );
    });

    test('full width: never an alignment, however the text is aligned', () {
      for (final align in LayoutTextAlign.values) {
        expect(
          _swift(
            countdownText(align: align),
            countdown: SwiftCountdownStyle.fullWidth,
          ),
          contains('FFCountdownText(end: values.date("p_ends")).font('),
          reason: '$align',
        );
      }
    });

    test('a start-aligned countdown is the same text in both styles', () {
      expect(
        _swift(countdownText(), countdown: SwiftCountdownStyle.fullWidth),
        _swift(countdownText()),
      );
    });
  });

  group('count-up text', () {
    const countUp = LayoutParamText(
      'p_started',
      LayoutValueType.dateTime,
      countUp: true,
    );

    test('counts up from its date, sized and aligned as a countdown', () {
      expect(
        _swift(LayoutTextNode('Text_1', countUp)),
        contains('FFCountUpText(start: values.date("p_started")).font('),
      );
      expect(
        _swift(
          LayoutTextNode('Text_1', countUp)..textAlign = LayoutTextAlign.end,
        ),
        contains(
          'FFCountUpText(start: values.date("p_started"), alignment: .trailing)',
        ),
      );
    });
  });

  group('timed progress', () {
    test('a bar fills between its two dates, with the bar\'s look', () {
      final bar =
          _timedBar()
            ..size = 8
            ..barRadius = 4;
      expect(
        _swift(bar),
        contains(
          'FFTimedBarProgress(start: values.date("p_start"), '
          'end: values.date("p_end"), '
          'color: FFColor(light: 0xFF4B39EF, dark: 0xFF4B39EF), '
          'track: FFColor(light: 0xFFE0E3E7, dark: 0xFFE0E3E7), '
          'height: 8, cornerRadius: 4).frame(maxWidth: .infinity, alignment: .leading)',
        ),
      );
      expect(_swift(bar), isNot(contains('FFBarProgress(')));
    });

    test('a ring fills between its two dates', () {
      final ring =
          _timedBar(circular: true)
            ..size = 40
            ..thickness = 4;
      expect(
        _swift(ring),
        contains(
          'FFTimedRingProgress(start: values.date("p_start"), '
          'end: values.date("p_end"), ',
        ),
      );
      expect(
        _swift(ring),
        contains('diameter: 40, thickness: 4, startAngle: 0)'),
      );
    });

    test('a bar without dates is drawn as before', () {
      final bar = LayoutProgress(
        'Bar_1',
        circular: false,
        value: const LayoutFraction.param('p_progress'),
      );
      expect(
        _swift(bar),
        contains('FFBarProgress(value: values.double("p_progress")'),
      );
      expect(_swift(bar), isNot(contains('Timed')));
    });
  });

  group('root mode', () {
    test('a widget fills the surface; a layout that fits its height takes '
        'only the height of what is in it', () {
      final text = LayoutTextNode('Text_1', const LayoutStaticText('Hi'));
      expect(
        _swift(text),
        contains(
          '.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)',
        ),
      );
      final fit = _swift(
        LayoutTextNode('Text_1', const LayoutStaticText('Hi')),
        rootMode: const LayoutRootMode(fitHeight: true),
      );
      expect(
        fit,
        contains(
          '.frame(maxWidth: .infinity, alignment: .topLeading)\n'
          '      .fixedSize(horizontal: false, vertical: true)',
        ),
      );
      expect(fit, isNot(contains('maxHeight: .infinity, alignment: .top')));
    });

    test('an empty layout that fits its height has no height', () {
      expect(
        swiftLayoutView(
          'V',
          NativeLayoutModel(null, const []),
          rootMode: const LayoutRootMode(fitHeight: true),
        ),
        contains('Color.clear.frame(height: 0)'),
      );
    });
  });

  group('Image values', () {
    test('a view that shows one takes the loaded pictures', () {
      final model = everyNode();
      final swift = swiftLayoutView('V', model);
      expect(swift, contains('  var images: [String: UIImage] = [:]'));
      expect(
        swift,
        contains(
          'FFValueImage(image: images["p_photo"], '
          'fallback: "assets/images/fallback.png", ',
        ),
      );
      expect(
        swiftLayoutViewInit('V', model),
        'V(values: values, images: images)',
      );
    });

    test('a view without one takes values only', () {
      final model = NativeLayoutModel(
        LayoutImage('Image_1', 'assets/images/car.png'),
        const [],
      );
      expect(swiftLayoutView('V', model), isNot(contains('var images')));
      expect(swiftLayoutView('V', model), isNot(contains('images[')));
      expect(swiftLayoutViewInit('V', model), 'V(values: values)');
    });
  });

  test('a Stages bar is an FFStagesBar reading the current stage', () {
    final swift = swiftLayoutView('V', everyNode());
    expect(
      swift,
      contains(
        'FFStagesBar(stages: [FFStage(label: "Ordered"), '
        'FFStage(label: "On the way", icon: 0xe558), FFStage(label: "Here")], '
        'current: values.double("p_stage"), ',
      ),
    );
  });

  test('the view name is the key and the size', () {
    expect(
      swiftLayoutViewName('my-widget', 'small'),
      'FFLayout_my_widget_small',
    );
  });
}
