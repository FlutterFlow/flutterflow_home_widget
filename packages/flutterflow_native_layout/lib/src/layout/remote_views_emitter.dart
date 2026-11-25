/// Android RemoteViews for a native layout (a home screen widget's or a
/// Live Activity's).
///
/// Each layout becomes a layout XML file, its colour and shape resources,
/// and a Kotlin binder that sets what depends on the widget's values. Views
/// size themselves from their parents' measure specs where Flutter passes
/// constraints down, so the emitter tracks the constraints Flutter would
/// give each node and picks the sizes that reproduce them:
/// - Each node knows which axes its parent bounds and which it forces (see
///   the SwiftUI emitter); a forced or filled side is `match_parent`.
/// - A `wrap_content` view does not grow for a `match_parent` child the way
///   Flutter grows for a child that fills, so a node that has a filling
///   child is `match_parent` itself on that axis.
/// - Padding is outside a widget, its fill and border included (FlutterFlow
///   wraps the widget in a Padding), so it becomes the view's margins; an
///   Alignment is a FrameLayout around it.
/// - A Column or Row lays out FlutterFlow's children: a fixed gap between
///   visible children, and the free space shared out by weighted views, all
///   hidden with the child they come before.
/// - Text sizes are dp, not sp: like iOS, a widget's text does not follow
///   the font size setting, so both platforms draw the design's sizes.
/// - Colours in XML are resources with a `values-night` twin, so the widget
///   follows the system's dark mode on its own. Icons and progress rings are
///   white bitmaps tinted from those resources for the same reason.
library;

import 'package:flutterflow_native_layout/src/escape.dart';
import 'package:flutterflow_native_layout/src/layout/layout_model.dart';

/// What one layout contributes to the plugin's Android resources and code.
class RemoteViewsLayout {
  RemoteViewsLayout({
    required this.layoutName,
    required this.xml,
    required this.drawables,
    required this.colors,
    required this.binder,
  });

  /// Resource name of the layout (`res/layout/<layoutName>.xml`).
  final String layoutName;
  final String xml;

  /// Shape drawables, by resource name.
  final Map<String, String> drawables;

  /// Colour resources, by resource name.
  final Map<String, LayoutColor> colors;

  /// Kotlin: `internal object <binderName> { ... }`.
  final String binder;
}

/// Black or white, whichever reads better on [argb].
int _onColor(int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return (r * 299 + g * 587 + b * 114) / 1000 >= 150 ? 0xFF000000 : 0xFFFFFFFF;
}

/// Kotlin object name of a layout's binder.
String kotlinBinderName(String tag) => 'FFLayout_$tag';

/// What [remoteViewsLayout] starts the name of every resource, view id and
/// tap key it makes with, unless told otherwise.
const kRemoteViewsResourcePrefix = 'hw_';

/// Builds the Android side of [model]. [tag] makes its resource names unique
/// (lower case letters, digits and `_`). [defaults] (the widget's default
/// values, by parameter key) are written into the XML as the text of bound
/// texts, so the picker's XML preview (Android 12 to 14, or before the app
/// publishes its own) shows them. [resourcePrefix] starts every name the
/// layout makes (lower case letters, digits and `_`, ending in `_`); layouts
/// that share an app's resources need tags or prefixes that cannot meet.
RemoteViewsLayout remoteViewsLayout(
  String tag,
  NativeLayoutModel model, {
  Map<String, String> defaults = const {},
  String widgetKey = '',
  LayoutRootMode rootMode = LayoutRootMode.widget,
  String resourcePrefix = kRemoteViewsResourcePrefix,
}) {
  final emitter = _RemoteViewsEmitter(tag, defaults, widgetKey, resourcePrefix);
  final root = model.root;
  // The whole widget's tap first: a node's own tap on top of it wins.
  if (model.tap case final tap?) {
    emitter._bind.add(
      tapCall(
        'android.R.id.background',
        '$resourcePrefix${tag}_widget',
        widgetKey,
        tap,
      ),
    );
  }
  final fit = rootMode.fitHeight;
  final body =
      root == null
          ? ''
          : emitter.node(root, fit ? _Space.fitHeightRoot : _Space.root, 1);
  final layoutName = '${resourcePrefix}layout_$tag';
  // A layout that fits its height is as tall as what is in it; a surface
  // with its own background gets no widget background behind the layout.
  final background =
      rootMode.background
          ? '''

    android:background="@drawable/ff_home_widget_background"
    android:clipToOutline="true"'''
          : '';
  final xml = '''
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@android:id/background"
    android:layout_width="match_parent"
    android:layout_height="${fit ? 'wrap_content' : 'match_parent'}"$background>
$body
</FrameLayout>
''';
  return RemoteViewsLayout(
    layoutName: layoutName,
    xml: xml,
    drawables: emitter.drawables,
    colors: emitter.colors,
    binder: emitter.binder(kotlinBinderName(tag), layoutName),
  );
}

String _kotlinOptional(double? value) => value == null ? 'null' : '$value';

/// The Kotlin arguments of [button] after the widget key: kind, value, step,
/// min, max and whether the value is a whole number.
String _buttonArgs(LayoutButton button) => switch (button) {
  LayoutToggle(:final paramKey) =>
    '"toggle", ${kotlinString(paramKey)}, 0.0, null, null, false',
  LayoutStep(
    :final paramKey,
    :final step,
    :final min,
    :final max,
    :final integer,
  ) =>
    '"step", ${kotlinString(paramKey)}, $step, ${_kotlinOptional(min)}, '
        '${_kotlinOptional(max)}, $integer',
  LayoutClear() => '"clear", "", 0.0, null, null, false',
};

/// The Kotlin statement that makes a tap on view [viewId] do [tap]. [key]
/// tells this tap's intent apart from every other; [widgetKey] is the widget
/// a button changes.
String tapCall(String viewId, String key, String widgetKey, LayoutTap tap) =>
    switch (tap) {
      LayoutOpenPage page => openPageCall(viewId, key, page),
      LayoutButton button =>
        'FFLayoutViews.button(ctx, views, $viewId, ${kotlinString(key)}, '
            '${kotlinString(widgetKey)}, ${_buttonArgs(button)}, v.choice)',
    };

/// The Kotlin statement that makes a tap on view [viewId] open [page] with
/// the widget's values.
String openPageCall(String viewId, String key, LayoutOpenPage page) {
  final params = [
    for (final param in page.params)
      '${kotlinString(param.name)} to ${_routeValue(param)}',
  ];
  return 'FFLayoutViews.openPage(ctx, views, $viewId, ${kotlinString(key)}, '
      '${kotlinString(page.path)}, listOf(${params.join(', ')}), v.choice)';
}

String _routeValue(LayoutRouteParam param) {
  if (param.constant != null) {
    return kotlinString(param.constant!);
  }
  final key = kotlinString(param.paramKey!);
  return switch (param.format) {
    LayoutRouteFormat.text => 'v.routeText($key)',
    LayoutRouteFormat.date => 'v.routeDate($key)',
    LayoutRouteFormat.color => 'v.routeColor($key)',
  };
}

/// The constraints a parent gives a child (see the SwiftUI emitter), and
/// where the child sits: a Column or Row (weights), or a frame.
class _Space {
  const _Space({
    required this.boundedWidth,
    required this.boundedHeight,
    this.forceWidth = false,
    this.forceHeight = false,
    this.flexParent,
  });

  static const root = _Space(boundedWidth: true, boundedHeight: true);

  /// The root of a layout that fits its height ([LayoutRootMode.fitHeight]).
  static const fitHeightRoot = _Space(boundedWidth: true, boundedHeight: false);

  final bool boundedWidth;
  final bool boundedHeight;
  final bool forceWidth;
  final bool forceHeight;

  /// Null in a frame; true in a Row, false in a Column.
  final bool? flexParent;

  bool bounded(bool horizontal) => horizontal ? boundedWidth : boundedHeight;
  bool forced(bool horizontal) => horizontal ? forceWidth : forceHeight;
}

/// A Kotlin Boolean expression; `true` when it always holds.
typedef _Condition = String;

_Condition _and(_Condition a, _Condition b) =>
    a == 'false' || b == 'false'
        ? 'false'
        : a == 'true'
        ? b
        : (b == 'true' ? a : '($a && $b)');

_Condition _not(_Condition a) =>
    a == 'true' ? 'false' : (a == 'false' ? 'true' : '!$a');

_Condition _or(Iterable<_Condition> conditions) {
  final list = conditions.where((c) => c != 'false').toList();
  if (list.isEmpty) return 'false';
  if (list.contains('true')) return 'true';
  return list.length == 1 ? list.single : '(${list.join(' || ')})';
}

String _num(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

String _dp(double value) => '${_num(value)}dp';

/// An XML attribute value: `&`, `<`, `>` and `"` escaped, and the
/// characters Android string parsing treats specially.
String _xmlAttr(String value) => escapeEach(value, kAndroidXmlAttributeEscapes);

/// A Kotlin string literal of [value].
String kotlinString(String value) {
  return '"${escapeEach(value, kKotlinStringEscapes)}"';
}

class _RemoteViewsEmitter {
  _RemoteViewsEmitter(this.tag, this.defaults, this.widgetKey, this.prefix);

  final String tag;

  /// What every name this layout makes starts with.
  final String prefix;

  /// The widget's key, which its buttons change.
  final String widgetKey;
  final Map<String, String> defaults;
  final drawables = <String, String>{};
  final colors = <String, LayoutColor>{};
  final _bind = <String>[];

  /// What draws the Image values' pictures (`bindImages`), and their keys.
  final _bindImages = <String>[];
  final _imageKeys = <String>{};
  var _extra = 0;

  String id(LayoutNode node) => '$prefix${tag}_${node.id.toLowerCase()}';

  /// [node]'s view id without the prefix, for the names of its resources.
  String _name(LayoutNode node) => id(node).substring(prefix.length);

  String color(LayoutNode node, String role, LayoutColor value) {
    final name = '${id(node)}_$role';
    colors[name] = value;
    return '@color/$name';
  }

  String _pad(int depth) => '    ' * depth;

  _Condition _visible(LayoutNode node) =>
      node.visibleParam == null
          ? 'true'
          : 'v.bool(${kotlinString(node.visibleParam!)})';

  void _visibility(String viewId, _Condition condition) {
    if (condition == 'true') return;
    _bind.add(
      'views.setViewVisibility(R.id.$viewId, '
      'if ($condition) View.VISIBLE else View.GONE)',
    );
  }

  String _gravity(LayoutAlignment a) {
    final h =
        a.x < -0.33 ? 'start' : (a.x > 0.33 ? 'end' : 'center_horizontal');
    final v = a.y < -0.33 ? 'top' : (a.y > 0.33 ? 'bottom' : 'center_vertical');
    return '$h|$v';
  }

  String _margins(LayoutInsets p, String indent) =>
      p.isZero
          ? ''
          : '\n${indent}android:layout_marginStart="${_dp(p.left)}"'
              '\n${indent}android:layout_marginTop="${_dp(p.top)}"'
              '\n${indent}android:layout_marginEnd="${_dp(p.right)}"'
              '\n${indent}android:layout_marginBottom="${_dp(p.bottom)}"';

  /// Roboto's line height and ascent, per unit of font size (hhea: ascender
  /// 1900, descender -500, 2048 units per em).
  static const _robotoLine = 2400 / 2048;
  static const _robotoAscentShare = 1900 / 2400;

  /// The extra leading of a text with a line height: each line is size ×
  /// height tall where Roboto's own line is [_robotoLine] × size.
  double _leading(LayoutTextNode text) =>
      text.lineHeight == null
          ? 0
          : text.fontSize * (text.lineHeight! - _robotoLine);

  /// A node's margins: its padding, and for a text with a line height the
  /// extra leading above its first line and below its last, split as
  /// Flutter's proportional leading does.
  LayoutInsets _withLeading(LayoutNode node) {
    final p = node.padding;
    if (node is! LayoutTextNode || node.lineHeight == null) return p;
    final extra = _leading(node);
    return LayoutInsets(
      p.left,
      p.top + extra * _robotoAscentShare,
      p.right,
      p.bottom + extra * (1 - _robotoAscentShare),
    );
  }

  // --- Sizes ---------------------------------------------------------------

  /// The room [box] gives its child.
  _Space _boxChildSpace(LayoutBox box, _Space space) {
    final width = space.forceWidth ? const LayoutLength.fill() : box.width;
    final height = space.forceHeight ? const LayoutLength.fill() : box.height;
    final aligned = box.childAlignment != null;
    return _Space(
      boundedWidth: !width.isFit || space.boundedWidth,
      boundedHeight: !height.isFit || space.boundedHeight,
      forceWidth: !aligned && !width.isFit,
      forceHeight: !aligned && !height.isFit,
    );
  }

  /// The room a Column or Row gives [child].
  _Space _flexChildSpace(LayoutFlex flex, LayoutNode child, _Space at) {
    final h = flex.horizontal;
    final expands = child.flex != null;
    final stretch = flex.crossAxis == LayoutCrossAxis.stretch;
    final crossBounded = at.bounded(!h);
    return _Space(
      boundedWidth: h ? expands : crossBounded,
      boundedHeight: h ? crossBounded : expands,
      forceWidth: h ? expands : stretch && crossBounded,
      forceHeight: h ? stretch && crossBounded : expands,
      flexParent: h,
    );
  }

  /// Whether [node] in [space] takes all the room on an axis, as Flutter
  /// lays it out.
  bool _fills(
    LayoutNode node,
    _Space space, {
    required bool horizontal,
    bool insideAlign = false,
  }) {
    if (space.forced(horizontal)) return true;
    final bounded = space.bounded(horizontal);
    // The Align around a node fills; the node in it has its own size.
    if (node.align != null && !insideAlign) return bounded;
    switch (node) {
      case LayoutBox():
        final own = horizontal ? node.width : node.height;
        if (own.fill) return bounded;
        if (own.points != null) return false;
        final child = node.child;
        if (child == null || node.childAlignment != null) return bounded;
        return _fills(
          child,
          _boxChildSpace(node, space),
          horizontal: horizontal,
        );
      case LayoutFlex():
        if (node.horizontal == horizontal) {
          return !node.shrinkMain && bounded;
        }
        if (node.crossAxis == LayoutCrossAxis.stretch && bounded) return true;
        return node.items.any(
          (c) => _fills(
            c,
            _flexChildSpace(node, c, space),
            horizontal: horizontal,
          ),
        );
      case LayoutStack():
        final childSpace = _Space(
          boundedWidth: space.boundedWidth,
          boundedHeight: space.boundedHeight,
        );
        return node.items.any(
          (c) => _fills(c, childSpace, horizontal: horizontal),
        );
      case LayoutImage():
        return (horizontal ? node.width : node.height).fill && bounded;
      case LayoutDivider():
        return horizontal && bounded;
      case LayoutProgress(:final circular, :final width):
        return !circular && horizontal && width.fill && bounded;
      default:
        return false;
    }
  }

  /// The layout_width or layout_height of [node] in [space].
  String _size(
    LayoutNode node,
    _Space space, {
    required bool horizontal,
    bool insideAlign = false,
  }) {
    if (_fills(node, space, horizontal: horizontal, insideAlign: insideAlign)) {
      return 'match_parent';
    }
    final fixed = switch (node) {
      // A Stages bar is as tall as its bar, tracker and labels.
      LayoutProgress(stages: != null, :final width) =>
        horizontal ? width.points : null,
      LayoutBox(:final width, :final height) =>
        (horizontal ? width : height).points,
      LayoutImage(:final width, :final height) =>
        (horizontal ? width : height).points,
      LayoutIcon(:final size) => size,
      LayoutDivider(:final space) => horizontal ? null : space,
      LayoutProgress(:final circular, :final size, :final width) =>
        circular ? size : (horizontal ? width.points : size),
      _ => null,
    };
    if (fixed != null) return _dp(fixed);
    // An empty box takes nothing on an axis with no bound.
    if (node is LayoutBox && node.child == null) return '0dp';
    return 'wrap_content';
  }

  // --- Nodes ---------------------------------------------------------------

  /// The XML of [node] in [space]. [visibility] false leaves showing and
  /// hiding to the Column or Row it is in, which hides the node with the
  /// gap before it.
  String node(
    LayoutNode node,
    _Space space,
    int depth, {
    bool visibility = true,
  }) {
    final align = node.align;
    if (align == null) {
      if (visibility) _visibility(id(node), _visible(node));
      return _body(node, space, depth);
    }
    // An Align: a frame taking the room the parent bounds (and its share
    // when it expands), the node in it at the alignment.
    final indent = _pad(depth);
    final attr = '$indent    ';
    final wrapperId = '${id(node)}_align';
    final flexParent = space.flexParent;
    final expands = node.flex != null && flexParent != null;
    String side(bool horizontal) =>
        expands && flexParent == horizontal
            ? '0dp'
            : space.bounded(horizontal) || space.forced(horizontal)
            ? 'match_parent'
            : 'wrap_content';
    if (visibility) _visibility(wrapperId, _visible(node));
    final inner = _body(
      node,
      const _Space(boundedWidth: true, boundedHeight: true),
      depth + 1,
      gravity: _gravity(align),
      insideAlign: true,
    );
    return '$indent<FrameLayout'
        '\n${attr}android:id="@+id/$wrapperId"'
        '\n${attr}android:layout_width="${side(true)}"'
        '\n${attr}android:layout_height="${side(false)}"'
        '${expands ? '\n${attr}android:layout_weight="1"' : ''}>\n'
        '$inner\n$indent</FrameLayout>';
  }

  /// The view of [node] itself, its size, weight, gravity and margins set.
  String _body(
    LayoutNode node,
    _Space space,
    int depth, {
    String? gravity,
    bool insideAlign = false,
  }) {
    // Here, not in [node]: every view passes through once, also the ones a
    // Stack or a Container places by gravity.
    if (node.tap case final tap?) {
      _bind.add(tapCall('R.id.${id(node)}', id(node), widgetKey, tap));
    }
    final indent = _pad(depth);
    final attr = '$indent    ';
    final flexParent = space.flexParent;
    final expands = node.flex != null && flexParent != null;
    var width = _size(node, space, horizontal: true, insideAlign: insideAlign);
    var height = _size(
      node,
      space,
      horizontal: false,
      insideAlign: insideAlign,
    );
    if (expands && !insideAlign) {
      if (flexParent) {
        width = '0dp';
      } else {
        height = '0dp';
      }
    }
    final common =
        '\n${attr}android:id="@+id/${id(node)}"'
        '\n${attr}android:layout_width="$width"'
        '\n${attr}android:layout_height="$height"'
        '${expands ? '\n${attr}android:layout_weight="1"' : ''}'
        '${gravity == null ? '' : '\n${attr}android:layout_gravity="$gravity"'}'
        '${_margins(_withLeading(node), attr)}';
    return switch (node) {
      LayoutBox() => _box(node, space, common, attr, depth),
      LayoutFlex() => _flex(node, space, common, attr, depth),
      LayoutStack() => _stack(node, space, common, depth),
      LayoutTextNode() => _text(node, common, attr, indent),
      LayoutImage() => _image(node, space, common, attr, indent),
      LayoutIcon() => _icon(node, common, attr, indent),
      LayoutSpacer() => '$indent<FrameLayout$common />',
      LayoutDivider() => _divider(node, common, attr, depth),
      LayoutProgress() => _progress(node, common, attr, depth),
    };
  }

  String _box(
    LayoutBox box,
    _Space space,
    String common,
    String attr,
    int depth,
  ) {
    final indent = _pad(depth);
    final buffer = StringBuffer('$indent<FrameLayout$common');
    if (box.background != null || box.borderWidth > 0) {
      final drawable = '${prefix}bg_${_name(box)}';
      final fill = box.background?.color;
      final solid =
          fill != null
              ? color(box, 'bg', fill)
              : box.background?.paramKey != null
              ? '#FFFFFFFF'
              : '#00000000';
      final stroke =
          box.borderWidth > 0 && box.borderColor != null
              ? '\n    <stroke android:width="${_dp(box.borderWidth)}" '
                  'android:color="${color(box, 'border', box.borderColor!)}" />'
              : '';
      drawables[drawable] = '''
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="$solid" />
    <corners android:radius="${_dp(box.radius)}" />$stroke
</shape>
''';
      buffer.write('\n${attr}android:background="@drawable/$drawable"');
      if (box.background?.paramKey case final key?) {
        _bind.add(
          'FFLayoutViews.tintBackground(views, R.id.${id(box)}, '
          'v.color(${kotlinString(key)}))',
        );
      }
    }
    if (box.clip) {
      buffer.write('\n${attr}android:clipToOutline="true"');
    }
    // A border insets the child by its width, as BoxDecoration does.
    if (box.borderWidth > 0) {
      buffer.write('\n${attr}android:padding="${_dp(box.borderWidth)}"');
    }
    final child = box.child;
    if (child == null) {
      buffer.write(' />');
      return buffer.toString();
    }
    buffer.write('>\n');
    final childSpace = _boxChildSpace(box, space);
    final aligned = box.childAlignment;
    buffer.write(
      aligned == null
          ? node(child, childSpace, depth + 1)
          : _withGravity(child, childSpace, depth + 1, _gravity(aligned)),
    );
    buffer.write('\n$indent</FrameLayout>');
    return buffer.toString();
  }

  /// [child] placed at [gravity] in a frame (a Container's alignment).
  String _withGravity(
    LayoutNode child,
    _Space space,
    int depth,
    String gravity,
  ) {
    if (child.align != null) return node(child, space, depth);
    _visibility(id(child), _visible(child));
    return _body(child, space, depth, gravity: gravity);
  }

  String _gap(String viewId, double size, bool horizontal, String indent) {
    final width = horizontal ? _dp(size) : '0dp';
    final height = horizontal ? '0dp' : _dp(size);
    return '$indent<FrameLayout android:id="@+id/$viewId" '
        'android:layout_width="$width" android:layout_height="$height" />';
  }

  String _share(String viewId, int weight, String indent) =>
      '$indent<FrameLayout android:id="@+id/$viewId" '
      'android:layout_width="0dp" android:layout_height="0dp" '
      'android:layout_weight="$weight" />';

  String _flex(
    LayoutFlex flex,
    _Space space,
    String common,
    String attr,
    int depth,
  ) {
    final indent = _pad(depth);
    final inner = _pad(depth + 1);
    final h = flex.horizontal;
    final cross = switch (flex.crossAxis) {
      LayoutCrossAxis.start || LayoutCrossAxis.stretch => h ? 'top' : 'start',
      LayoutCrossAxis.end => h ? 'bottom' : 'end',
      LayoutCrossAxis.center => h ? 'center_vertical' : 'center_horizontal',
    };
    final children = flex.items;
    final expands = children.any((c) => c.flex != null);
    final free = !flex.shrinkMain && !expands && space.bounded(h);
    final mode = free ? flex.mainAxis : LayoutMainAxis.start;
    final main = switch (mode) {
      LayoutMainAxis.center => h ? 'center_horizontal' : 'center_vertical',
      LayoutMainAxis.end => h ? 'end' : 'bottom',
      _ => h ? 'start' : 'top',
    };
    final buffer = StringBuffer(
      '$indent<LinearLayout$common'
      '\n${attr}android:orientation="${h ? 'horizontal' : 'vertical'}"'
      '\n${attr}android:gravity="$main|$cross">\n',
    );
    final between = switch (mode) {
      LayoutMainAxis.spaceBetween || LayoutMainAxis.spaceEvenly => 1,
      LayoutMainAxis.spaceAround => 2,
      _ => 0,
    };
    final edge = switch (mode) {
      LayoutMainAxis.spaceAround || LayoutMainAxis.spaceEvenly => 1,
      _ => 0,
    };
    String extraId() => '${id(flex)}_s${_extra++}';
    final lines = <String>[];
    void share(_Condition condition) {
      if (between == 0 || condition == 'false') return;
      final viewId = extraId();
      _visibility(viewId, condition);
      lines.add(_share(viewId, between, inner));
    }

    void gap(double size, _Condition condition) {
      if (size <= 0 || condition == 'false') return;
      final viewId = extraId();
      _visibility(viewId, condition);
      lines.add(_gap(viewId, size, h, inner));
    }

    if (edge > 0) lines.add(_share(extraId(), edge, inner));
    final hasStart = flex.startSpacing > 0;
    if (hasStart) lines.add(_gap(extraId(), flex.startSpacing, h, inner));
    final shown = <_Condition>[];
    for (final child in children) {
      final visible = _visible(child);
      final anyBefore = _or(shown);
      // Before the child when it shows: after an earlier visible child, a
      // gap with a share of the free space either side; else, after the
      // start gap, one share.
      final afterChild = _and(visible, anyBefore);
      share(afterChild);
      gap(flex.spacing, afterChild);
      if (flex.spacing > 0) share(afterChild);
      if (hasStart) share(_and(visible, _not(anyBefore)));
      _visibility(id(child), visible);
      if (child.align != null) {
        _visibility('${id(child)}_align', visible);
      }
      lines.add(
        node(
          child,
          _flexChildSpace(flex, child, space),
          depth + 1,
          visibility: false,
        ),
      );
      shown.add(visible);
    }
    if (flex.endSpacing > 0) {
      share(_or(shown));
      lines.add(_gap(extraId(), flex.endSpacing, h, inner));
    }
    if (edge > 0) lines.add(_share(extraId(), edge, inner));
    buffer
      ..write(lines.join('\n'))
      ..write('\n$indent</LinearLayout>');
    return buffer.toString();
  }

  String _stack(LayoutStack stack, _Space space, String common, int depth) {
    final indent = _pad(depth);
    final gravity = _gravity(stack.alignment);
    final childSpace = _Space(
      boundedWidth: space.boundedWidth,
      boundedHeight: space.boundedHeight,
    );
    return '$indent<FrameLayout$common>\n'
        '${[for (final child in stack.items) _withGravity(child, childSpace, depth + 1, gravity)].join('\n')}'
        '\n$indent</FrameLayout>';
  }

  String _cased(String value, LayoutCase textCase) => switch (textCase) {
    LayoutCase.upper => value.toUpperCase(),
    LayoutCase.lower => value.toLowerCase(),
    LayoutCase.none => value,
  };

  String _textAttrs(LayoutTextNode text, String attr) {
    final buffer = StringBuffer(
      '\n${attr}android:textSize="${_num(text.fontSize)}dp"'
      '\n${attr}android:textFontWeight="${text.fontWeight}"'
      '\n${attr}android:includeFontPadding="false"',
    );
    final styles = [
      if (text.fontWeight >= 600) 'bold',
      if (text.italic) 'italic',
    ];
    if (styles.isNotEmpty) {
      buffer.write('\n${attr}android:textStyle="${styles.join('|')}"');
    }
    final leading = _leading(text);
    if (leading > 0) {
      // Between lines; above the first and below the last are margins.
      buffer.write('\n${attr}android:lineSpacingExtra="${_dp(leading)}"');
    }
    if (text.letterSpacing != 0) {
      // Android's letter spacing is in ems.
      final em = text.letterSpacing / text.fontSize;
      buffer.write('\n${attr}android:letterSpacing="${em.toStringAsFixed(4)}"');
    }
    if (text.color.color case final fixed?) {
      buffer.write(
        '\n${attr}android:textColor="${color(text, 'text', fixed)}"',
      );
    } else {
      _bind.add(
        'views.setTextColor(R.id.${id(text)}, '
        'v.color(${kotlinString(text.color.paramKey!)}))',
      );
    }
    final gravity = switch (text.textAlign) {
      LayoutTextAlign.center => 'center_horizontal',
      LayoutTextAlign.end => 'end',
      LayoutTextAlign.start => 'start',
    };
    buffer.write('\n${attr}android:gravity="$gravity"');
    if (text.maxLines != null) {
      // Flutter cuts a text at its last line; "…" only with Ellipsis.
      buffer.write('\n${attr}android:maxLines="${text.maxLines}"');
      if (text.ellipsis) {
        buffer.write('\n${attr}android:ellipsize="end"');
      }
    }
    return buffer.toString();
  }

  String _text(LayoutTextNode text, String common, String attr, String indent) {
    final decorated = text.underline || text.strikethrough;
    String styled(String kotlinText) =>
        decorated
            ? 'FFLayoutViews.decorated($kotlinText, '
                'underline = ${text.underline}, strike = ${text.strikethrough})'
            : kotlinText;
    switch (text.content) {
      case LayoutStaticText(text: final value):
        final shown = _cased(value, text.textCase);
        if (decorated) {
          _bind.add(
            'views.setTextViewText(R.id.${id(text)}, '
            '${styled(kotlinString(shown))})',
          );
          return '$indent<TextView$common${_textAttrs(text, attr)} />';
        }
        return '$indent<TextView$common${_textAttrs(text, attr)}'
            '\n${attr}android:text="${_xmlAttr(shown)}" />';
      case LayoutParamText(:final paramKey, isCountdown: true):
        _bind.add(
          'FFLayoutViews.countdown(views, R.id.${id(text)}, '
          'v.date(${kotlinString(paramKey)}), v.frozen)',
        );
        return '$indent<Chronometer$common${_textAttrs(text, attr)}'
            '\n${attr}android:countDown="true" />';
      // Counts up from the date on its own (cards only; the reader gives no
      // count-up text to a home screen widget).
      case LayoutParamText(:final paramKey, isCountUp: true):
        _bind.add(
          'FFLayoutViews.countUp(views, R.id.${id(text)}, '
          'v.date(${kotlinString(paramKey)}), v.frozen)',
        );
        return '$indent<Chronometer$common${_textAttrs(text, attr)} />';
      case LayoutParamText(:final paramKey):
        final value = switch (text.textCase) {
          LayoutCase.upper => 'v.text(${kotlinString(paramKey)}).uppercase()',
          LayoutCase.lower => 'v.text(${kotlinString(paramKey)}).lowercase()',
          LayoutCase.none => 'v.text(${kotlinString(paramKey)})',
        };
        _bind.add('views.setTextViewText(R.id.${id(text)}, ${styled(value)})');
        final preview = defaults[paramKey];
        return '$indent<TextView$common${_textAttrs(text, attr)}'
            '${preview == null || preview.isEmpty ? '' : '\n${attr}android:text="${_xmlAttr(_cased(preview, text.textCase))}"'} />';
    }
  }

  String _image(
    LayoutImage image,
    _Space space,
    String common,
    String attr,
    String indent,
  ) {
    final fit = switch (image.fit) {
      LayoutFit.cover => 'cover',
      LayoutFit.fill => 'fill',
      LayoutFit.contain => 'contain',
    };
    final width = space.forceWidth ? null : image.width.points;
    final height = space.forceHeight ? null : image.height.points;
    final sized = width != null && height != null;
    if (image.paramKey case final key?) {
      // An Image value: the host hands the binder the picture it loaded
      // (`bindImages`); without one the fallback asset is drawn, and
      // without that a neutral block.
      final placeholder = '${prefix}ph_${_name(image)}';
      drawables[placeholder] = '''
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="${color(image, 'placeholder', const LayoutColor(0xFFE0E3E7, 0xFF2B3238))}" />
    <corners android:radius="${_dp(sized ? image.radius : 0)}" />
</shape>
''';
      _imageKeys.add(key);
      _bindImages.add(
        'FFLayoutViews.valueImage(ctx, views, R.id.${id(image)}, '
        'images[${kotlinString(key)}], '
        '${image.assetPath.isEmpty ? 'null' : kotlinString('flutter_assets/${image.assetPath}')}, '
        'R.drawable.$placeholder, '
        '${sized ? '${_num(width)}f, ${_num(height)}f' : '0f, 0f'}, "$fit", '
        '${sized ? _num(image.radius) : 0}f)',
      );
    } else if (sized) {
      // A fixed size: the bitmap is drawn at that size, fitted and rounded
      // as Flutter draws it.
      _bind.add(
        'FFLayoutViews.image(ctx, views, R.id.${id(image)}, '
        '${kotlinString('flutter_assets/${image.assetPath}')}, '
        '${_num(width)}f, ${_num(height)}f, "$fit", ${_num(image.radius)}f)',
      );
    }
    if (sized) {
      return '$indent<ImageView$common'
          '\n${attr}android:scaleType="fitXY" />';
    }
    // Filling, or stretched by its parent: the view fits the picture
    // itself. A rounded one is clipped to its outline, a transparent rounded
    // shape, since the bitmap can't be drawn at a size not known here.
    if (image.paramKey == null) {
      _bind.add(
        'FFLayoutViews.image(ctx, views, R.id.${id(image)}, '
        '${kotlinString('flutter_assets/${image.assetPath}')}, 0f, 0f, "$fit", 0f)',
      );
    }
    final scale = switch (image.fit) {
      LayoutFit.cover => 'centerCrop',
      LayoutFit.fill => 'fitXY',
      LayoutFit.contain => 'fitCenter',
    };
    var rounded = '';
    if (image.radius > 0) {
      final drawable = '${prefix}clip_${_name(image)}';
      drawables[drawable] = '''
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#00000000" />
    <corners android:radius="${_dp(image.radius)}" />
</shape>
''';
      rounded =
          '\n${attr}android:background="@drawable/$drawable"'
          '\n${attr}android:clipToOutline="true"';
    }
    return '$indent<ImageView$common$rounded'
        '\n${attr}android:scaleType="$scale" />';
  }

  String _icon(LayoutIcon icon, String common, String attr, String indent) {
    _bind.add(
      'FFLayoutViews.icon(ctx, views, R.id.${id(icon)}, 0x${icon.codePoint.toRadixString(16)}, '
      '${_num(icon.size)}f)',
    );
    // src_in: the white glyph takes the colour, its alpha included (the
    // default src_atop would lay a see-through colour over white).
    final tint =
        icon.color.color != null
            ? '\n${attr}android:tint="${color(icon, 'icon', icon.color.color!)}"'
                '\n${attr}android:tintMode="src_in"'
            : '\n${attr}android:tintMode="src_in"';
    if (icon.color.paramKey case final key?) {
      _bind.add(
        'FFLayoutViews.tint(views, R.id.${id(icon)}, v.color(${kotlinString(key)}))',
      );
    }
    // The glyph at its size, centred in whatever room the icon is given.
    return '$indent<ImageView$common$tint'
        '\n${attr}android:scaleType="center" />';
  }

  String _divider(
    LayoutDivider divider,
    String common,
    String attr,
    int depth,
  ) {
    final indent = _pad(depth);
    // Flutter's Divider: a line of its thickness, indented, centred in a box
    // of its height.
    return '$indent<FrameLayout$common>\n'
        '$indent    <FrameLayout'
        ' android:layout_width="match_parent"'
        ' android:layout_height="${_dp(divider.thickness)}"'
        ' android:layout_gravity="center_vertical"'
        ' android:layout_marginStart="${_dp(divider.indent)}"'
        ' android:layout_marginEnd="${_dp(divider.endIndent)}"'
        ' android:background="${color(divider, 'line', divider.color)}" />'
        '\n$indent</FrameLayout>';
  }

  String _progress(
    LayoutProgress progress,
    String common,
    String attr,
    int depth,
  ) {
    final indent = _pad(depth);
    if (progress.stages case final stages?) {
      return _stages(progress, stages, common, attr, depth);
    }
    // Timed progress: how far now is between the two dates, worked out each
    // time the card is posted. RemoteViews has no bar that fills by itself.
    final value =
        progress.isTimed
            ? 'FFLayoutViews.timedFraction('
                'v.date(${kotlinString(progress.timedStart!)}), '
                'v.date(${kotlinString(progress.timedEnd!)}))'
            : progress.value.paramKey != null
            ? 'v.double(${kotlinString(progress.value.paramKey!)})'
            : '${progress.value.value}';
    if (!progress.circular) {
      _bind.add(
        'views.setProgressBar(R.id.${id(progress)}, 1000, '
        '(($value).coerceIn(0.0, 1.0) * 1000).toInt(), false)',
      );
      // The track and the bar as one layer list. The bar is scaled, not
      // clipped, so its end keeps its rounded corners as Flutter draws it.
      final drawable = '${prefix}bar_${_name(progress)}';
      final corners = '<corners android:radius="${_dp(progress.barRadius)}" />';
      drawables[drawable] = '''
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:id="@android:id/background">
        <shape><solid android:color="${color(progress, 'track', progress.trackColor)}" />$corners</shape>
    </item>
    <item android:id="@android:id/progress">
        <scale android:scaleWidth="100%" android:scaleGravity="start|fill_vertical">
            <shape><solid android:color="${color(progress, 'bar', progress.color)}" />$corners</shape>
        </scale>
    </item>
</layer-list>
''';
      return '$indent<ProgressBar$common'
          '\n${attr}style="?android:attr/progressBarStyleHorizontal"'
          '\n${attr}android:max="1000"'
          '\n${attr}android:progressDrawable="@drawable/$drawable" />';
    }
    // Two tinted white bitmaps: the full track, and the arc over it.
    final trackId = '${id(progress)}_track';
    _bind
      ..add(
        'FFLayoutViews.ring(views, R.id.$trackId, 1.0, '
        '${_num(progress.size)}f, ${_num(progress.thickness)}f, 0f, ctx)',
      )
      ..add(
        'FFLayoutViews.ring(views, R.id.${id(progress)}_arc, $value, '
        '${_num(progress.size)}f, ${_num(progress.thickness)}f, '
        '${_num(progress.startAngle)}f, ctx)',
      );
    return '$indent<FrameLayout$common>'
        '\n$indent    <ImageView android:id="@+id/$trackId"'
        ' android:layout_width="match_parent" android:layout_height="match_parent"'
        ' android:tint="${color(progress, 'track', progress.trackColor)}"'
        ' android:tintMode="src_in" />'
        '\n$indent    <ImageView android:id="@+id/${id(progress)}_arc"'
        ' android:layout_width="match_parent" android:layout_height="match_parent"'
        ' android:tint="${color(progress, 'arc', progress.color)}"'
        ' android:tintMode="src_in" />'
        '\n$indent</FrameLayout>';
  }

  /// A Stages bar as views, not a drawn bitmap: small in the notification,
  /// crisp text, readable by TalkBack. A column of two rows: the stages
  /// (each a frame holding its piece of the bar and its tracker), then the
  /// labels. `FFLayoutViews.stages` (kotlin_runtime.dart) sets what depends
  /// on the current stage. RemoteViews cannot move a view, so the tracker
  /// is one view per place: the middle of each stage, or its start, middle
  /// and end when a value says how far along the stage it is.
  String _stages(
    LayoutProgress progress,
    LayoutStages stages,
    String common,
    String attr,
    int depth,
  ) {
    final indent = _pad(depth);
    final row = _pad(depth + 1);
    final cell = _pad(depth + 2);
    final leaf = _pad(depth + 3);
    final base = id(progress);
    final name = _name(progress);
    final count = stages.stages.length;
    final tracker = stages.trackerCodePoint;
    final done = color(progress, 'bar', progress.color);
    final upcoming = color(progress, 'upcoming', stages.upcomingColor);
    String shape(String fill) => '''
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="$fill" />
    <corners android:radius="${_dp(progress.barRadius)}" />
</shape>
''';
    drawables['${prefix}stage_${name}_done'] = shape(done);
    drawables['${prefix}stage_${name}_upcoming'] = shape(upcoming);
    final places =
        tracker == null
            ? const <(String, String)>[]
            : stages.progressParamKey == null
            ? const [('', 'center')]
            : const [
              ('a', 'start|center_vertical'),
              ('b', 'center'),
              ('c', 'end|center_vertical'),
            ];
    var trackerTint = '';
    if (tracker != null) {
      drawables['${prefix}stage_${name}_disc'] = '''
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">
    <solid android:color="$done" />
</shape>
''';
      trackerTint = color(
        progress,
        'tracker',
        LayoutColor(
          _onColor(progress.color.light),
          _onColor(progress.color.dark),
        ),
      );
    }
    final rowHeight =
        tracker == null
            ? progress.size
            : (progress.size > LayoutStages.trackerSize
                ? progress.size
                : LayoutStages.trackerSize);
    String gapBefore(int index) =>
        index == 0
            ? ''
            : ' android:layout_marginStart="${_dp(LayoutStages.gap)}"';
    final segments = <String>[];
    final trackers = <String>[];
    final labels = <String>[];
    final icons = <String>[];
    final buffer = StringBuffer(
      '$indent<LinearLayout$common'
      '\n${attr}android:orientation="vertical">\n'
      '$row<LinearLayout android:layout_width="match_parent" '
      'android:layout_height="wrap_content" '
      'android:orientation="horizontal">\n',
    );
    for (var i = 0; i < count; i++) {
      segments.add('${base}_seg$i');
      buffer.write(
        '$cell<FrameLayout android:layout_width="0dp" '
        'android:layout_height="${_dp(rowHeight)}" '
        'android:layout_weight="1"${gapBefore(i)}>\n'
        '$leaf<FrameLayout android:id="@+id/${base}_seg$i" '
        'android:layout_width="match_parent" '
        'android:layout_height="${_dp(progress.size)}" '
        'android:layout_gravity="center_vertical" '
        'android:background="@drawable/${prefix}stage_${name}_upcoming" />\n',
      );
      for (final (suffix, gravity) in places) {
        trackers.add('${base}_trk$i$suffix');
        buffer.write(
          '$leaf<ImageView android:id="@+id/${base}_trk$i$suffix" '
          'android:layout_width="${_dp(LayoutStages.trackerSize)}" '
          'android:layout_height="${_dp(LayoutStages.trackerSize)}" '
          'android:layout_gravity="$gravity" '
          'android:background="@drawable/${prefix}stage_${name}_disc" '
          'android:tint="$trackerTint" android:tintMode="src_in" '
          'android:scaleType="center" android:visibility="gone" />\n',
        );
      }
      buffer.write('$cell</FrameLayout>\n');
    }
    buffer.write('$row</LinearLayout>');
    final texts = <String>[];
    if (stages.showLabels) {
      final labelColor = color(progress, 'label', stages.labelColor);
      color(progress, 'label_upcoming', stages.upcomingLabelColor);
      buffer.write(
        '\n$row<LinearLayout android:layout_width="match_parent" '
        'android:layout_height="wrap_content" '
        'android:layout_marginTop="${_dp(LayoutStages.gap)}" '
        'android:orientation="horizontal">\n',
      );
      for (final (i, stage) in stages.stages.indexed) {
        labels.add('${base}_lbl$i');
        icons.add('${base}_ico$i');
        final (preview, text) = switch (stage.label) {
          LayoutStaticText(:final text) => (text, kotlinString(text)),
          LayoutParamText(:final paramKey) => (
            defaults[paramKey] ?? '',
            'v.text(${kotlinString(paramKey)})',
          ),
        };
        texts.add(text);
        buffer.write(
          '$cell<LinearLayout android:layout_width="0dp" '
          'android:layout_height="wrap_content" android:layout_weight="1" '
          'android:orientation="horizontal" '
          'android:gravity="start|center_vertical"${gapBefore(i)}>\n'
          '$leaf<ImageView android:id="@+id/${base}_ico$i" '
          'android:layout_width="${_dp(stages.labelSize)}" '
          'android:layout_height="${_dp(stages.labelSize)}" '
          'android:layout_marginEnd="3dp" android:tintMode="src_in" '
          'android:scaleType="center" android:visibility="gone" />\n'
          '$leaf<TextView android:id="@+id/${base}_lbl$i" '
          'android:layout_width="wrap_content" '
          'android:layout_height="wrap_content" '
          'android:textSize="${_num(stages.labelSize)}dp" '
          'android:includeFontPadding="false" android:maxLines="1" '
          'android:ellipsize="end" android:textColor="$labelColor"'
          '${preview.isEmpty ? '' : ' android:text="${_xmlAttr(preview)}"'} />\n'
          '$cell</LinearLayout>\n',
        );
      }
      buffer.write('$row</LinearLayout>');
    }
    buffer.write('\n$indent</LinearLayout>');
    String ids(List<String> names) =>
        'intArrayOf(${names.map((n) => 'R.id.$n').join(', ')})';
    String hex(int? codePoint) =>
        codePoint == null ? '0' : '0x${codePoint.toRadixString(16)}';
    final inside =
        stages.progressParamKey == null
            ? 'null'
            : 'v.double(${kotlinString(stages.progressParamKey!)})';
    final args = [
      'v.double(${kotlinString(stages.currentParamKey)})',
      inside,
      ids(segments),
      'R.drawable.${prefix}stage_${name}_done',
      'R.drawable.${prefix}stage_${name}_upcoming',
      ids(trackers),
      hex(tracker),
      ids(labels),
      ids(icons),
      'intArrayOf(${stages.showLabels ? stages.stages.map((s) => hex(s.iconCodePoint)).join(', ') : ''})',
      'arrayOf<String>(${texts.join(', ')})',
      '${_num(stages.labelSize)}f',
      'R.color.${base}_bar',
      stages.showLabels ? 'R.color.${base}_label' : '0',
      stages.showLabels ? 'R.color.${base}_label_upcoming' : '0',
    ];
    _bind.add('FFLayoutViews.stages(ctx, views, ${args.join(', ')})');
    return buffer.toString();
  }

  /// A layout that shows Image values also implements
  /// `FFLayoutImageBinder`: the host calls `bind`, then `bindImages` with
  /// the pictures it has loaded (see kotlin_runtime.dart).
  String binder(String name, String layoutName) =>
      _imageKeys.isEmpty
          ? '''

internal object $name : FFLayoutBinder {
    override val layout: Int = R.layout.$layoutName

    override fun bind(ctx: Context, views: RemoteViews, v: FFValues) {
${_bind.map((line) => '        $line').join('\n')}
    }
}'''
          : '''

internal object $name : FFLayoutBinder, FFLayoutImageBinder {
    override val layout: Int = R.layout.$layoutName

    override fun bind(ctx: Context, views: RemoteViews, v: FFValues) {
${_bind.map((line) => '        $line').join('\n')}
    }

    override val imageKeys: List<String> = listOf(${_imageKeys.map(kotlinString).join(', ')})

    override fun bindImages(ctx: Context, views: RemoteViews, images: Map<String, Bitmap>) {
${_bindImages.map((line) => '        $line').join('\n')}
    }
}''';
}

/// The colour resources of [colors] for `values` ([night] false) or
/// `values-night`.
String remoteViewsColorResources(
  Map<String, LayoutColor> colors, {
  required bool night,
}) {
  final lines = [
    for (final MapEntry(:key, :value) in colors.entries)
      '    <color name="$key">#${(night ? value.dark : value.light).toRadixString(16).padLeft(8, '0').toUpperCase()}</color>',
  ];
  return '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
${lines.join('\n')}
</resources>
''';
}
