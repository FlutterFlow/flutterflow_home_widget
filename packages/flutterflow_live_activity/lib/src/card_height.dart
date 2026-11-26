/// How tall a card design draws, worked out from its layout without drawing
/// it. A design whose height fits its content has no height to read, so the
/// "card too tall" check adds its parts up instead.
library;

import 'dart:math' as math;

import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// The height of a design, in points.
class LiveActivityCardHeight {
  const LiveActivityCardHeight(this.atLeast, this.likely);

  /// What the design takes with every conditionally shown widget hidden and
  /// every text on one line. The card is never shorter than this.
  final double atLeast;

  /// What it takes with every widget shown, fixed texts on the lines their
  /// line breaks give. An estimate: a text that wraps makes the card taller.
  final double likely;
}

/// One line of the system font is this many times its size (San Francisco:
/// 20.29 pt for 17 pt), kept just under so the result stays a lower bound.
const _kSystemLineHeight = 1.19;

/// The height of the design whose top widget is [root]; null without one.
LiveActivityCardHeight? liveActivityCardHeight(LayoutNode? root) {
  if (root == null) {
    return null;
  }
  final (atLeast, likely) = _height(root);
  return LiveActivityCardHeight(atLeast, likely);
}

(double, double) _max(Iterable<LayoutNode> nodes) {
  var atLeast = 0.0;
  var likely = 0.0;
  for (final node in nodes) {
    final (a, l) = _height(node);
    atLeast = math.max(atLeast, a);
    likely = math.max(likely, l);
  }
  return (atLeast, likely);
}

(double, double) _column(LayoutFlex flex) {
  var atLeast = 0.0;
  var likely = 0.0;
  var always = 0;
  for (final item in flex.items) {
    final (a, l) = _height(item);
    atLeast += a;
    likely += l;
    if (item.visibleParam == null) {
      always++;
    }
  }
  final ends = flex.startSpacing + flex.endSpacing;
  return (
    atLeast + ends + flex.spacing * math.max(always - 1, 0),
    likely + ends + flex.spacing * math.max(flex.items.length - 1, 0),
  );
}

(double, double) _content(LayoutNode node) {
  switch (node) {
    case LayoutBox(:final height, :final child):
      final points = height.points;
      if (points != null) {
        return (points, points);
      }
      // A box that fills the height of a card that fits its content has
      // nothing to fill: it is as tall as what is in it.
      return child == null ? (0, 0) : _height(child);
    case LayoutFlex(horizontal: true, :final items):
      return _max(items);
    case LayoutFlex():
      return _column(node);
    case LayoutStack(:final items):
      return _max(items);
    case LayoutTextNode():
      final line = node.fontSize * (node.lineHeight ?? _kSystemLineHeight);
      var lines = 1;
      if (node.content case LayoutStaticText(:final text)) {
        lines = '\n'.allMatches(text).length + 1;
        if (node.maxLines case final max?) {
          lines = math.min(lines, math.max(max, 1));
        }
      }
      return (line, line * lines);
    case LayoutImage(:final width, :final height):
      final points = height.points;
      if (points != null) {
        return (points, points);
      }
      // No fixed height: the picture decides. A square is the guess.
      return (0, width.points ?? 0);
    case LayoutIcon(:final size):
      return (size, size);
    case LayoutSpacer():
      return (0, 0);
    case LayoutDivider(:final space):
      return (space, space);
    case LayoutProgress(:final stages?):
      final bar =
          stages.trackerCodePoint == null
              ? node.size
              : math.max(node.size, LayoutStages.trackerSize);
      final all =
          bar +
          (stages.showLabels
              ? LayoutStages.gap + stages.labelSize * _kSystemLineHeight
              : 0);
      return (all, all);
    case LayoutProgress(:final size):
      return (size, size);
  }
}

(double, double) _height(LayoutNode node) {
  final (atLeast, likely) = _content(node);
  final padding = node.padding.top + node.padding.bottom;
  return (node.visibleParam == null ? atLeast + padding : 0, likely + padding);
}
