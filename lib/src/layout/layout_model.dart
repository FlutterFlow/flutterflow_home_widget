/// A home screen widget layout as the native code draws it.
///
/// Both emitters (SwiftUI for iOS, RemoteViews for Android) draw from this
/// model, so the two platforms share one reading of every widget and
/// property. It holds only what both platforms draw faithfully: a tool that
/// builds it from a design reports anything else as a [LayoutIssue], so a
/// design never silently differs from what ships.
library;

import 'package:flutterflow_home_widget/src/escape.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Something in a layout the native code cannot draw faithfully.
class LayoutIssue {
  const LayoutIssue(this.nodeKey, this.message);

  /// Key of the node the issue is on.
  final String nodeKey;

  /// What is wrong, written for the project errors panel.
  final String message;
}

/// A colour as both platforms need it: its light value and its dark-mode
/// value (the same when the theme has none), as 0xAARRGGBB.
class LayoutColor {
  const LayoutColor(this.light, this.dark);

  const LayoutColor.same(int argb) : light = argb, dark = argb;

  final int light;
  final int dark;

  bool get isClear => light >> 24 == 0 && dark >> 24 == 0;
}

/// A colour that is either fixed or the value of a Color parameter.
class LayoutPaint {
  const LayoutPaint.fixed(LayoutColor this.color) : paramKey = null;
  const LayoutPaint.param(String this.paramKey) : color = null;

  final LayoutColor? color;
  final String? paramKey;
}

class LayoutInsets {
  const LayoutInsets(this.left, this.top, this.right, this.bottom);

  static const zero = LayoutInsets(0, 0, 0, 0);

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool get isZero => left == 0 && top == 0 && right == 0 && bottom == 0;
}

/// A side of a size: unset (fit the content), a fixed number of points, or
/// the whole space the parent gives.
class LayoutLength {
  const LayoutLength.fit() : points = null, fill = false;
  const LayoutLength.points(double this.points) : fill = false;
  const LayoutLength.fill() : points = null, fill = true;

  final double? points;
  final bool fill;

  bool get isFit => points == null && !fill;
}

/// Where a child sits in its box, each axis from -1 (start) to 1 (end).
class LayoutAlignment {
  const LayoutAlignment(this.x, this.y);

  static const topStart = LayoutAlignment(-1, -1);
  static const center = LayoutAlignment(0, 0);

  final double x;
  final double y;
}

enum LayoutMainAxis {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly,
}

enum LayoutCrossAxis { start, center, end, stretch }

enum LayoutTextAlign { start, center, end }

enum LayoutFit { contain, cover, fill }

enum LayoutCase { none, upper, lower }

/// What a text shows.
sealed class LayoutText {
  const LayoutText();
}

/// Text typed into the design.
class LayoutStaticText extends LayoutText {
  const LayoutStaticText(this.text);
  final String text;
}

/// The value of a parameter. A date parameter counts down to its time.
class LayoutParamText extends LayoutText {
  const LayoutParamText(this.paramKey, this.type);
  final String paramKey;
  final HomeWidgetValueType type;

  bool get isCountdown => type == HomeWidgetValueType.dateTime;
}

/// A number from 0 to 1 that is fixed or a parameter.
class LayoutFraction {
  const LayoutFraction.fixed(double this.value) : paramKey = null;
  const LayoutFraction.param(String this.paramKey) : value = null;

  final double? value;
  final String? paramKey;
}

/// How a value goes into a page's route: the format the app's router reads
/// it in (`deserializeParam`).
enum LayoutRouteFormat { text, date, color }

/// One parameter a tap passes to the page it opens: a widget value
/// ([paramKey]) or a fixed string ([constant]), already in route format.
class LayoutRouteParam {
  const LayoutRouteParam.value(this.name, String this.paramKey, this.format)
    : constant = null;
  const LayoutRouteParam.constant(this.name, String this.constant)
    : paramKey = null,
      format = LayoutRouteFormat.text;

  /// The page parameter's name, as the route reads it.
  final String name;
  final String? paramKey;
  final String? constant;
  final LayoutRouteFormat format;
}

/// What a tap on the widget or on one of its elements does (null: open the
/// app).
sealed class LayoutTap {
  const LayoutTap();
}

/// A tap that opens a page of the app at its route [path]. A `:name` segment
/// of [path] is filled with the parameter of that name; the rest go in the
/// query.
class LayoutOpenPage extends LayoutTap {
  const LayoutOpenPage(this.path, this.params);

  final String path;
  final List<LayoutRouteParam> params;
}

/// A button: changes the widget's own values in place and redraws it,
/// without opening the app.
sealed class LayoutButton extends LayoutTap {
  const LayoutButton();
}

/// Flips the Boolean value [paramKey].
class LayoutToggle extends LayoutButton {
  const LayoutToggle(this.paramKey);
  final String paramKey;
}

/// Adds [step] to the number value [paramKey], kept within [min] and [max]
/// (null: no limit). An [integer] value stays a whole number.
class LayoutStep extends LayoutButton {
  const LayoutStep(
    this.paramKey,
    this.step, {
    this.min,
    this.max,
    required this.integer,
  });
  final String paramKey;
  final double step;
  final double? min;
  final double? max;
  final bool integer;
}

/// Clears the widget's values: it shows its placeholder text again.
class LayoutClear extends LayoutButton {
  const LayoutClear();
}

/// One node of a layout. Every node has a stable [id] (its node key, made
/// safe for Swift and Android resource names), its padding, its share of
/// the parent's free space ([flex], null when it does not expand) and the
/// Boolean parameter that shows it ([visibleParam], null when always shown).
sealed class LayoutNode {
  LayoutNode(this.nodeKey);

  final String nodeKey;
  LayoutInsets padding = LayoutInsets.zero;
  int? flex;
  String? visibleParam;

  /// What a tap on this node does; null when a tap falls through to what is
  /// under it (in the end, the whole widget's tap).
  LayoutTap? tap;

  /// Where the node sits in the space its parent gives it (FlutterFlow's
  /// Alignment, an `Align` around the node and its padding). An `Align`
  /// takes all the space it may: the whole box or stack, the cross axis of a
  /// Column or Row.
  LayoutAlignment? align;

  String get id => identifierPart(nodeKey);

  Iterable<LayoutNode> get children => const [];

  /// This node and all its descendants, parents first.
  Iterable<LayoutNode> get all sync* {
    yield this;
    for (final child in children) {
      yield* child.all;
    }
  }
}

class LayoutBox extends LayoutNode {
  LayoutBox(super.nodeKey);

  LayoutLength width = const LayoutLength.fit();
  LayoutLength height = const LayoutLength.fit();
  LayoutPaint? background;
  double radius = 0;
  double borderWidth = 0;
  LayoutColor? borderColor;
  LayoutAlignment? childAlignment;

  /// Whether the box clips its child to its rounded shape (FlutterFlow's
  /// Clip Content). The fill and border are rounded either way.
  bool clip = false;
  LayoutNode? child;

  @override
  Iterable<LayoutNode> get children => [?child];
}

class LayoutFlex extends LayoutNode {
  LayoutFlex(super.nodeKey, {required this.horizontal});

  final bool horizontal;
  LayoutMainAxis mainAxis = LayoutMainAxis.start;
  LayoutCrossAxis crossAxis = LayoutCrossAxis.center;
  double spacing = 0;

  /// Space before the first child and after the last (FlutterFlow's start
  /// and end spacing).
  double startSpacing = 0;
  double endSpacing = 0;

  /// Whether the flex only takes the space its children need along its axis
  /// (Flutter's `MainAxisSize.min`). By default it takes all of it.
  bool shrinkMain = false;
  final List<LayoutNode> items = [];

  @override
  Iterable<LayoutNode> get children => items;
}

class LayoutStack extends LayoutNode {
  LayoutStack(super.nodeKey);

  LayoutAlignment alignment = LayoutAlignment.topStart;
  final List<LayoutNode> items = [];

  @override
  Iterable<LayoutNode> get children => items;
}

class LayoutTextNode extends LayoutNode {
  LayoutTextNode(super.nodeKey, this.content);

  final LayoutText content;
  double fontSize = 14;
  int fontWeight = 400;
  LayoutPaint color = const LayoutPaint.fixed(LayoutColor.same(0xFF14181B));
  LayoutTextAlign textAlign = LayoutTextAlign.start;
  int? maxLines;

  /// With [maxLines], whether cut text ends in "…" (FlutterFlow's Ellipsis
  /// overflow). Otherwise it is cut off, as Flutter's default clip does.
  bool ellipsis = false;
  double letterSpacing = 0;

  /// Flutter's `TextStyle.height`: each line is [fontSize] times this
  /// tall, the extra leading split above and below the glyphs in the
  /// font's ascent-to-descent ratio. Null for the font's own line height.
  double? lineHeight;
  bool italic = false;
  bool underline = false;
  bool strikethrough = false;
  LayoutCase textCase = LayoutCase.none;
}

class LayoutImage extends LayoutNode {
  LayoutImage(super.nodeKey, this.assetPath);

  /// The Flutter asset path the app ships the image under
  /// (`assets/images/...`).
  final String assetPath;
  LayoutLength width = const LayoutLength.fit();
  LayoutLength height = const LayoutLength.fit();
  LayoutFit fit = LayoutFit.contain;
  double radius = 0;
}

class LayoutIcon extends LayoutNode {
  LayoutIcon(super.nodeKey, this.codePoint);

  /// The Material Icons code point the icon draws.
  final int codePoint;
  double size = 24;
  LayoutPaint color = const LayoutPaint.fixed(LayoutColor.same(0xFF14181B));
}

class LayoutSpacer extends LayoutNode {
  LayoutSpacer(super.nodeKey);
}

class LayoutDivider extends LayoutNode {
  LayoutDivider(super.nodeKey);

  /// The height the divider takes, its line centred in it (Flutter's
  /// `Divider.height`, 16 by default).
  double space = 16;
  double thickness = 1;
  LayoutColor color = const LayoutColor(0x1F000000, 0x1FFFFFFF);
  double indent = 0;
  double endIndent = 0;
}

class LayoutProgress extends LayoutNode {
  LayoutProgress(super.nodeKey, {required this.circular, required this.value});

  final bool circular;
  final LayoutFraction value;
  LayoutColor color = const LayoutColor.same(0xFF4B39EF);
  LayoutColor trackColor = const LayoutColor.same(0xFFE0E3E7);

  /// Circular: the diameter (FF's width). Linear: the line height (FF's
  /// height).
  double size = 100;

  /// Circular: the stroke width (FF's height).
  double thickness = 5;

  /// Linear: the width; fills the parent when not fixed, as in FF.
  LayoutLength width = const LayoutLength.fill();

  /// Linear: the corner radius of the bar.
  double barRadius = 0;

  /// Circular: where the arc starts, in degrees clockwise from the top.
  double startAngle = 0;
}

/// A layout read from its widget class: the root node and every issue found.
class HomeWidgetLayoutModel {
  HomeWidgetLayoutModel(this.root, this.issues, {this.tap});

  final LayoutNode? root;
  final List<LayoutIssue> issues;

  /// What a tap on the widget does; null opens the app as it is.
  final LayoutTap? tap;

  /// Every tap: the widget's and its nodes'.
  Iterable<LayoutTap> get taps => [
    ?tap,
    for (final node in nodes)
      if (node.tap != null) node.tap!,
  ];

  /// Every tap that opens a page.
  Iterable<LayoutOpenPage> get openPages => taps.whereType<LayoutOpenPage>();

  Iterable<LayoutNode> get nodes => root?.all ?? const [];

  /// The parameters the layout reads, by key.
  Set<String> get paramKeys => {
    for (final node in nodes) ...[
      if (node.visibleParam != null) node.visibleParam!,
      if (node case LayoutTextNode(content: LayoutParamText(:final paramKey)))
        paramKey,
      if (node case LayoutTextNode(color: LayoutPaint(:final paramKey?)))
        paramKey,
      if (node case LayoutIcon(color: LayoutPaint(:final paramKey?))) paramKey,
      if (node case LayoutBox(background: LayoutPaint(:final paramKey?)))
        paramKey,
      if (node case LayoutProgress(value: LayoutFraction(:final paramKey?)))
        paramKey,
    ],
    for (final tap in taps)
      ...switch (tap) {
        LayoutOpenPage(:final params) => [
          for (final param in params)
            if (param.paramKey != null) param.paramKey!,
        ],
        LayoutToggle(:final paramKey) ||
        LayoutStep(:final paramKey) => [paramKey],
        LayoutClear() => const <String>[],
      },
  };
}
