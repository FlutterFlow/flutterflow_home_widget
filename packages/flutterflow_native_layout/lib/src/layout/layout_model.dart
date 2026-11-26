/// A native layout (a home screen widget's or a Live Activity card's) as the
/// native code draws it.
///
/// Both emitters (SwiftUI for iOS, RemoteViews for Android) draw from this
/// model, so the two platforms share one reading of every widget and
/// property. It holds only what both platforms draw faithfully: a tool that
/// builds it from a design reports anything else as a [LayoutIssue], so a
/// design never silently differs from what ships.
library;

import 'package:flutterflow_native_layout/src/escape.dart';

/// What a [LayoutIssue] is about, for callers that give each kind its own
/// error code.
enum LayoutIssueKind {
  /// A widget type outside the list.
  widget,

  /// A property set to something the native code cannot draw.
  property,

  /// A binding to something other than one of the values, to a value of the
  /// wrong type, or one that changes the value first.
  binding,

  /// An icon outside Material Icons.
  icon,

  /// A Stages bar with too few or too many stages.
  stagesCount,

  /// A Stages bar whose current stage (or progress in it) is not a value.
  stagesBinding,

  /// A layout that shows more Image values than a card may have.
  imageValueLimit,

  /// An On Tap that is a button (Toggle, Change Number or Clear of a home
  /// screen widget) on a layout that has no buttons: a card's.
  button,
}

/// Something in a layout the native code cannot draw faithfully.
class LayoutIssue {
  const LayoutIssue(
    this.nodeKey,
    this.message, {
    this.kind = LayoutIssueKind.property,
  });

  /// What the issue is about.
  final LayoutIssueKind kind;

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

/// The type of a value a layout shows. Only a date draws differently (it
/// counts down to its time, or up from it); the others show as text.
enum LayoutValueType { string, integer, double, boolean, dateTime, color }

/// The value of a parameter. A date parameter counts down to its time.
class LayoutParamText extends LayoutText {
  const LayoutParamText(this.paramKey, this.type, {this.countUp = false});
  final String paramKey;
  final LayoutValueType type;

  /// A date parameter only: the text shows the time since the date (0:00
  /// before it) instead of the time left until it.
  final bool countUp;

  bool get isCountdown => type == LayoutValueType.dateTime && !countUp;

  /// Whether the text counts up from its date.
  bool get isCountUp => type == LayoutValueType.dateTime && countUp;
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
  Iterable<LayoutNode> get children => [if (child != null) child!];
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
  LayoutImage(super.nodeKey, this.assetPath, {this.paramKey});

  /// The Flutter asset path the app ships the image under
  /// (`assets/images/...`). With [paramKey] it is the fallback, drawn while
  /// the value has no picture, and empty when the value has none.
  final String assetPath;

  /// The Image value the node shows; null for a fixed asset. The host loads
  /// the value's picture and hands it to the view (see the emitters).
  final String? paramKey;
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

  /// Timed progress: the two date parameters the indicator fills between
  /// on its own, with no update from the app. Both set, or both null (the
  /// indicator then shows [value]).
  String? timedStart;
  String? timedEnd;

  bool get isTimed => timedStart != null && timedEnd != null;

  /// Linear only: the bar drawn as a row of stages; null for one bar. The
  /// bar's [value] is then not read.
  LayoutStages? stages;
}

/// One stage of a Stages bar.
class LayoutStage {
  const LayoutStage(this.key, this.label, this.iconCodePoint);

  final String key;

  /// The label: fixed text or a String value.
  final LayoutText label;

  /// The stage's Material Icons code point; null without an icon.
  final int? iconCodePoint;
}

/// The plain values a host reads of one Stages bar, as the design sets them:
/// no checks, no fallbacks beyond those named.
class LayoutStagesSpec {
  const LayoutStagesSpec({
    required this.labels,
    required this.labelParamKeys,
    required this.currentParamKey,
    required this.progressParamKey,
    required this.trackerCodePoint,
    required this.doneArgb,
    required this.upcomingArgb,
    required this.hideLabels,
  });

  /// Each stage's fixed label, or its key when it has none.
  final List<String> labels;

  /// The String value each stage's label is bound to; '' when fixed.
  final List<String> labelParamKeys;

  /// The Integer value that is the current stage; '' when not bound.
  final String currentParamKey;

  /// The Double value inside the stage; '' when not bound.
  final String progressParamKey;

  /// The tracker icon's code point; 0 for none.
  final int trackerCodePoint;

  /// The progress and upcoming colours (theme colours resolved, 0xAARRGGBB);
  /// null when the design sets none.
  final int? doneArgb;
  final int? upcomingArgb;

  final bool hideLabels;
}

/// A linear ProgressBar in Stages mode: a row of stages, those before the
/// current one done, those after it upcoming. Done and current stages take
/// the bar's progress colour.
class LayoutStages {
  LayoutStages({
    required this.stages,
    required this.currentParamKey,
    required this.upcomingColor,
    required this.labelColor,
    required this.upcomingLabelColor,
  });

  /// The size of the disc the tracker icon rides in, and of its glyph.
  static const double trackerSize = 22;
  static const double trackerGlyphSize = 14;

  /// The gap between two stages, and between the bar and the labels.
  static const double gap = 4;

  /// Material Icons `check_circle`: shown on a done stage's label.
  static const int doneCodePoint = 0xe159;

  final List<LayoutStage> stages;

  /// The Integer value that is the current stage: 0 is the first, below 0
  /// none has started, the number of stages or more all are done.
  final String currentParamKey;

  /// The Double value (0 to 1) that places the tracker inside the current
  /// stage; null puts it in the middle.
  String? progressParamKey;

  /// The Material Icons code point of the tracker icon; null for none.
  int? trackerCodePoint;

  /// The colour of the stages that have not started.
  final LayoutColor upcomingColor;

  bool showLabels = true;
  double labelSize = 11;

  /// The colour of done and current labels, and of upcoming ones.
  LayoutColor labelColor;
  LayoutColor upcomingLabelColor;

  /// The theme's colour for each when the design sets none (labels have no
  /// colour of their own for upcoming stages; done and current ones take the
  /// bar's text colour). `fitStageLabelColors` starts from these.
  LayoutColor? themedLabelColor;
  LayoutColor? themedUpcomingLabelColor;

  /// Whether any stage has an icon of its own.
  bool get hasStageIcons => stages.any((s) => s.iconCodePoint != null);

  /// The values the bar reads.
  Iterable<String> get paramKeys => [
    currentParamKey,
    if (progressParamKey != null) progressParamKey!,
    for (final stage in stages)
      if (stage.label case LayoutParamText(:final paramKey)) paramKey,
  ];
}

/// How the top of a layout sits in the surface it is drawn on.
///
/// A home screen widget has a size of its own: the layout fills it, on the
/// widget's background ([widget], the default). A card that is as tall as
/// what is in it (a Live Activity) fits its height instead, and a surface
/// that has its own background draws none behind the layout.
class LayoutRootMode {
  const LayoutRootMode({this.fitHeight = false, this.background = true});

  /// Fills the surface, on the surface's background: a home screen widget.
  static const widget = LayoutRootMode();

  /// Whether the layout is as tall as its content rather than as tall as
  /// the surface. Its height is then unbounded, as a Column's child's is:
  /// nothing in it can fill the height or share out free height.
  final bool fitHeight;

  /// Whether the layout's frame draws the surface's background behind it
  /// and clips to it. Android only (`ff_home_widget_background`): on iOS
  /// the background belongs to what holds the view, not to the view. The
  /// top widget's own fill is drawn either way; to drop it, clear
  /// `background` on the model's root.
  final bool background;
}

/// A layout read from its design: the root node and every issue found.
class NativeLayoutModel {
  NativeLayoutModel(
    this.root,
    this.issues, {
    this.tap,
    this.stagesSpecs = const [],
  });

  final LayoutNode? root;

  /// What a host's spec table reads of each Stages bar the design holds, in
  /// the order met. Unlike [stageBars], also for a bar the layout refused
  /// (the issues say so), so a refused design still has its spec.
  final List<LayoutStagesSpec> stagesSpecs;
  final List<LayoutIssue> issues;

  /// What a tap on the widget does; null opens the app as it is.
  final LayoutTap? tap;

  /// Every tap: the widget's and its nodes'.
  Iterable<LayoutTap> get taps => [
    if (tap != null) tap!,
    for (final node in nodes)
      if (node.tap != null) node.tap!,
  ];

  /// Every tap that opens a page.
  Iterable<LayoutOpenPage> get openPages => taps.whereType<LayoutOpenPage>();

  Iterable<LayoutNode> get nodes => root?.all ?? const [];

  /// The Image values the layout shows, by key, in the order met. The host
  /// loads their pictures and hands them to the layout's view or binder.
  Set<String> get imageParamKeys => {
    for (final node in nodes)
      if (node case LayoutImage(:final paramKey?)) paramKey,
  };

  /// The Stages bars of the layout, in the order met.
  Iterable<LayoutProgress> get stageBars =>
      nodes.whereType<LayoutProgress>().where((bar) => bar.stages != null);

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
      if (node case LayoutProgress(:final timedStart?)) timedStart,
      if (node case LayoutProgress(:final timedEnd?)) timedEnd,
      if (node case LayoutImage(:final paramKey?)) paramKey,
      if (node case LayoutProgress(:final stages?)) ...stages.paramKeys,
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

/// The name [NativeLayoutModel] had when only home screen widgets drew it.
typedef HomeWidgetLayoutModel = NativeLayoutModel;
