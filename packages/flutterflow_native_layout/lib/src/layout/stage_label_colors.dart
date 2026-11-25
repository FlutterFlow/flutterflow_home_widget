/// Stage label colours that stay readable on the fill behind them.
library;

import 'dart:math' as math;

import 'package:flutterflow_native_layout/src/layout/layout_model.dart';

/// Makes the stage labels that have no colour of their own readable on the
/// fill they are drawn over.
///
/// Such a label takes the theme's text colour, which follows the phone's
/// mode; the fill of the box it is in need not (a card that is dark in both
/// modes). For each mode, such a label takes the value of its theme colour
/// (light or dark) that stands out from that fill, or the default text
/// colour that does when neither would. A label over no
/// fill of the layout's own (the surface's background shows, which follows
/// the phone) keeps the theme's colour, as does one over a Color value.
///
/// [behind] is what the layout itself is drawn over, when that is known and
/// fixed (the black Dynamic Island). Safe to call again after a fill of
/// [model] changes.
void fitStageLabelColors(NativeLayoutModel model, {LayoutColor? behind}) {
  final root = model.root;
  if (root == null || model.stageBars.isEmpty) {
    return;
  }
  void visit(LayoutNode node, LayoutColor? behind) {
    if (node case LayoutBox(:final background?)) {
      final fill = background.color;
      if (fill == null) {
        // A Color value: not known here.
        behind = null;
      } else if (fill.light >> 24 >= 0x80 && fill.dark >> 24 >= 0x80) {
        behind = fill;
      }
    }
    if (node case LayoutProgress(:final stages?)) {
      if (stages.themedLabelColor case final themed?) {
        stages.labelColor = _readableOn(
          themed,
          behind,
          onLight: 0xFF14181B,
          onDark: 0xFFFFFFFF,
        );
      }
      if (stages.themedUpcomingLabelColor case final themed?) {
        stages.upcomingLabelColor = _readableOn(
          themed,
          behind,
          onLight: 0xFF57636C,
          onDark: 0xFF95A1AC,
        );
      }
    }
    for (final child in node.children) {
      visit(child, behind);
    }
  }

  visit(root, behind);
}

/// [color] as it reads best on [behind]: for each mode, whichever of the
/// colour's own two values (its light and its dark one) stands out more
/// from the fill in that mode, so a theme text colour follows the card and
/// not the phone. When neither stands out enough, [onLight] or [onDark]
/// does, whichever fits the fill.
LayoutColor _readableOn(
  LayoutColor color,
  LayoutColor? behind, {
  required int onLight,
  required int onDark,
}) {
  if (behind == null) {
    return color;
  }
  int best(int a, int b, int fill) =>
      _contrast(a, fill) >= _contrast(b, fill) ? a : b;
  int fit(int fill) {
    final own = best(color.light, color.dark, fill);
    return _contrast(own, fill) >= _kMinLabelContrast
        ? own
        : best(onDark, onLight, fill);
  }

  return LayoutColor(fit(behind.light), fit(behind.dark));
}

/// The least contrast (WCAG ratio, its level for small text) a label keeps
/// its theme colour at.
const _kMinLabelContrast = 4.5;

/// The WCAG contrast ratio of two colours, alpha ignored.
double _contrast(int a, int b) {
  double channel(int c) {
    final v = c / 255;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  double luminance(int argb) =>
      0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
