/// SwiftUI for a home widget layout.
///
/// Each layout becomes one `View` struct that reads the widget's values
/// through `FFValues` (defined in `HomeWidgetViews.swift`). SwiftUI sizes
/// views by proposals where Flutter passes constraints down, so the emitter
/// tracks the constraints Flutter would give each node and writes the frames
/// that reproduce them:
/// - Each node knows which axes its parent bounds (a Column bounds the width
///   it gives a child, not the height, unless the child is Expanded) and
///   which it forces (a sized Container forces its child to its size).
/// - Padding is outside a widget, its fill and border included (FlutterFlow
///   wraps the widget in a Padding); an Alignment wraps that.
/// - A Column or Row lays out FlutterFlow's children: its spacing is a fixed
///   gap between visible children, and the main-axis alignment shares the
///   free space between all of them, gaps included.
/// - A text bound to a date counts down to it, like `Text(_:style: .timer)`.
library;

import 'package:flutterflow_home_widget/src/layout/layout_model.dart';
import 'package:flutterflow_home_widget/src/escape.dart';

/// Swift struct name of a layout's view.
String swiftLayoutViewName(String widgetKey, String sizeName) =>
    'FFLayout_${identifierPart(widgetKey)}_$sizeName';

/// The Swift source of [model]'s view, named [viewName]. [widgetKey] is the
/// widget's key, which its buttons change.
String swiftLayoutView(
  String viewName,
  HomeWidgetLayoutModel model, {
  String widgetKey = '',
}) {
  final root = model.root;
  var body = root == null
      ? 'Color.clear'
      : _SwiftEmitter(widgetKey).view(root, 2, _Space.root);
  body +=
      '\n      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)';
  switch (model.tap) {
    case LayoutOpenPage page:
      body += '\n      .widgetURL(${swiftPageUrl(page)})';
    case LayoutButton button:
      body = '${swiftButton(widgetKey, button)} {\n      $body\n    }';
    case null:
      break;
  }
  return '''

struct $viewName: View {
  let values: FFValues

  var body: some View {
    $body
  }
}
''';
}

String _swiftOptional(double? value) => value == null ? 'nil' : _num(value);

/// The Swift `FFButton(...)` (the label follows as a trailing closure) of
/// [button] on widget [widgetKey].
String swiftButton(String widgetKey, LayoutButton button) {
  final (kind, value, step, min, max, integer) = switch (button) {
    LayoutToggle(:final paramKey) => (
      'toggle',
      paramKey,
      0.0,
      null,
      null,
      false,
    ),
    LayoutStep(
      :final paramKey,
      :final step,
      :final min,
      :final max,
      :final integer,
    ) =>
      ('step', paramKey, step, min, max, integer),
    LayoutClear() => ('clear', '', 0.0, null, null, false),
  };
  return 'FFButton(widget: ${swiftString(widgetKey)}, choice: values.choice, '
      'kind: ${swiftString(kind)}, value: ${swiftString(value)}, '
      'step: ${_num(step)}, min: ${_swiftOptional(min)}, '
      'max: ${_swiftOptional(max)}, integer: $integer)';
}

/// A Swift `URL` expression of [page]'s deep link with the widget's values.
String swiftPageUrl(LayoutOpenPage page) {
  final params = [
    for (final param in page.params)
      '(${swiftString(param.name)}, ${_routeValue(param)})',
  ];
  return 'FFPageURL(${swiftString(page.path)}, [${params.join(', ')}])';
}

String _routeValue(LayoutRouteParam param) {
  if (param.constant != null) {
    return swiftString(param.constant!);
  }
  final key = swiftString(param.paramKey!);
  return switch (param.format) {
    LayoutRouteFormat.text => 'values.routeText($key)',
    LayoutRouteFormat.date => 'values.routeDate($key)',
    LayoutRouteFormat.color => 'values.routeColor($key)',
  };
}

/// A Swift string literal of [value]: `"`, `\` and line breaks escaped.
String swiftString(String value) {
  return '"${escapeEach(value, kSwiftStringEscapes)}"';
}

String _num(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

String _hex(int argb) =>
    '0x${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

String swiftColor(LayoutColor color) =>
    'FFColor(light: ${_hex(color.light)}, dark: ${_hex(color.dark)})';

/// The constraints a parent gives a child, per axis: whether the axis is
/// bounded (the child may fill it) and whether it is forced (the child has
/// exactly the parent's size on it, whatever its own).
class _Space {
  const _Space({
    required this.boundedWidth,
    required this.boundedHeight,
    this.forceWidth = false,
    this.forceHeight = false,
  });

  static const root = _Space(boundedWidth: true, boundedHeight: true);

  final bool boundedWidth;
  final bool boundedHeight;
  final bool forceWidth;
  final bool forceHeight;
}

/// A Swift Boolean expression; `true` when it always holds.
typedef _Condition = String;

_Condition _or(Iterable<_Condition> conditions) {
  final list = conditions.toList();
  if (list.isEmpty) return 'false';
  if (list.contains('true')) return 'true';
  return list.length == 1 ? list.single : '(${list.join(' || ')})';
}

class _SwiftEmitter {
  _SwiftEmitter(this.widgetKey);

  /// The widget's key, which its buttons change.
  final String widgetKey;

  String _pad(int depth) => '  ' * depth;

  String _paint(LayoutPaint paint) => paint.paramKey != null
      ? 'values.color(${swiftString(paint.paramKey!)})'
      : swiftColor(paint.color!);

  _Condition _visible(LayoutNode node) => node.visibleParam == null
      ? 'true'
      : 'values.bool(${swiftString(node.visibleParam!)})';

  String _alignment(LayoutAlignment a) {
    final h = a.x < -0.33 ? 'leading' : (a.x > 0.33 ? 'trailing' : '');
    final v = a.y < -0.33 ? 'top' : (a.y > 0.33 ? 'bottom' : '');
    if (h.isEmpty && v.isEmpty) return '.center';
    if (v.isEmpty) return '.$h';
    if (h.isEmpty) return '.$v';
    return '.$v${h[0].toUpperCase()}${h.substring(1)}';
  }

  String _padding(LayoutInsets p) => p.isZero
      ? ''
      : '.padding(EdgeInsets(top: ${_num(p.top)}, leading: ${_num(p.left)}, '
            'bottom: ${_num(p.bottom)}, trailing: ${_num(p.right)}))';

  /// A frame that fills the axes given, aligning the content in it.
  String _fill({
    required bool width,
    required bool height,
    required String alignment,
  }) {
    if (!width && !height) return '';
    final parts = [
      if (width) 'maxWidth: .infinity',
      if (height) 'maxHeight: .infinity',
    ];
    return '.frame(${parts.join(', ')}, alignment: $alignment)';
  }

  /// A side's own size: forced to the parent's when the parent forces the
  /// axis, else the node's length (a fill only when the axis is bounded).
  LayoutLength _side(LayoutLength own, {required bool forced}) =>
      forced ? const LayoutLength.fill() : own;

  String _fixedFrame(LayoutLength width, LayoutLength height) {
    final parts = [
      if (width.points != null) 'width: ${_num(width.points!)}',
      if (height.points != null) 'height: ${_num(height.points!)}',
    ];
    return parts.isEmpty ? '' : '.frame(${parts.join(', ')})';
  }

  /// Where a node's content sits in a frame bigger than it, as Flutter puts
  /// a child given more room than it takes: a Text by its alignment, a
  /// Column or Row by its cross axis, anything else at the top start.
  String _contentAlignment(LayoutNode node) => switch (node) {
    LayoutTextNode(:final textAlign) => switch (textAlign) {
      LayoutTextAlign.center => '.top',
      LayoutTextAlign.end => '.topTrailing',
      LayoutTextAlign.start => '.topLeading',
    },
    LayoutFlex(:final horizontal, :final crossAxis) => _alignment(
      horizontal
          ? LayoutAlignment(-1, _crossValue(crossAxis))
          : LayoutAlignment(_crossValue(crossAxis), -1),
    ),
    LayoutIcon() => '.center',
    _ => '.topLeading',
  };

  double _crossValue(LayoutCrossAxis cross) => switch (cross) {
    LayoutCrossAxis.center => 0,
    LayoutCrossAxis.end => 1,
    _ => -1,
  };

  /// [node] in [space], with its padding and alignment. Its visibility is
  /// applied here unless [visibility] is false (a Column or Row hides a
  /// child together with the gap before it).
  String view(
    LayoutNode node,
    int depth,
    _Space space, {
    bool visibility = true,
  }) {
    // An Alignment is an Align around the node and its padding: it takes
    // the room the parent bounds, and the node inside is loose.
    final align = node.align;
    final inner = align == null
        ? space
        : const _Space(boundedWidth: true, boundedHeight: true);
    var code = switch (node) {
      LayoutBox() => _box(node, depth, inner),
      LayoutFlex() => _flex(node, depth, inner),
      LayoutStack() => _stack(node, depth, inner),
      LayoutTextNode() => _text(node, inner),
      LayoutImage() => _image(node, inner),
      LayoutIcon() => _icon(node, inner),
      LayoutSpacer() => 'Spacer(minLength: 0)',
      LayoutDivider() => _divider(node, inner),
      LayoutProgress() => _progress(node, inner),
    };
    // A Link around the node without its padding: the same area Android
    // takes taps on (its view, the padding being margins).
    switch (node.tap) {
      case LayoutOpenPage page:
        code =
            'Link(destination: ${swiftPageUrl(page)}) {\n'
            '${_pad(depth + 1)}$code\n${_pad(depth)}}';
      case LayoutButton button:
        code =
            '${swiftButton(widgetKey, button)} {\n'
            '${_pad(depth + 1)}$code\n${_pad(depth)}}';
      case null:
        break;
    }
    code += _padding(node.padding);
    if (align != null) {
      code += _fill(
        width: space.boundedWidth,
        height: space.boundedHeight,
        alignment: _alignment(align),
      );
    }
    if (visibility && node.visibleParam != null) {
      code =
          'Group {\n${_pad(depth + 1)}if ${_visible(node)} {\n'
          '${_pad(depth + 2)}$code\n${_pad(depth + 1)}}\n${_pad(depth)}}';
    }
    return code;
  }

  String _box(LayoutBox box, int depth, _Space space) {
    final width = _side(box.width, forced: space.forceWidth);
    final height = _side(box.height, forced: space.forceHeight);
    final buffer = StringBuffer();
    final child = box.child;
    if (child == null) {
      // An empty Container takes all the room it is given on a bounded axis
      // and none on an unbounded one.
      buffer.write('Color.clear');
      if (width.isFit && !space.boundedWidth) buffer.write('.frame(width: 0)');
      if (height.isFit && !space.boundedHeight) {
        buffer.write('.frame(height: 0)');
      }
      buffer.write(
        _fill(
          width: width.fill || (width.isFit && space.boundedWidth),
          height: height.fill || (height.isFit && space.boundedHeight),
          alignment: '.topLeading',
        ),
      );
    } else {
      // The room the box gives its child: a sized side forces the child to
      // the box's size (Flutter's tight constraints); a fitted side passes
      // the parent's bound on. An alignment loosens both.
      final aligned = box.childAlignment != null;
      final childSpace = _Space(
        boundedWidth: !width.isFit || space.boundedWidth,
        boundedHeight: !height.isFit || space.boundedHeight,
        forceWidth: !aligned && !width.isFit,
        forceHeight: !aligned && !height.isFit,
      );
      buffer.write(view(child, depth, childSpace));
      // A border insets the child by its width, as BoxDecoration does.
      if (box.borderWidth > 0) {
        buffer.write('.padding(${_num(box.borderWidth)})');
      }
      if (aligned) {
        // An aligned child: the box takes the room on its bounded sides and
        // places the child in it.
        buffer.write(
          _fill(
            width: !width.isFit || space.boundedWidth,
            height: !height.isFit || space.boundedHeight,
            alignment: _alignment(box.childAlignment!),
          ),
        );
      } else {
        buffer.write(
          _fill(
            width: !width.isFit,
            height: !height.isFit,
            alignment: _contentAlignment(child),
          ),
        );
      }
    }
    buffer.write(_fixedFrame(width, height));
    final shape =
        'RoundedRectangle(cornerRadius: ${_num(box.radius)}, '
        'style: .continuous)';
    if (box.background != null) {
      buffer.write('.background($shape.fill(${_paint(box.background!)}))');
    }
    if (box.borderWidth > 0 && box.borderColor != null) {
      buffer.write(
        '.overlay($shape.strokeBorder(${swiftColor(box.borderColor!)}, '
        'lineWidth: ${_num(box.borderWidth)}))',
      );
    }
    if (box.clip) {
      buffer.write('.clipShape($shape)');
    }
    return buffer.toString();
  }

  String _flex(LayoutFlex flex, int depth, _Space space) {
    final h = flex.horizontal;
    final stack = h ? 'HStack' : 'VStack';
    final cross = switch (flex.crossAxis) {
      LayoutCrossAxis.start => h ? '.top' : '.leading',
      LayoutCrossAxis.end => h ? '.bottom' : '.trailing',
      _ => '.center',
    };
    final pad = _pad(depth + 1);
    final children = flex.items;
    final expands = children.any((c) => c.flex != null);
    final mainBounded = h ? space.boundedWidth : space.boundedHeight;
    // Whether the free main-axis space is shared out by the alignment. A
    // flex that hugs its children, or one with an expanding child, has none.
    final free = !flex.shrinkMain && !expands && mainBounded;
    final mode = free ? flex.mainAxis : LayoutMainAxis.start;
    final between = switch (mode) {
      LayoutMainAxis.spaceBetween || LayoutMainAxis.spaceEvenly => 1,
      LayoutMainAxis.spaceAround => 2,
      _ => 0,
    };
    final edge = switch (mode) {
      LayoutMainAxis.spaceAround || LayoutMainAxis.spaceEvenly => 1,
      _ => 0,
    };
    final spacer = '${pad}Spacer(minLength: 0)';
    List<String> slot(int count) => List.filled(count, spacer);
    // Zero across the axis, like Flutter's SizedBox gap: a Color.clear left
    // free across would be greedy and change how the stack shares space.
    String gap(double size) =>
        '${pad}Color.clear.frame(width: ${h ? _num(size) : 0}, '
        'height: ${h ? 0 : _num(size)})';

    // Flutter's children: the start gap, the children with a gap between
    // each two visible ones, the end gap. The alignment shares the free
    // space between every two of them.
    final lines = <String>[...slot(edge)];
    final hasStart = flex.startSpacing > 0;
    if (hasStart) lines.add(gap(flex.startSpacing));
    final shown = <_Condition>[];
    for (final child in children) {
      final visible = _visible(child);
      final anyBefore = _or(shown);
      // What comes before this child when it shows: a gap (with its share
      // of the free space either side) after an earlier visible child, or a
      // share of the space after the start gap.
      final afterChild = [
        ...slot(between),
        if (flex.spacing > 0) ...[gap(flex.spacing), ...slot(between)],
      ];
      final afterStart = hasStart ? slot(between) : const <String>[];
      final childCode = _flexChild(flex, child, depth + 1, space);
      final body = <String>[];
      if (anyBefore == 'true') {
        body.addAll(afterChild);
      } else if (anyBefore != 'false' &&
          (afterChild.isNotEmpty || afterStart.isNotEmpty)) {
        body.add(
          '${pad}if $anyBefore {\n'
          '${afterChild.map((l) => '  $l').join('\n')}\n'
          '$pad}${afterStart.isEmpty ? '' : ' else {\n${afterStart.map((l) => '  $l').join('\n')}\n$pad}'}',
        );
      } else {
        body.addAll(afterStart);
      }
      body.add('$pad$childCode');
      if (visible == 'true') {
        lines.addAll(body);
      } else {
        lines.add(
          '${pad}if $visible {\n'
          '${body.map((l) => '  $l').join('\n')}\n$pad}',
        );
      }
      shown.add(visible);
    }
    if (flex.endSpacing > 0) {
      lines
        ..addAll(slot(between))
        ..add(gap(flex.endSpacing));
    }
    lines.addAll(slot(edge));
    if (free) {
      if (mode == LayoutMainAxis.center || mode == LayoutMainAxis.end) {
        lines.insert(0, spacer);
      }
      if (mode == LayoutMainAxis.center || mode == LayoutMainAxis.start) {
        lines.add(spacer);
      }
    }
    final fill = switch ((h, flex.shrinkMain, mainBounded)) {
      (_, true, _) || (_, _, false) => '',
      (true, _, _) => '.frame(maxWidth: .infinity)',
      (false, _, _) => '.frame(maxHeight: .infinity)',
    };
    // A forced cross axis (a stretching parent, a sized box) widens the
    // flex itself; its children keep their cross alignment within it.
    final crossFill = (h ? space.forceHeight : space.forceWidth)
        ? (h
              ? '.frame(maxHeight: .infinity, alignment: ${_alignment(LayoutAlignment(-1, _crossValue(flex.crossAxis)))})'
              : '.frame(maxWidth: .infinity, alignment: ${_alignment(LayoutAlignment(_crossValue(flex.crossAxis), -1))})')
        : '';
    return '$stack(alignment: $cross, spacing: 0) {\n'
        '${lines.join('\n')}\n${_pad(depth)}}$fill$crossFill';
  }

  /// A child of a Column or Row, with what the flex gives it: its share of
  /// the space when it expands, the whole cross axis when the flex
  /// stretches.
  String _flexChild(LayoutFlex flex, LayoutNode child, int depth, _Space at) {
    final h = flex.horizontal;
    final expands = child.flex != null && child is! LayoutSpacer;
    final stretch = flex.crossAxis == LayoutCrossAxis.stretch;
    final crossBounded = h ? at.boundedHeight : at.boundedWidth;
    final space = _Space(
      boundedWidth: h ? expands : crossBounded,
      boundedHeight: h ? crossBounded : expands,
      forceWidth: h ? expands : stretch && crossBounded,
      forceHeight: h ? stretch && crossBounded : expands,
    );
    var code = view(child, depth, space, visibility: false);
    if (child is LayoutSpacer) {
      return code;
    }
    // Forced sides the child does not fill itself (a Text, an Icon): frame
    // them, the content placed as Flutter places it.
    final fillWidth = space.forceWidth && !_fillsForced(child);
    final fillHeight = space.forceHeight && !_fillsForced(child);
    code += _fill(
      width: fillWidth,
      height: fillHeight,
      alignment: _contentAlignment(child),
    );
    return code;
  }

  /// Whether [node] already fills forced sides on its own.
  bool _fillsForced(LayoutNode node) =>
      node.align == null &&
      (node is LayoutBox || node is LayoutFlex || node is LayoutImage);

  String _stack(LayoutStack stack, int depth, _Space space) {
    // A Stack's children are loose in the room the Stack has.
    final childSpace = _Space(
      boundedWidth: space.boundedWidth,
      boundedHeight: space.boundedHeight,
    );
    final items = [
      for (final child in stack.items)
        '${_pad(depth + 1)}${view(child, depth + 1, childSpace)}',
    ];
    final forced = _fill(
      width: space.forceWidth,
      height: space.forceHeight,
      alignment: _alignment(stack.alignment),
    );
    return 'ZStack(alignment: ${_alignment(stack.alignment)}) {\n'
        '${items.join('\n')}\n${_pad(depth)}}$forced';
  }

  String _case(String expression, LayoutCase textCase) => switch (textCase) {
    LayoutCase.upper => '$expression.uppercased()',
    LayoutCase.lower => '$expression.lowercased()',
    LayoutCase.none => expression,
  };

  String _text(LayoutTextNode text, _Space space) {
    final content = text.content;
    final base = switch (content) {
      LayoutStaticText(:final text) => 'Text(${swiftString(text)})',
      LayoutParamText(:final paramKey, isCountdown: true) =>
        'FFCountdownText(end: values.date(${swiftString(paramKey)}))',
      LayoutParamText(:final paramKey) =>
        'Text(${_case('values.text(${swiftString(paramKey)})', text.textCase)})',
    };
    final staticCase = content is LayoutStaticText
        ? text.textCase
        : LayoutCase.none;
    final weight = switch (text.fontWeight) {
      <= 100 => '.ultraLight',
      <= 200 => '.thin',
      <= 300 => '.light',
      <= 400 => '.regular',
      <= 500 => '.medium',
      <= 600 => '.semibold',
      <= 700 => '.bold',
      <= 800 => '.heavy',
      _ => '.black',
    };
    final align = switch (text.textAlign) {
      LayoutTextAlign.center => '.center',
      LayoutTextAlign.end => '.trailing',
      _ => '.leading',
    };
    final buffer = StringBuffer(
      staticCase == LayoutCase.none
          ? base
          : 'Text(${swiftString(switch (staticCase) {
              LayoutCase.upper => (content as LayoutStaticText).text.toUpperCase(),
              _ => (content as LayoutStaticText).text.toLowerCase(),
            })})',
    );
    buffer.write(
      '.font(.system(size: ${_num(text.fontSize)}, weight: $weight))',
    );
    if (text.italic) buffer.write('.italic()');
    if (text.underline) buffer.write('.underline()');
    if (text.strikethrough) buffer.write('.strikethrough()');
    if (text.letterSpacing != 0) {
      buffer.write('.kerning(${_num(text.letterSpacing)})');
    }
    buffer
      ..write('.foregroundColor(${_paint(text.color)})')
      ..write('.multilineTextAlignment($align)');
    // Flutter cuts a text at its last line; "…" only with Ellipsis.
    final lines = text.maxLines;
    if (lines != null && text.ellipsis) {
      buffer.write('.lineLimit($lines)');
    }
    final clip = lines != null && !text.ellipsis ? '$lines' : 'nil';
    if (text.lineHeight != null || clip != 'nil') {
      buffer.write(
        '.ffLines(size: ${_num(text.fontSize)}, weight: $weight, '
        'height: ${text.lineHeight == null ? 'nil' : _num(text.lineHeight!)}, '
        'clip: $clip)',
      );
    }
    return buffer.toString();
  }

  String _image(LayoutImage image, _Space space) {
    final mode = switch (image.fit) {
      LayoutFit.cover => '.fill',
      LayoutFit.fill => 'nil',
      LayoutFit.contain => '.fit',
    };
    final width = _side(image.width, forced: space.forceWidth);
    final height = _side(image.height, forced: space.forceHeight);
    final picture =
        'FFAssetImage(path: ${swiftString(image.assetPath)}, contentMode: $mode)';
    // A filling image takes the room it is given, as Flutter's does. An
    // aspect-filled SwiftUI image reports its own, larger size instead, which
    // would grow a Stack around it past the widget; so it is drawn over a
    // clear view of that room.
    final fills = width.fill || height.fill;
    final buffer = StringBuffer(fills ? 'Color.clear' : picture)
      ..write(_fixedFrame(width, height))
      ..write(
        _fill(width: width.fill, height: height.fill, alignment: '.center'),
      );
    if (fills) {
      buffer.write('.overlay($picture)');
    }
    if (image.radius > 0) {
      buffer.write(
        '.clipShape(RoundedRectangle(cornerRadius: ${_num(image.radius)}, '
        'style: .continuous))',
      );
    } else if (image.fit == LayoutFit.cover || fills) {
      buffer.write('.clipped()');
    }
    return buffer.toString();
  }

  String _icon(LayoutIcon icon, _Space space) =>
      'FFIconText(codePoint: 0x${icon.codePoint.toRadixString(16)}, '
      'size: ${_num(icon.size)}, color: ${_paint(icon.color)})';

  String _divider(LayoutDivider divider, _Space space) =>
      // Flutter's Divider: a line of its thickness, indented, centred in a
      // box of its height across the whole width it is given.
      'Rectangle().fill(${swiftColor(divider.color)})'
      '.frame(height: ${_num(divider.thickness)})'
      '.padding(.leading, ${_num(divider.indent)})'
      '.padding(.trailing, ${_num(divider.endIndent)})'
      '.frame(maxWidth: .infinity)'
      '.frame(height: ${_num(divider.space)})';

  String _progress(LayoutProgress progress, _Space space) {
    final value = progress.value.paramKey != null
        ? 'values.double(${swiftString(progress.value.paramKey!)})'
        : _num(progress.value.value!);
    final colors =
        'color: ${swiftColor(progress.color)}, track: ${swiftColor(progress.trackColor)}';
    if (progress.circular) {
      return 'FFRingProgress(value: $value, $colors, '
          'diameter: ${_num(progress.size)}, thickness: ${_num(progress.thickness)}, '
          'startAngle: ${_num(progress.startAngle)})';
    }
    final width = _side(progress.width, forced: space.forceWidth);
    return 'FFBarProgress(value: $value, $colors, height: ${_num(progress.size)}, '
        'cornerRadius: ${_num(progress.barRadius)})'
        '${_fixedFrame(width, const LayoutLength.fit())}'
        '${_fill(width: width.fill, height: false, alignment: '.leading')}';
  }
}
