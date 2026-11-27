/// The JSON form of a [NativeLayoutModel], shared by the specs that hold
/// layouts (home screen widgets and Live Activity cards), and the small
/// reader those specs read their own JSON with.
///
/// Colors are `#AARRGGBB` (or `#RRGGBB`, opaque), or `{"light": …, "dark":
/// …}` for a color with a dark-mode value. A paint (a fill or text color) is
/// a color or `{"value": key}`, a Color value. Lengths are a number of
/// points, `"fill"` or `"fit"` (the default).
///
/// A card (`card: true`) may also hold what only a card draws: a text that
/// counts up from its date (`countUp`), an image that shows an Image value
/// (`value`, with `asset` as its fallback), a bar that fills between two
/// dates on its own (`timed`), a bar drawn as stages (`stages`), and the
/// layout's `stagesSpecs`.
library;

import 'package:flutterflow_native_layout/src/layout/layout_model.dart';
import 'package:flutterflow_native_layout/src/layout/stage_label_colors.dart';

/// Thrown when JSON does not describe a valid spec. [path] says where
/// (`$.activities[0].surfaces.lockScreen.root.type`).
class NativeLayoutJsonException implements Exception {
  NativeLayoutJsonException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'NativeLayoutJsonException at $path: $message';
}

/// The layout [json] describes.
///
/// [types] are the values text may show, by key. [path] is where [json]
/// is, for errors; [owner] what the values belong to (`'widget'`, `'card'`),
/// for the error of a text that shows a value there is none of.
///
/// With [card], [json] may hold what only a card draws (see the library
/// doc); without it, that is an error. With [darkColors] every color takes
/// its dark value, light and dark: the layout is read for a surface that is
/// always dark. [behind] is what the layout is drawn on, when known: the
/// stage labels that have no color of their own are made readable on it
/// (see [fitStageLabelColors]).
NativeLayoutModel nativeLayoutFromJson(
  Map<String, Object?> json, {
  required Map<String, LayoutValueType> types,
  String path = r'$',
  String owner = 'layout',
  bool card = false,
  bool darkColors = false,
  LayoutColor? behind,
}) {
  final reader = _LayoutReader(
    types: types,
    owner: owner,
    card: card,
    darkColors: darkColors,
  );
  final layout = SpecJsonReader(json, path);
  // The root first: reading it collects the specs of its Stages bars.
  final root = layout.optChild('root')?.let(reader.node);
  final model = NativeLayoutModel(
    root,
    const [],
    tap: layout.optChild('tap')?.let(reader.tap),
    stagesSpecs: switch (layout.json['stagesSpecs']) {
      null => reader.stagesSpecs,
      _ when !card => layout.fail(
        'only a Live Activity card has stage specs',
        'stagesSpecs',
      ),
      _ => [
        for (final spec in layout.children('stagesSpecs'))
          _readStagesSpec(spec),
      ],
    },
  );
  if (card) {
    fitStageLabelColors(model, behind: behind);
  }
  return model;
}

/// [layout] as JSON. `nativeLayoutFromJson(nativeLayoutToJson(layout))`
/// draws the same layout, as long as the reader is given what [layout] was
/// read with (`card`, `darkColors`, `behind`) and [layout] was built as a
/// reader builds it: a stage label's own color, or none and its theme
/// color fitted to what is behind it.
///
/// A layout's own `issues` are not written.
Map<String, Object?> nativeLayoutToJson(NativeLayoutModel layout) {
  final derived = [for (final bar in layout.stageBars) _derivedStagesSpec(bar)];
  return {
    if (layout.tap case final tap?) 'tap': _tapToJson(tap),
    if (layout.root case final root?) 'root': _nodeToJson(root),
    if (!_sameSpecs(layout.stagesSpecs, derived))
      'stagesSpecs': [
        for (final spec in layout.stagesSpecs) _stagesSpecToJson(spec),
      ],
  };
}

/// A color as JSON: `#AARRGGBB`, or `{"light", "dark"}` when they differ.
Object layoutColorToJson(LayoutColor color) =>
    color.light == color.dark
        ? layoutHex(color.light)
        : {'light': layoutHex(color.light), 'dark': layoutHex(color.dark)};

/// [argb] as `#AARRGGBB`, upper case.
String layoutHex(int argb) =>
    '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

// --- Writing ----------------------------------------------------------------

Object _paintToJson(LayoutPaint paint) =>
    paint.paramKey != null
        ? {'value': paint.paramKey}
        : layoutColorToJson(paint.color!);

Object _lengthToJson(LayoutLength length) =>
    length.fill ? 'fill' : (length.points ?? 'fit');

List<double> _alignmentToJson(LayoutAlignment a) => [a.x, a.y];

Object _textToJson(LayoutText text) => switch (text) {
  LayoutStaticText(:final text) => text,
  LayoutParamText(:final paramKey) => {'value': paramKey},
};

Map<String, Object?> _tapToJson(LayoutTap tap) => switch (tap) {
  LayoutOpenPage(:final path, :final params) => {
    'openPage': path,
    if (params.isNotEmpty)
      'params': [
        for (final param in params)
          {
            'name': param.name,
            if (param.paramKey != null) 'value': param.paramKey,
            if (param.constant != null) 'constant': param.constant,
            if (param.paramKey != null &&
                param.format != LayoutRouteFormat.text)
              'format': param.format.name,
          },
      ],
  },
  LayoutToggle(:final paramKey) => {'toggle': paramKey},
  LayoutStep(
    :final paramKey,
    :final step,
    :final min,
    :final max,
    :final integer,
  ) =>
    {
      'step': paramKey,
      'by': step,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (integer) 'integer': true,
    },
  LayoutClear() => {'clear': true},
};

Map<String, Object?> _nodeToJson(LayoutNode node) {
  final json = <String, Object?>{
    'type': switch (node) {
      LayoutBox() => 'box',
      LayoutFlex(:final horizontal) => horizontal ? 'row' : 'column',
      LayoutStack() => 'stack',
      LayoutTextNode() => 'text',
      LayoutImage() => 'image',
      LayoutIcon() => 'icon',
      LayoutSpacer() => 'spacer',
      LayoutDivider() => 'divider',
      LayoutProgress() => 'progress',
    },
    'key': node.nodeKey,
    if (!node.padding.isZero)
      'padding': [
        node.padding.left,
        node.padding.top,
        node.padding.right,
        node.padding.bottom,
      ],
    if (node.flex != null) 'flex': node.flex,
    if (node.visibleParam != null) 'visibleIf': node.visibleParam,
    if (node.tap case final tap?) 'tap': _tapToJson(tap),
    if (node.align case final align?) 'align': _alignmentToJson(align),
  };
  switch (node) {
    case LayoutBox():
      json.addAll({
        if (!node.width.isFit) 'width': _lengthToJson(node.width),
        if (!node.height.isFit) 'height': _lengthToJson(node.height),
        if (node.background case final background?)
          'background': _paintToJson(background),
        if (node.radius != 0) 'radius': node.radius,
        if (node.borderWidth != 0) 'borderWidth': node.borderWidth,
        if (node.borderColor case final color?)
          'borderColor': layoutColorToJson(color),
        if (node.childAlignment case final alignment?)
          'childAlignment': _alignmentToJson(alignment),
        if (node.clip) 'clip': true,
        if (node.child case final child?) 'child': _nodeToJson(child),
      });
    case LayoutFlex():
      json.addAll({
        if (node.mainAxis != LayoutMainAxis.start)
          'mainAxis': node.mainAxis.name,
        if (node.crossAxis != LayoutCrossAxis.center)
          'crossAxis': node.crossAxis.name,
        if (node.spacing != 0) 'spacing': node.spacing,
        if (node.startSpacing != 0) 'startSpacing': node.startSpacing,
        if (node.endSpacing != 0) 'endSpacing': node.endSpacing,
        if (node.shrinkMain) 'shrinkMain': true,
        'children': [for (final item in node.items) _nodeToJson(item)],
      });
    case LayoutStack():
      json.addAll({
        'alignment': _alignmentToJson(node.alignment),
        'children': [for (final item in node.items) _nodeToJson(item)],
      });
    case LayoutTextNode():
      json.addAll({
        ...switch (node.content) {
          LayoutStaticText(:final text) => {'text': text},
          LayoutParamText(:final paramKey, :final countUp) => {
            'value': paramKey,
            if (countUp) 'countUp': true,
          },
        },
        'fontSize': node.fontSize,
        'fontWeight': node.fontWeight,
        'color': _paintToJson(node.color),
        if (node.textAlign != LayoutTextAlign.start)
          'textAlign': node.textAlign.name,
        if (node.maxLines != null) 'maxLines': node.maxLines,
        if (node.ellipsis) 'ellipsis': true,
        if (node.letterSpacing != 0) 'letterSpacing': node.letterSpacing,
        if (node.lineHeight != null) 'lineHeight': node.lineHeight,
        if (node.italic) 'italic': true,
        if (node.underline) 'underline': true,
        if (node.strikethrough) 'strikethrough': true,
        if (node.textCase != LayoutCase.none) 'textCase': node.textCase.name,
      });
    case LayoutImage():
      json.addAll({
        if (node.paramKey != null) 'value': node.paramKey,
        if (node.paramKey == null || node.assetPath.isNotEmpty)
          'asset': node.assetPath,
        if (!node.width.isFit) 'width': _lengthToJson(node.width),
        if (!node.height.isFit) 'height': _lengthToJson(node.height),
        'fit': node.fit.name,
        if (node.radius != 0) 'radius': node.radius,
      });
    case LayoutIcon():
      json.addAll({
        'codePoint': node.codePoint,
        'size': node.size,
        'color': _paintToJson(node.color),
      });
    case LayoutSpacer():
      break;
    case LayoutDivider():
      json.addAll({
        'space': node.space,
        'thickness': node.thickness,
        'color': layoutColorToJson(node.color),
        if (node.indent != 0) 'indent': node.indent,
        if (node.endIndent != 0) 'endIndent': node.endIndent,
      });
    case LayoutProgress():
      json.addAll({
        'circular': node.circular,
        'value':
            node.value.paramKey != null
                ? {'value': node.value.paramKey}
                : node.value.value,
        'color': layoutColorToJson(node.color),
        'trackColor': layoutColorToJson(node.trackColor),
        'size': node.size,
        'thickness': node.thickness,
        if (!node.circular) 'width': _lengthToJson(node.width),
        if (node.barRadius != 0) 'barRadius': node.barRadius,
        if (node.startAngle != 0) 'startAngle': node.startAngle,
        if (node.timedStart != null || node.timedEnd != null)
          'timed': {
            if (node.timedStart != null) 'start': node.timedStart,
            if (node.timedEnd != null) 'end': node.timedEnd,
          },
        if (node.stages case final stages?) 'stages': _stagesToJson(stages),
      });
  }
  return json;
}

/// The colors a stage label takes when the layout sets none and the
/// design's (or theme's) color does not read on what is behind it: done
/// and current labels, upcoming labels.
const _kAutoLabelColor = LayoutColor(0xFF14181B, 0xFFFFFFFF);
const _kAutoUpcomingLabelColor = LayoutColor(0xFF57636C, 0xFF95A1AC);

bool _sameColor(LayoutColor a, LayoutColor b) =>
    a.light == b.light && a.dark == b.dark;

Map<String, Object?> _stagesToJson(LayoutStages stages) => {
  'current': stages.currentParamKey,
  if (stages.progressParamKey != null) 'progress': stages.progressParamKey,
  if (stages.trackerCodePoint != null) 'trackerIcon': stages.trackerCodePoint,
  'upcomingColor': layoutColorToJson(stages.upcomingColor),
  if (!stages.showLabels) 'showLabels': false,
  if (stages.labelSize != 11) 'labelSize': stages.labelSize,
  // A label color the design sets is drawn as it is; otherwise the
  // preferred one is fitted to what is behind the bar.
  ...switch (stages.themedLabelColor) {
    null => {'labelColor': layoutColorToJson(stages.labelColor)},
    final themed when !_sameColor(themed, _kAutoLabelColor) => {
      'preferredLabelColor': layoutColorToJson(themed),
    },
    _ => const {},
  },
  ...switch (stages.themedUpcomingLabelColor) {
    null => {
      'upcomingLabelColor': layoutColorToJson(stages.upcomingLabelColor),
    },
    final themed when !_sameColor(themed, _kAutoUpcomingLabelColor) => {
      'preferredUpcomingLabelColor': layoutColorToJson(themed),
    },
    _ => const {},
  },
  'items': [
    for (final stage in stages.stages)
      {
        'key': stage.key,
        'label': _textToJson(stage.label),
        if (stage.iconCodePoint != null) 'icon': stage.iconCodePoint,
      },
  ],
};

/// The spec a host reads of [bar] when the layout gives none: what the bar
/// draws, its colors' light values.
LayoutStagesSpec _derivedStagesSpec(LayoutProgress bar) =>
    _stagesSpec(bar.stages!, bar.color.light, bar.stages!.upcomingColor.light);

LayoutStagesSpec _stagesSpec(LayoutStages stages, int done, int upcoming) =>
    LayoutStagesSpec(
      labels: [
        for (final stage in stages.stages)
          switch (stage.label) {
            LayoutStaticText(:final text) => text,
            LayoutParamText() => stage.key,
          },
      ],
      labelParamKeys: [
        for (final stage in stages.stages)
          switch (stage.label) {
            LayoutStaticText() => '',
            LayoutParamText(:final paramKey) => paramKey,
          },
      ],
      currentParamKey: stages.currentParamKey,
      progressParamKey: stages.progressParamKey ?? '',
      trackerCodePoint: stages.trackerCodePoint ?? 0,
      doneArgb: done,
      upcomingArgb: upcoming,
      hideLabels: !stages.showLabels,
    );

bool _sameSpecs(List<LayoutStagesSpec> a, List<LayoutStagesSpec> b) {
  if (a.length != b.length) {
    return false;
  }
  bool sameList(List<String> x, List<String> y) =>
      x.length == y.length &&
      [for (var i = 0; i < x.length; i++) x[i] == y[i]].every((e) => e);
  for (var i = 0; i < a.length; i++) {
    final x = a[i];
    final y = b[i];
    if (!sameList(x.labels, y.labels) ||
        !sameList(x.labelParamKeys, y.labelParamKeys) ||
        x.currentParamKey != y.currentParamKey ||
        x.progressParamKey != y.progressParamKey ||
        x.trackerCodePoint != y.trackerCodePoint ||
        x.doneArgb != y.doneArgb ||
        x.upcomingArgb != y.upcomingArgb ||
        x.hideLabels != y.hideLabels) {
      return false;
    }
  }
  return true;
}

Map<String, Object?> _stagesSpecToJson(LayoutStagesSpec spec) => {
  'labels': spec.labels,
  'labelValues': spec.labelParamKeys,
  'current': spec.currentParamKey,
  'progress': spec.progressParamKey,
  'trackerIcon': spec.trackerCodePoint,
  if (spec.doneArgb case final done?) 'doneColor': layoutHex(done),
  if (spec.upcomingArgb case final upcoming?)
    'upcomingColor': layoutHex(upcoming),
  'hideLabels': spec.hideLabels,
};

// --- Reading ----------------------------------------------------------------

/// Reads one JSON object of a spec, and says where it is in each error it
/// throws ([NativeLayoutJsonException]).
class SpecJsonReader {
  SpecJsonReader(this.json, this.path);

  final Map<String, Object?> json;

  /// Where [json] is: `$`, then `.key` and `[index]` steps.
  final String path;

  /// Throws at [key] of this object, or at the object itself.
  Never fail(String message, [String? key]) =>
      throw NativeLayoutJsonException(
        key == null ? path : '$path.$key',
        message,
      );

  /// The value at [key], null when absent. A number reads as a double when
  /// [T] is `double`.
  T? opt<T>(String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (T == double && value is num) {
      return value.toDouble() as T;
    }
    if (value is! T) {
      fail('expected ${_typeName<T>()}, got ${value.runtimeType}', key);
    }
    return value as T;
  }

  T req<T>(String key) => opt<T>(key) ?? fail('missing ${_typeName<T>()}', key);

  SpecJsonReader child(String key) =>
      SpecJsonReader(req<Map<String, Object?>>(key), '$path.$key');

  SpecJsonReader? optChild(String key) => json[key] == null ? null : child(key);

  /// The objects of the list at [key]; empty when absent.
  List<SpecJsonReader> children(String key) {
    final list = opt<List<Object?>>(key) ?? const [];
    return [
      for (var i = 0; i < list.length; i++)
        if (list[i] case final Map<String, Object?> item)
          SpecJsonReader(item, '$path.$key[$i]')
        else
          fail('expected an object', '$key[$i]'),
    ];
  }

  /// The strings of the object at [key], by key; empty when absent.
  Map<String, String> strings(String key) => {
    for (final MapEntry(key: name, :value)
        in (opt<Map<String, Object?>>(key) ?? const {}).entries)
      name: value is String ? value : fail('expected a string', '$key.$name'),
  };

  E enumValue<E extends Enum>(String key, List<E> values, E fallback) {
    final name = opt<String>(key);
    if (name == null) {
      return fallback;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    fail('expected one of ${values.map((v) => v.name).join(', ')}', key);
  }

  /// Fails on the first key that is not one of [known]: a misspelt field
  /// would otherwise be left out without a word.
  void only(Set<String> known) {
    for (final key in json.keys) {
      if (!known.contains(key)) {
        fail('unknown field; expected one of ${known.join(', ')}', key);
      }
    }
  }

  /// The color at [key]: `#AARRGGBB`, `#RRGGBB` or `{"light", "dark"}`.
  LayoutColor color(String key) {
    final value = json[key];
    if (value is String) {
      return LayoutColor.same(hex(value, key));
    }
    if (value is Map<String, Object?>) {
      final colors = child(key);
      return LayoutColor(
        colors.hex(colors.req<String>('light'), 'light'),
        colors.hex(colors.req<String>('dark'), 'dark'),
      );
    }
    fail('expected "#AARRGGBB" or {"light", "dark"}', key);
  }

  LayoutColor? optColor(String key) => json[key] == null ? null : color(key);

  /// [text] (at [key]), `#AARRGGBB` or `#RRGGBB`, as 0xAARRGGBB.
  int hex(String text, String key) {
    final hex = text.startsWith('#') ? text.substring(1) : text;
    final value = int.tryParse(hex, radix: 16);
    if (value == null || (hex.length != 6 && hex.length != 8)) {
      fail('expected "#AARRGGBB" or "#RRGGBB"', key);
    }
    return hex.length == 6 ? 0xFF000000 | value : value;
  }

  /// The Material Icons code point at [key]: a number or `"0xe145"`.
  int? codePoint(String key) => switch (json[key]) {
    null => null,
    final int codePoint => codePoint,
    final String text
        when int.tryParse(text.replaceFirst(RegExp('^0x'), ''), radix: 16) !=
            null =>
      int.parse(text.replaceFirst(RegExp('^0x'), ''), radix: 16),
    _ => fail('expected a Material Icons code point', key),
  };

  R let<R>(R Function(SpecJsonReader reader) read) => read(this);
}

LayoutStagesSpec _readStagesSpec(SpecJsonReader spec) {
  List<String> strings(String key) => [
    for (final (i, item) in (spec.opt<List<Object?>>(key) ?? const []).indexed)
      item is String ? item : spec.fail('expected a string', '$key[$i]'),
  ];
  return LayoutStagesSpec(
    labels: strings('labels'),
    labelParamKeys: strings('labelValues'),
    currentParamKey: spec.opt<String>('current') ?? '',
    progressParamKey: spec.opt<String>('progress') ?? '',
    trackerCodePoint: spec.codePoint('trackerIcon') ?? 0,
    doneArgb: switch (spec.opt<String>('doneColor')) {
      final text? => spec.hex(text, 'doneColor'),
      null => null,
    },
    upcomingArgb: switch (spec.opt<String>('upcomingColor')) {
      final text? => spec.hex(text, 'upcomingColor'),
      null => null,
    },
    hideLabels: spec.opt<bool>('hideLabels') ?? false,
  );
}

class _LayoutReader {
  _LayoutReader({
    required this.types,
    required this.owner,
    required this.card,
    required this.darkColors,
  });

  final Map<String, LayoutValueType> types;
  final String owner;
  final bool card;
  final bool darkColors;

  /// The spec of each Stages bar read, in the order met.
  final stagesSpecs = <LayoutStagesSpec>[];

  LayoutColor tone(LayoutColor color) =>
      darkColors ? LayoutColor.same(color.dark) : color;

  /// Fails when [key] is set on a layout that is not a card's.
  void cardOnly(SpecJsonReader json, String key) {
    if (!card && json.json[key] != null) {
      json.fail('only a Live Activity card can use this', key);
    }
  }

  LayoutColor color(SpecJsonReader json, String key, LayoutColor fallback) =>
      tone(json.optColor(key) ?? fallback);

  LayoutPaint paint(SpecJsonReader json, String key, LayoutPaint fallback) {
    final value = json.json[key];
    if (value == null) {
      return switch (fallback) {
        LayoutPaint(color: final color?) => LayoutPaint.fixed(tone(color)),
        _ => fallback,
      };
    }
    if (value case {'value': final String paramKey}) {
      return LayoutPaint.param(paramKey);
    }
    return LayoutPaint.fixed(tone(json.color(key)));
  }

  LayoutLength length(SpecJsonReader json, String key, LayoutLength fallback) {
    final value = json.json[key];
    return switch (value) {
      null => fallback,
      'fill' => const LayoutLength.fill(),
      'fit' => const LayoutLength.fit(),
      num() => LayoutLength.points(value.toDouble()),
      _ => json.fail('expected a number, "fill" or "fit"', key),
    };
  }

  LayoutAlignment? alignment(SpecJsonReader json, String key) {
    final list = json.opt<List<Object?>>(key);
    if (list == null) {
      return null;
    }
    if (list case [num x, num y]) {
      return LayoutAlignment(x.toDouble(), y.toDouble());
    }
    json.fail('expected [x, y], each from -1 to 1', key);
  }

  LayoutTap tap(SpecJsonReader json) {
    if (json.opt<String>('openPage') case final path?) {
      return LayoutOpenPage(path, [
        for (final param in json.children('params'))
          if (param.opt<String>('value') case final paramKey?)
            LayoutRouteParam.value(
              param.req<String>('name'),
              paramKey,
              param.enumValue(
                'format',
                LayoutRouteFormat.values,
                LayoutRouteFormat.text,
              ),
            )
          else
            LayoutRouteParam.constant(
              param.req<String>('name'),
              param.req<String>('constant'),
            ),
      ]);
    }
    if (json.opt<String>('toggle') case final paramKey?) {
      return LayoutToggle(paramKey);
    }
    if (json.opt<String>('step') case final paramKey?) {
      return LayoutStep(
        paramKey,
        json.req<double>('by'),
        min: json.opt<double>('min'),
        max: json.opt<double>('max'),
        integer: json.opt<bool>('integer') ?? false,
      );
    }
    if (json.opt<bool>('clear') == true) {
      return const LayoutClear();
    }
    json.fail('expected "openPage", "toggle", "step" or "clear"');
  }

  /// The text a value shows, [paramKey] at [key] of [json].
  LayoutParamText paramText(
    SpecJsonReader json,
    String key,
    String paramKey, {
    bool countUp = false,
  }) => LayoutParamText(
    paramKey,
    types[paramKey] ??
        json.fail('no value "$paramKey" in the $owner\'s values', key),
    countUp: countUp,
  );

  List<LayoutNode> items(SpecJsonReader json, String key) => [
    for (final item in json.children(key)) node(item),
  ];

  LayoutNode node(SpecJsonReader json) {
    final key = json.req<String>('key');
    final type = json.req<String>('type');
    final LayoutNode node;
    switch (type) {
      case 'box':
        node =
            LayoutBox(key)
              ..width = length(json, 'width', const LayoutLength.fit())
              ..height = length(json, 'height', const LayoutLength.fit())
              ..background =
                  json.json['background'] == null
                      ? null
                      : paint(
                        json,
                        'background',
                        const LayoutPaint.fixed(LayoutColor.same(0)),
                      )
              ..radius = json.opt<double>('radius') ?? 0
              ..borderWidth = json.opt<double>('borderWidth') ?? 0
              ..borderColor = json.optColor('borderColor')?.let(tone)
              ..childAlignment = alignment(json, 'childAlignment')
              ..clip = json.opt<bool>('clip') ?? false
              ..child = json.optChild('child')?.let(this.node);
      case 'row' || 'column':
        node =
            LayoutFlex(key, horizontal: type == 'row')
              ..mainAxis = json.enumValue(
                'mainAxis',
                LayoutMainAxis.values,
                LayoutMainAxis.start,
              )
              ..crossAxis = json.enumValue(
                'crossAxis',
                LayoutCrossAxis.values,
                LayoutCrossAxis.center,
              )
              ..spacing = json.opt<double>('spacing') ?? 0
              ..startSpacing = json.opt<double>('startSpacing') ?? 0
              ..endSpacing = json.opt<double>('endSpacing') ?? 0
              ..shrinkMain = json.opt<bool>('shrinkMain') ?? false;
        (node as LayoutFlex).items.addAll(items(json, 'children'));
      case 'stack':
        node = LayoutStack(
          key,
        )..alignment = alignment(json, 'alignment') ?? LayoutAlignment.topStart;
        (node as LayoutStack).items.addAll(items(json, 'children'));
      case 'text':
        cardOnly(json, 'countUp');
        final LayoutText content;
        if (json.opt<String>('value') case final paramKey?) {
          content = paramText(
            json,
            'value',
            paramKey,
            countUp: json.opt<bool>('countUp') ?? false,
          );
        } else {
          content = LayoutStaticText(json.req<String>('text'));
        }
        final text =
            LayoutTextNode(key, content)
              ..fontSize = json.opt<double>('fontSize') ?? 14
              ..fontWeight = json.opt<num>('fontWeight')?.toInt() ?? 400
              ..textAlign = json.enumValue(
                'textAlign',
                LayoutTextAlign.values,
                LayoutTextAlign.start,
              )
              ..maxLines = json.opt<num>('maxLines')?.toInt()
              ..ellipsis = json.opt<bool>('ellipsis') ?? false
              ..letterSpacing = json.opt<double>('letterSpacing') ?? 0
              ..lineHeight = json.opt<double>('lineHeight')
              ..italic = json.opt<bool>('italic') ?? false
              ..underline = json.opt<bool>('underline') ?? false
              ..strikethrough = json.opt<bool>('strikethrough') ?? false
              ..textCase = json.enumValue(
                'textCase',
                LayoutCase.values,
                LayoutCase.none,
              );
        text.color = paint(json, 'color', text.color);
        node = text;
      case 'image':
        cardOnly(json, 'value');
        final paramKey = json.opt<String>('value');
        node =
            LayoutImage(
                key,
                paramKey == null
                    ? json.req<String>('asset')
                    : json.opt<String>('asset') ?? '',
                paramKey: paramKey,
              )
              ..width = length(json, 'width', const LayoutLength.fit())
              ..height = length(json, 'height', const LayoutLength.fit())
              ..fit = json.enumValue('fit', LayoutFit.values, LayoutFit.contain)
              ..radius = json.opt<double>('radius') ?? 0;
      case 'icon':
        final icon = LayoutIcon(
          key,
          json.codePoint('codePoint') ??
              json.fail('expected a Material Icons code point', 'codePoint'),
        )..size = json.opt<double>('size') ?? 24;
        icon.color = paint(json, 'color', icon.color);
        node = icon;
      case 'spacer':
        node = LayoutSpacer(key);
      case 'divider':
        final divider =
            LayoutDivider(key)
              ..space = json.opt<double>('space') ?? 16
              ..thickness = json.opt<double>('thickness') ?? 1
              ..indent = json.opt<double>('indent') ?? 0
              ..endIndent = json.opt<double>('endIndent') ?? 0;
        divider.color = color(json, 'color', divider.color);
        node = divider;
      case 'progress':
        cardOnly(json, 'timed');
        cardOnly(json, 'stages');
        final value = json.json['value'];
        final progress =
            LayoutProgress(
                key,
                circular: json.opt<bool>('circular') ?? false,
                value: switch (value) {
                  {'value': final String paramKey} => LayoutFraction.param(
                    paramKey,
                  ),
                  num() => LayoutFraction.fixed(value.toDouble()),
                  _ => json.fail(
                    'expected a number from 0 to 1 or {"value": key}',
                    'value',
                  ),
                },
              )
              ..size = json.opt<double>('size') ?? 100
              ..thickness = json.opt<double>('thickness') ?? 5
              ..width = length(json, 'width', const LayoutLength.fill())
              ..barRadius = json.opt<double>('barRadius') ?? 0
              ..startAngle = json.opt<double>('startAngle') ?? 0;
        final barColor = json.optColor('color') ?? progress.color;
        final trackColor = json.optColor('trackColor') ?? progress.trackColor;
        progress
          ..color = tone(barColor)
          ..trackColor = tone(trackColor);
        if (json.optChild('timed') case final timed?) {
          progress
            ..timedStart = timed.opt<String>('start')
            ..timedEnd = timed.opt<String>('end');
        }
        if (json.optChild('stages') case final stages?) {
          progress.stages = this.stages(stages, barColor, trackColor);
        }
        node = progress;
      default:
        json.fail(
          'unknown node type; expected box, row, column, stack, text, image, '
              'icon, spacer, divider or progress',
          'type',
        );
    }
    if (json.opt<List<Object?>>('padding') case final padding?) {
      if (padding case [num l, num t, num r, num b]) {
        node.padding = LayoutInsets(
          l.toDouble(),
          t.toDouble(),
          r.toDouble(),
          b.toDouble(),
        );
      } else {
        json.fail('expected [left, top, right, bottom]', 'padding');
      }
    }
    node
      ..flex = json.opt<num>('flex')?.toInt()
      ..visibleParam = json.opt<String>('visibleIf')
      ..tap = json.optChild('tap')?.let(tap)
      ..align = alignment(json, 'align');
    return node;
  }

  /// A bar's Stages mode. [barColor] and [trackColor] are the bar's colors
  /// as the JSON gives them, before [tone]: the spec a host reads of the
  /// bar takes their light values whatever surface the layout is read for.
  LayoutStages stages(
    SpecJsonReader json,
    LayoutColor barColor,
    LayoutColor trackColor,
  ) {
    final upcoming = json.optColor('upcomingColor') ?? trackColor;
    final ownLabel = json.optColor('labelColor');
    final ownUpcomingLabel = json.optColor('upcomingLabelColor');
    final autoLabel = tone(
      json.optColor('preferredLabelColor') ?? _kAutoLabelColor,
    );
    final autoUpcomingLabel = tone(
      json.optColor('preferredUpcomingLabelColor') ?? _kAutoUpcomingLabelColor,
    );
    final stages =
        LayoutStages(
            stages: [
              for (final stage in json.children('items'))
                LayoutStage(stage.req<String>('key'), switch (stage
                    .json['label']) {
                  null => const LayoutStaticText(''),
                  final String text => LayoutStaticText(text),
                  {'value': final String paramKey} => paramText(
                    stage,
                    'label',
                    paramKey,
                  ),
                  _ => stage.fail('expected a text or {"value": key}', 'label'),
                }, stage.codePoint('icon')),
            ],
            currentParamKey: json.req<String>('current'),
            upcomingColor: tone(upcoming),
            labelColor: ownLabel?.let(tone) ?? autoLabel,
            upcomingLabelColor:
                ownUpcomingLabel?.let(tone) ?? autoUpcomingLabel,
          )
          ..themedLabelColor = ownLabel == null ? autoLabel : null
          ..themedUpcomingLabelColor =
              ownUpcomingLabel == null ? autoUpcomingLabel : null
          ..progressParamKey = json.opt<String>('progress')
          ..trackerCodePoint = json.codePoint('trackerIcon')
          ..showLabels = json.opt<bool>('showLabels') ?? true
          ..labelSize = json.opt<double>('labelSize') ?? 11;
    stagesSpecs.add(_stagesSpec(stages, barColor.light, upcoming.light));
    return stages;
  }
}

extension on LayoutColor {
  R let<R>(R Function(LayoutColor color) f) => f(this);
}

String _typeName<T>() => switch (T) {
  const (String) => 'a string',
  const (bool) => 'true or false',
  const (double) || const (num) || const (int) => 'a number',
  const (List<Object?>) => 'a list',
  const (Map<String, Object?>) => 'an object',
  _ => '$T',
};
