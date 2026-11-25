import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';
import 'package:test/test.dart';

import 'test_layouts.dart';

/// The `FFCountdownText` declaration in [blocks].
String _countdown(String blocks) {
  final start = blocks.indexOf('struct FFCountdownText: View {');
  final end = blocks.indexOf('/// An image the app bundles');
  expect(start, greaterThan(0));
  expect(end, greaterThan(start));
  return blocks.substring(start, end);
}

void main() {
  group('Swift', () {
    test('every helper the views call is there once, in either countdown '
        'style', () {
      for (final style in SwiftCountdownStyle.values) {
        final blocks = nativeLayoutSwiftBuildingBlocks(
          'Widgets',
          countdown: style,
        );
        final all = [
          kNativeLayoutSwiftPageUrl,
          kNativeLayoutSwiftValues,
          kNativeLayoutSwiftColor,
          kNativeLayoutSwiftNow,
          blocks,
          kNativeLayoutSwiftValueImage,
          kNativeLayoutSwiftStages,
          kNativeLayoutSwiftTimed,
        ].join('\n');
        for (final declaration in [
          'func FFPageURL(_ path: String, _ params: [(String, String?)]) -> URL {',
          'struct FFValues {',
          'func FFColor(light: UInt32, dark: UInt32) -> Color {',
          'var ffNow: Date {',
          'struct FFCountdownText: View {',
          'struct FFAssetImage: View {',
          'struct FFIconText: View {',
          'struct FFRingProgress: View {',
          'func ffLines(size: CGFloat, weight: Font.Weight, height: CGFloat?, clip: Int?)',
          'struct FFBarProgress: View {',
          'struct FFValueImage: View {',
          'struct FFStagesBar: View {',
          'struct FFCountUpText: View {',
          'struct FFTimedBarProgress: View {',
          'struct FFTimedRingProgress: View {',
        ]) {
          expect(count(all, declaration), 1, reason: '$style $declaration');
        }
        expect(balance(all, '{', '}'), 0, reason: '$style');
        expect(balance(all, '(', ')'), 0, reason: '$style');
        // The extension's own name, and no Dart left in the Swift.
        expect(blocks, contains('PlugIns/Widgets.appex'));
        expect(all, isNot(contains(r'$_')));
        expect(all, isNot(contains(r'\$')));
        expect(all, contains(r'{ Double($0) }'));
        expect(all, contains(r'@Environment(\.ffNow)'));
      }
    });

    test('the default countdown is fitted', () {
      expect(
        nativeLayoutSwiftBuildingBlocks('Widgets'),
        nativeLayoutSwiftBuildingBlocks(
          'Widgets',
          countdown: SwiftCountdownStyle.fitted,
        ),
      );
    });

    test('a fitted countdown is as wide as its widest text, not as its '
        'room', () {
      final view = _countdown(nativeLayoutSwiftBuildingBlocks('Widgets'));
      expect(view, contains('var alignment: Alignment = .leading'));
      // The ticking text is an overlay of a hidden text of zeros, so it
      // adds nothing to the width.
      final hidden = view.indexOf('Text(widest(end))\n        .hidden()');
      final overlay = view.indexOf('.overlay(\n          ticking(end)');
      expect(hidden, greaterThan(0));
      expect(overlay, greaterThan(hidden));
      expect(
        view,
        contains('.lineLimit(1)\n            .minimumScaleFactor(0.2)'),
      );
      expect(
        view,
        contains(
          'if #available(iOS 16.0, *) {\n'
          '      return Text(timerInterval: now...end, countsDown: true)\n'
          '    }\n'
          '    return Text(end, style: .timer)',
        ),
      );
      expect(view, contains('Text("0:00")'));
    });

    test('a full-width countdown is the system timer text, with no '
        'alignment', () {
      final view = _countdown(
        nativeLayoutSwiftBuildingBlocks(
          'Widgets',
          countdown: SwiftCountdownStyle.fullWidth,
        ),
      );
      expect(
        view,
        'struct FFCountdownText: View {\n'
        '  let end: Date?\n'
        '  @Environment(\\.ffNow) private var now\n'
        '\n'
        '  var body: some View {\n'
        '    if let end = end, end > now {\n'
        '      Text(end, style: .timer)\n'
        '    } else {\n'
        '      Text("0:00")\n'
        '    }\n'
        '  }\n'
        '}\n'
        '\n',
      );
    });

    test('the two styles differ only in FFCountdownText', () {
      final fitted = nativeLayoutSwiftBuildingBlocks('Widgets');
      final full = nativeLayoutSwiftBuildingBlocks(
        'Widgets',
        countdown: SwiftCountdownStyle.fullWidth,
      );
      String without(String blocks) {
        final start = blocks.indexOf('/// Counts down to [end]');
        final end = blocks.indexOf('/// An image the app bundles');
        return blocks.replaceRange(start, end, '');
      }

      expect(without(full), without(fitted));
    });
  });

  group('Kotlin', () {
    test('the binder, the values and what binders draw with', () {
      final views = nativeLayoutKotlinViews();
      expect(kNativeLayoutKotlinBinder, contains('interface FFLayoutBinder {'));
      expect(kNativeLayoutKotlinValues, contains('internal class FFValues('));
      expect(views, startsWith('/** What the layouts\' binders draw with. */'));
      for (final function in [
        'fun openPage(',
        'fun button(',
        'fun tintBackground(',
        'fun tint(',
        'fun countdown(',
        'fun image(',
        'fun decorated(',
        'fun icon(',
        'fun ring(',
      ]) {
        expect(count(views, function), 1, reason: function);
      }
      for (final source in [
        kNativeLayoutKotlinBinder,
        kNativeLayoutKotlinValues,
        kNativeLayoutKotlinImageBinder,
        views,
        nativeLayoutKotlinViews(taps: false, cards: true),
      ]) {
        expect(balance(source, '{', '}'), 0);
        expect(balance(source, '(', ')'), 0);
      }
      expect(
        kNativeLayoutKotlinImports.trim().split('\n'),
        everyElement(startsWith('import ')),
      );
    });

    test('without taps nothing names the home widget plugin', () {
      final views = nativeLayoutKotlinViews(taps: false);
      expect(views, isNot(contains('FFHomeWidget')));
      expect(views, isNot(contains('fun openPage(')));
      expect(views, isNot(contains('fun button(')));
      expect(views, contains('fun countdown('));
      final withTaps = nativeLayoutKotlinViews();
      expect(withTaps, contains('FFHomeWidgetOpenActivity'));
      expect(withTaps, contains('FFHomeWidgetButtonReceiver'));
      expect(withTaps, startsWith(views.substring(0, 200)));
      expect(withTaps, endsWith(views.substring(views.length - 200)));
    });

    test('what only cards draw is there only when asked', () {
      final cards = nativeLayoutKotlinViews(taps: false, cards: true);
      for (final function in [
        'fun countUp(views: RemoteViews',
        'fun timedFraction(start: Long?, end: Long?)',
        'fun valueImage(',
        'fun stages(',
      ]) {
        expect(count(cards, function), 1, reason: function);
        expect(nativeLayoutKotlinViews(), isNot(contains(function)));
      }
    });
  });
}
