import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// A text bound to a date value: a countdown.
LayoutTextNode countdownText({LayoutTextAlign align = LayoutTextAlign.start}) =>
    LayoutTextNode(
      'Text_1',
      const LayoutParamText('p_ends', LayoutValueType.dateTime),
    )..textAlign = align;

/// A filled box around a column that holds one of nearly every node: static,
/// bound and decorated text, a countdown, a fixed and a bound image, an
/// icon, a bar, a ring, a Stages bar, a divider and a spacer.
NativeLayoutModel everyNode({LayoutTap? tap}) {
  final column = LayoutFlex('Column_1', horizontal: false)
    ..items.addAll([
      LayoutTextNode('Text_1', const LayoutStaticText('Ride to the airport')),
      LayoutTextNode(
        'Text_2',
        const LayoutParamText('p_driver', LayoutValueType.string),
      ),
      LayoutTextNode('Text_3', const LayoutStaticText('Struck'))
        ..strikethrough = true,
      LayoutTextNode(
        'Text_4',
        const LayoutParamText('p_ends', LayoutValueType.dateTime),
      ),
      LayoutImage('Image_1', 'assets/images/car.png')..radius = 8,
      LayoutImage('Image_2', 'assets/images/fallback.png', paramKey: 'p_photo'),
      LayoutIcon('Icon_1', 0xe1d7),
      LayoutProgress(
        'Bar_1',
        circular: false,
        value: const LayoutFraction.param('p_done'),
      ),
      LayoutProgress(
        'Ring_1',
        circular: true,
        value: const LayoutFraction.fixed(0.5),
      ),
      LayoutProgress(
          'Stages_1',
          circular: false,
          value: const LayoutFraction.fixed(0),
        )
        ..stages = LayoutStages(
          stages: const [
            LayoutStage('s1', LayoutStaticText('Ordered'), null),
            LayoutStage('s2', LayoutStaticText('On the way'), 0xe558),
            LayoutStage('s3', LayoutStaticText('Here'), null),
          ],
          currentParamKey: 'p_stage',
          upcomingColor: const LayoutColor.same(0xFFE0E3E7),
          labelColor: const LayoutColor.same(0xFF14181B),
          upcomingLabelColor: const LayoutColor.same(0xFF57636C),
        ),
      LayoutDivider('Divider_1'),
      LayoutSpacer('Spacer_1'),
    ]);
  final box =
      LayoutBox('Container_1')
        ..background = const LayoutPaint.fixed(
          LayoutColor(0xFFFFFFFF, 0xFF101213),
        )
        ..radius = 12
        ..child = column;
  return NativeLayoutModel(box, const [], tap: tap);
}

int count(String text, String part) => part.allMatches(text).length;

int balance(String source, String open, String close) =>
    count(source, open) - count(source, close);
