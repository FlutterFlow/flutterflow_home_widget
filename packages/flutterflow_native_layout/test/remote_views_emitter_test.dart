import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:test/test.dart';

import 'test_layouts.dart';

/// Every name a layout makes: its layout, drawables, colours and view ids.
Set<String> _names(RemoteViewsLayout layout) => {
  layout.layoutName,
  ...layout.drawables.keys,
  ...layout.colors.keys,
  for (final m in RegExp(r'@\+id/(\w+)').allMatches(layout.xml)) m.group(1)!,
  for (final m in RegExp(
    r'(?<!android\.)R\.(?:id|drawable)\.(\w+)',
  ).allMatches(layout.binder))
    m.group(1)!,
};

void main() {
  const open = LayoutOpenPage('/ride', []);

  group('resource prefix', () {
    test('is hw_ unless given', () {
      final plain = remoteViewsLayout('w_small', everyNode(tap: open));
      final given = remoteViewsLayout(
        'w_small',
        everyNode(tap: open),
        resourcePrefix: kRemoteViewsResourcePrefix,
      );
      expect(kRemoteViewsResourcePrefix, 'hw_');
      expect(given.xml, plain.xml);
      expect(given.binder, plain.binder);
      expect(given.drawables, plain.drawables);
      expect(given.colors.keys, plain.colors.keys);
      expect(plain.layoutName, 'hw_layout_w_small');
      expect(_names(plain), everyElement(startsWith('hw_')));
    });

    test('starts every name the layout makes, drawables of each kind '
        'included', () {
      final layout = remoteViewsLayout(
        'w_small',
        everyNode(tap: open),
        resourcePrefix: 'ab_',
      );
      final names = _names(layout);
      expect(names, everyElement(startsWith('ab_')));
      expect(layout.layoutName, 'ab_layout_w_small');
      for (final kind in ['bg', 'ph', 'clip', 'stage']) {
        expect(
          layout.drawables.keys.where((name) => name.startsWith('ab_${kind}_')),
          isNotEmpty,
          reason: kind,
        );
      }
      for (final text in [
        layout.xml,
        layout.binder,
        ...layout.drawables.values,
      ]) {
        expect(text, isNot(contains('hw_')));
      }
      expect(layout.binder, contains('"ab_w_small_widget"'));
    });

    test('names differ only by the prefix', () {
      final hw = remoteViewsLayout(
        'w_small',
        everyNode(),
        resourcePrefix: 'hw_',
      );
      final ab = remoteViewsLayout(
        'w_small',
        everyNode(),
        resourcePrefix: 'ab_',
      );
      expect(ab.xml, hw.xml.replaceAll('hw_', 'ab_'));
      expect(ab.binder, hw.binder.replaceAll('hw_', 'ab_'));
      expect(
        ab.drawables.keys,
        hw.drawables.keys.map((name) => name.replaceFirst('hw_', 'ab_')),
      );
    });
  });

  group('root mode', () {
    final text = NativeLayoutModel(
      LayoutTextNode('Text_1', const LayoutStaticText('Hi')),
      const [],
    );

    test('a widget fills the surface and draws its background', () {
      final xml = remoteViewsLayout('t', text).xml;
      expect(xml, contains('android:layout_height="match_parent"\n'));
      expect(
        xml,
        contains(
          '    android:background="@drawable/ff_home_widget_background"\n'
          '    android:clipToOutline="true">',
        ),
      );
    });

    test('a card wraps its content and has no widget background', () {
      final xml =
          remoteViewsLayout(
            't',
            text,
            rootMode: const LayoutRootMode(fitHeight: true, background: false),
          ).xml;
      expect(xml, contains('android:layout_height="wrap_content">'));
      expect(xml, isNot(contains('ff_home_widget_background')));
    });
  });

  group('timed nodes', () {
    test('a count-up text is a Chronometer the host starts', () {
      final layout = remoteViewsLayout(
        't',
        NativeLayoutModel(
          LayoutTextNode(
            'Text_1',
            const LayoutParamText(
              'p_started',
              LayoutValueType.dateTime,
              countUp: true,
            ),
          ),
          const [],
        ),
      );
      expect(layout.xml, contains('<Chronometer'));
      expect(layout.xml, isNot(contains('android:countDown')));
      expect(
        layout.binder,
        contains(
          'FFLayoutViews.countUp(views, R.id.hw_t_text_1, '
          'v.date("p_started"), v.frozen)',
        ),
      );
    });

    test('a timed bar reads how far now is between the dates', () {
      final bar =
          LayoutProgress(
              'Bar_1',
              circular: false,
              value: const LayoutFraction.fixed(0),
            )
            ..timedStart = 'p_start'
            ..timedEnd = 'p_end';
      const fraction =
          'FFLayoutViews.timedFraction(v.date("p_start"), v.date("p_end"))';
      expect(
        remoteViewsLayout('t', NativeLayoutModel(bar, const [])).binder,
        contains(
          'views.setProgressBar(R.id.hw_t_bar_1, 1000, '
          '(($fraction).coerceIn(0.0, 1.0) * 1000).toInt(), false)',
        ),
      );
    });
  });

  group('binder', () {
    test('a layout that shows an Image value also binds the pictures', () {
      final binder = remoteViewsLayout('t', everyNode()).binder;
      expect(
        binder,
        contains(
          'internal object FFLayout_t : FFLayoutBinder, FFLayoutImageBinder {',
        ),
      );
      expect(binder, contains('"p_photo"'));
    });

    test('one without is a plain binder', () {
      final binder =
          remoteViewsLayout(
            't',
            NativeLayoutModel(
              LayoutTextNode('Text_1', const LayoutStaticText('Hi')),
              const [],
            ),
          ).binder;
      expect(binder, contains('internal object FFLayout_t : FFLayoutBinder {'));
      expect(binder, isNot(contains('FFLayoutImageBinder')));
    });
  });

  test('every FFLayoutViews call the emitter writes has its helper', () {
    // The emitter and the run time are two files; a call to a helper that
    // is not there would only fail in the Android build.
    final layout = remoteViewsLayout('t', everyNode(tap: open));
    final called =
        RegExp(
          r'FFLayoutViews\.(\w+)\(',
        ).allMatches(layout.binder).map((m) => m.group(1)!).toSet();
    expect(called, containsAll(['countdown', 'openPage', 'valueImage']));
    final views = nativeLayoutKotlinViews(cards: true);
    for (final name in called) {
      expect(views, contains('fun $name('), reason: name);
    }
  });

  test('colour resources have a light and a night set', () {
    final layout = remoteViewsLayout('t', everyNode());
    final day = remoteViewsColorResources(layout.colors, night: false);
    final night = remoteViewsColorResources(layout.colors, night: true);
    expect(
      day,
      contains('<color name="hw_t_container_1_bg">#FFFFFFFF</color>'),
    );
    expect(
      night,
      contains('<color name="hw_t_container_1_bg">#FF101213</color>'),
    );
  });
}
