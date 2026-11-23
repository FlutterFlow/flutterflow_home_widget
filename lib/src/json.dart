/// The JSON form of a [HomeWidgetApp], for tools that write the spec rather
/// than build it in Dart. `doc/spec.md` describes every field.
///
/// Colors are `#AARRGGBB` (or `#RRGGBB`, opaque), or `{"light": …, "dark":
/// …}` for a color with a dark-mode value. A paint (a fill or text color) is
/// a color or `{"value": key}`, a Color value of the widget. Lengths are a
/// number of points, `"fill"` or `"fit"` (the default).
library;

import 'package:flutterflow_home_widget/src/layout/layout_model.dart';
import 'package:flutterflow_home_widget/src/refresh.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Thrown when JSON does not describe a valid spec. [path] says where.
class HomeWidgetJsonException implements Exception {
  HomeWidgetJsonException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'HomeWidgetJsonException at $path: $message';
}

/// The app [json] describes.
HomeWidgetApp homeWidgetAppFromJson(Map<String, Object?> json) =>
    _Reader(json, r'$').app();

/// [app] as JSON. `homeWidgetAppFromJson(homeWidgetAppToJson(app))`
/// generates the same files as [app].
Map<String, Object?> homeWidgetAppToJson(HomeWidgetApp app) => {
  'iosBundleId': app.iosBundleId,
  'iosDeviceFamily': app.iosDeviceFamily,
  'routes': {
    'scheme': app.routes.scheme,
    'host': app.routes.host,
    'encodeTwice': app.routes.encodeTwice,
  },
  'widgets': [for (final widget in app.widgets) _widgetToJson(widget)],
};

Map<String, Object?> _widgetToJson(HomeWidgetDefinition widget) => {
  'key': widget.key,
  'name': widget.name,
  if (widget.description.isNotEmpty) 'description': widget.description,
  if (widget.placeholderText.isNotEmpty)
    'placeholderText': widget.placeholderText,
  'values': [
    for (final value in widget.values)
      {
        'key': value.key,
        'name': value.name,
        'type': value.type.id,
        if (value.defaultValue != null) 'default': value.defaultValue,
      },
  ],
  'layouts': {
    for (final (size, layout) in widget.sizedLayouts)
      size.name: _layoutToJson(layout),
  },
  if (widget.refresh case final refresh?)
    'refresh': {
      'url': refresh.url,
      if (refresh.headers.isNotEmpty) 'headers': refresh.headers,
      'intervalMinutes': refresh.intervalMinutes,
      'values': [
        for (final value in refresh.values)
          {
            'key': value.key,
            'type': value.type.id,
            'path': _jsonPathString(value.path),
          },
      ],
    },
  if (widget.configuration case final configuration?)
    'configuration': {
      if (configuration.title.isNotEmpty) 'title': configuration.title,
      'choices': [
        for (final choice in configuration.choices)
          {'id': choice.id, 'name': choice.name, 'values': choice.values},
      ],
      'appChoices': configuration.appChoices,
    },
};

String _jsonPathString(List<JsonStep> path) => [
  r'$',
  for (final step in path)
    switch (step) {
      JsonKey(:final name) =>
        RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(name) ? '.$name' : "['$name']",
      JsonIndex(:final index) => '[$index]',
    },
].join();

Map<String, Object?> _layoutToJson(HomeWidgetLayoutModel layout) => {
  if (layout.tap case final tap?) 'tap': _tapToJson(tap),
  if (layout.root case final root?) 'root': _nodeToJson(root),
};

Object _colorToJson(LayoutColor color) => color.light == color.dark
    ? _hex(color.light)
    : {'light': _hex(color.light), 'dark': _hex(color.dark)};

String _hex(int argb) =>
    '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

Object _paintToJson(LayoutPaint paint) => paint.paramKey != null
    ? {'value': paint.paramKey}
    : _colorToJson(paint.color!);

Object _lengthToJson(LayoutLength length) =>
    length.fill ? 'fill' : (length.points ?? 'fit');

List<double> _alignmentToJson(LayoutAlignment a) => [a.x, a.y];

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
      'min': ?min,
      'max': ?max,
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
    'flex': ?node.flex,
    'visibleIf': ?node.visibleParam,
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
          'borderColor': _colorToJson(color),
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
          LayoutParamText(:final paramKey) => {'value': paramKey},
        },
        'fontSize': node.fontSize,
        'fontWeight': node.fontWeight,
        'color': _paintToJson(node.color),
        if (node.textAlign != LayoutTextAlign.start)
          'textAlign': node.textAlign.name,
        'maxLines': ?node.maxLines,
        if (node.ellipsis) 'ellipsis': true,
        if (node.letterSpacing != 0) 'letterSpacing': node.letterSpacing,
        'lineHeight': ?node.lineHeight,
        if (node.italic) 'italic': true,
        if (node.underline) 'underline': true,
        if (node.strikethrough) 'strikethrough': true,
        if (node.textCase != LayoutCase.none) 'textCase': node.textCase.name,
      });
    case LayoutImage():
      json.addAll({
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
        'color': _colorToJson(node.color),
        if (node.indent != 0) 'indent': node.indent,
        if (node.endIndent != 0) 'endIndent': node.endIndent,
      });
    case LayoutProgress():
      json.addAll({
        'circular': node.circular,
        'value': node.value.paramKey != null
            ? {'value': node.value.paramKey}
            : node.value.value,
        'color': _colorToJson(node.color),
        'trackColor': _colorToJson(node.trackColor),
        'size': node.size,
        'thickness': node.thickness,
        if (!node.circular) 'width': _lengthToJson(node.width),
        if (node.barRadius != 0) 'barRadius': node.barRadius,
        if (node.startAngle != 0) 'startAngle': node.startAngle,
      });
  }
  return json;
}

// --- Reading ----------------------------------------------------------------

class _Reader {
  _Reader(this.json, this.path);

  final Map<String, Object?> json;
  final String path;

  Never fail(String message, [String? key]) =>
      throw HomeWidgetJsonException(key == null ? path : '$path.$key', message);

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

  _Reader child(String key) =>
      _Reader(req<Map<String, Object?>>(key), '$path.$key');

  _Reader? optChild(String key) => json[key] == null ? null : child(key);

  List<_Reader> children(String key) {
    final list = opt<List<Object?>>(key) ?? const [];
    return [
      for (var i = 0; i < list.length; i++)
        if (list[i] case final Map<String, Object?> item)
          _Reader(item, '$path.$key[$i]')
        else
          fail('expected an object', '$key[$i]'),
    ];
  }

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

  HomeWidgetApp app() => HomeWidgetApp(
    iosBundleId: req<String>('iosBundleId'),
    iosDeviceFamily: opt<String>('iosDeviceFamily') ?? '1',
    routes: switch (optChild('routes')) {
      final routes? => HomeWidgetRoutes(
        scheme: routes.opt<String>('scheme') ?? '',
        host: routes.opt<String>('host') ?? '',
        encodeTwice: routes.opt<bool>('encodeTwice') ?? true,
      ),
      null => const HomeWidgetRoutes(scheme: ''),
    },
    widgets: [for (final widget in children('widgets')) widget.widget()],
  );

  HomeWidgetDefinition widget() {
    final values = [
      for (final value in children('values'))
        HomeWidgetValue(
          key: value.req<String>('key'),
          name: value.opt<String>('name') ?? value.req<String>('key'),
          type: value.valueType('type'),
          defaultValue: value.opt<String>('default'),
        ),
    ];
    final types = {for (final value in values) value.key: value.type};
    final layoutsJson = child('layouts');
    final layouts = <HomeWidgetSize, HomeWidgetLayoutModel>{};
    for (final size in HomeWidgetSize.values) {
      if (layoutsJson.optChild(size.name) case final layout?) {
        layouts[size] = layout.layout(types);
      }
    }
    for (final key in layoutsJson.json.keys) {
      if (!HomeWidgetSize.values.any((size) => size.name == key)) {
        layoutsJson.fail(
          'unknown size; expected one of '
          '${HomeWidgetSize.values.map((s) => s.name).join(', ')}',
          key,
        );
      }
    }
    return HomeWidgetDefinition(
      key: req<String>('key'),
      name: opt<String>('name') ?? '',
      description: opt<String>('description') ?? '',
      placeholderText: opt<String>('placeholderText') ?? '',
      values: values,
      layouts: layouts,
      refresh: optChild('refresh')?.refresh(),
      configuration: optChild('configuration')?.configuration(),
    );
  }

  HomeWidgetValueType valueType(String key) {
    final id = req<String>(key);
    for (final type in HomeWidgetValueType.values) {
      if (type.id == id) {
        return type;
      }
    }
    fail(
      'expected one of ${HomeWidgetValueType.values.map((t) => t.id).join(', ')}',
      key,
    );
  }

  HomeWidgetRefreshPlan refresh() => HomeWidgetRefreshPlan(
    url: req<String>('url'),
    headers: {
      for (final MapEntry(:key, :value)
          in (opt<Map<String, Object?>>('headers') ?? const {}).entries)
        key: value is String
            ? value
            : fail('expected a string', 'headers.$key'),
    },
    intervalMinutes:
        (opt<num>('intervalMinutes') ?? kHomeWidgetMinRefreshMinutes).toInt(),
    values: [
      for (final value in children('values'))
        FetchedValue(
          value.req<String>('key'),
          value.valueType('type'),
          parseJsonPath(value.req<String>('path')) ??
              value.fail('a widget reads only plain paths: \$.a.b[0]', 'path'),
        ),
    ],
  );

  HomeWidgetConfiguration configuration() => HomeWidgetConfiguration(
    title: opt<String>('title') ?? '',
    appChoices: opt<bool>('appChoices') ?? false,
    choices: [
      for (final choice in children('choices'))
        HomeWidgetChoice(
          id: choice.req<String>('id'),
          name: choice.opt<String>('name') ?? choice.req<String>('id'),
          values: {
            for (final MapEntry(:key, :value)
                in (choice.opt<Map<String, Object?>>('values') ?? const {})
                    .entries)
              key: value is String
                  ? value
                  : choice.fail('expected a string', 'values.$key'),
          },
        ),
    ],
  );

  HomeWidgetLayoutModel layout(Map<String, HomeWidgetValueType> types) =>
      HomeWidgetLayoutModel(
        optChild('root')?.node(types),
        const [],
        tap: optChild('tap')?.tap(),
      );

  LayoutColor color(String key) {
    final value = json[key];
    if (value is String) {
      return LayoutColor.same(_parseHex(value, key));
    }
    if (value is Map<String, Object?>) {
      final colors = child(key);
      return LayoutColor(
        _parseHexOf(colors, 'light'),
        _parseHexOf(colors, 'dark'),
      );
    }
    fail('expected "#AARRGGBB" or {"light", "dark"}', key);
  }

  LayoutColor? optColor(String key) => json[key] == null ? null : color(key);

  int _parseHexOf(_Reader reader, String key) =>
      reader._parseHex(reader.req<String>(key), key);

  int _parseHex(String text, String key) {
    final hex = text.startsWith('#') ? text.substring(1) : text;
    final value = int.tryParse(hex, radix: 16);
    if (value == null || (hex.length != 6 && hex.length != 8)) {
      fail('expected "#AARRGGBB" or "#RRGGBB"', key);
    }
    return hex.length == 6 ? 0xFF000000 | value : value;
  }

  LayoutPaint paint(String key, LayoutPaint fallback) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value case {'value': final String paramKey}) {
      return LayoutPaint.param(paramKey);
    }
    return LayoutPaint.fixed(color(key));
  }

  LayoutLength length(String key, LayoutLength fallback) {
    final value = json[key];
    return switch (value) {
      null => fallback,
      'fill' => const LayoutLength.fill(),
      'fit' => const LayoutLength.fit(),
      num() => LayoutLength.points(value.toDouble()),
      _ => fail('expected a number, "fill" or "fit"', key),
    };
  }

  LayoutAlignment? alignment(String key) {
    final list = opt<List<Object?>>(key);
    if (list == null) {
      return null;
    }
    if (list case [num x, num y]) {
      return LayoutAlignment(x.toDouble(), y.toDouble());
    }
    fail('expected [x, y], each from -1 to 1', key);
  }

  LayoutTap tap() {
    if (opt<String>('openPage') case final path?) {
      return LayoutOpenPage(path, [
        for (final param in children('params'))
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
    if (opt<String>('toggle') case final paramKey?) {
      return LayoutToggle(paramKey);
    }
    if (opt<String>('step') case final paramKey?) {
      return LayoutStep(
        paramKey,
        req<double>('by'),
        min: opt<double>('min'),
        max: opt<double>('max'),
        integer: opt<bool>('integer') ?? false,
      );
    }
    if (opt<bool>('clear') == true) {
      return const LayoutClear();
    }
    fail('expected "openPage", "toggle", "step" or "clear"');
  }

  List<LayoutNode> items(String key, Map<String, HomeWidgetValueType> types) =>
      [for (final item in children(key)) item.node(types)];

  LayoutNode node(Map<String, HomeWidgetValueType> types) {
    final key = req<String>('key');
    final type = req<String>('type');
    final LayoutNode node;
    switch (type) {
      case 'box':
        node = LayoutBox(key)
          ..width = length('width', const LayoutLength.fit())
          ..height = length('height', const LayoutLength.fit())
          ..background = json['background'] == null
              ? null
              : paint(
                  'background',
                  const LayoutPaint.fixed(LayoutColor.same(0)),
                )
          ..radius = opt<double>('radius') ?? 0
          ..borderWidth = opt<double>('borderWidth') ?? 0
          ..borderColor = optColor('borderColor')
          ..childAlignment = alignment('childAlignment')
          ..clip = opt<bool>('clip') ?? false
          ..child = optChild('child')?.node(types);
      case 'row' || 'column':
        node = LayoutFlex(key, horizontal: type == 'row')
          ..mainAxis = enumValue(
            'mainAxis',
            LayoutMainAxis.values,
            LayoutMainAxis.start,
          )
          ..crossAxis = enumValue(
            'crossAxis',
            LayoutCrossAxis.values,
            LayoutCrossAxis.center,
          )
          ..spacing = opt<double>('spacing') ?? 0
          ..startSpacing = opt<double>('startSpacing') ?? 0
          ..endSpacing = opt<double>('endSpacing') ?? 0
          ..shrinkMain = opt<bool>('shrinkMain') ?? false;
        (node as LayoutFlex).items.addAll(items('children', types));
      case 'stack':
        node = LayoutStack(key)
          ..alignment = alignment('alignment') ?? LayoutAlignment.topStart;
        (node as LayoutStack).items.addAll(items('children', types));
      case 'text':
        final LayoutText content;
        if (opt<String>('value') case final paramKey?) {
          content = LayoutParamText(
            paramKey,
            types[paramKey] ??
                fail('no value "$paramKey" in the widget\'s values', 'value'),
          );
        } else {
          content = LayoutStaticText(req<String>('text'));
        }
        final text = LayoutTextNode(key, content)
          ..fontSize = opt<double>('fontSize') ?? 14
          ..fontWeight = opt<num>('fontWeight')?.toInt() ?? 400
          ..textAlign = enumValue(
            'textAlign',
            LayoutTextAlign.values,
            LayoutTextAlign.start,
          )
          ..maxLines = opt<num>('maxLines')?.toInt()
          ..ellipsis = opt<bool>('ellipsis') ?? false
          ..letterSpacing = opt<double>('letterSpacing') ?? 0
          ..lineHeight = opt<double>('lineHeight')
          ..italic = opt<bool>('italic') ?? false
          ..underline = opt<bool>('underline') ?? false
          ..strikethrough = opt<bool>('strikethrough') ?? false
          ..textCase = enumValue(
            'textCase',
            LayoutCase.values,
            LayoutCase.none,
          );
        text.color = paint('color', text.color);
        node = text;
      case 'image':
        node = LayoutImage(key, req<String>('asset'))
          ..width = length('width', const LayoutLength.fit())
          ..height = length('height', const LayoutLength.fit())
          ..fit = enumValue('fit', LayoutFit.values, LayoutFit.contain)
          ..radius = opt<double>('radius') ?? 0;
      case 'icon':
        final codePoint = json['codePoint'];
        final icon = LayoutIcon(key, switch (codePoint) {
          int() => codePoint,
          String()
              when int.tryParse(
                    codePoint.replaceFirst(RegExp('^0x'), ''),
                    radix: 16,
                  ) !=
                  null =>
            int.parse(codePoint.replaceFirst(RegExp('^0x'), ''), radix: 16),
          _ => fail('expected a Material Icons code point', 'codePoint'),
        })..size = opt<double>('size') ?? 24;
        icon.color = paint('color', icon.color);
        node = icon;
      case 'spacer':
        node = LayoutSpacer(key);
      case 'divider':
        final divider = LayoutDivider(key)
          ..space = opt<double>('space') ?? 16
          ..thickness = opt<double>('thickness') ?? 1
          ..indent = opt<double>('indent') ?? 0
          ..endIndent = opt<double>('endIndent') ?? 0;
        divider.color = optColor('color') ?? divider.color;
        node = divider;
      case 'progress':
        final value = json['value'];
        final progress =
            LayoutProgress(
                key,
                circular: opt<bool>('circular') ?? false,
                value: switch (value) {
                  {'value': final String paramKey} => LayoutFraction.param(
                    paramKey,
                  ),
                  num() => LayoutFraction.fixed(value.toDouble()),
                  _ => fail(
                    'expected a number from 0 to 1 or {"value": key}',
                    'value',
                  ),
                },
              )
              ..size = opt<double>('size') ?? 100
              ..thickness = opt<double>('thickness') ?? 5
              ..width = length('width', const LayoutLength.fill())
              ..barRadius = opt<double>('barRadius') ?? 0
              ..startAngle = opt<double>('startAngle') ?? 0;
        progress
          ..color = optColor('color') ?? progress.color
          ..trackColor = optColor('trackColor') ?? progress.trackColor;
        node = progress;
      default:
        fail(
          'unknown node type; expected box, row, column, stack, text, image, '
              'icon, spacer, divider or progress',
          'type',
        );
    }
    if (opt<List<Object?>>('padding') case final padding?) {
      if (padding case [num l, num t, num r, num b]) {
        node.padding = LayoutInsets(
          l.toDouble(),
          t.toDouble(),
          r.toDouble(),
          b.toDouble(),
        );
      } else {
        fail('expected [left, top, right, bottom]', 'padding');
      }
    }
    node
      ..flex = opt<num>('flex')?.toInt()
      ..visibleParam = opt<String>('visibleIf')
      ..tap = optChild('tap')?.tap()
      ..align = alignment('align');
    return node;
  }
}

String _typeName<T>() => switch (T) {
  const (String) => 'a string',
  const (bool) => 'true or false',
  const (double) || const (num) => 'a number',
  const (List<Object?>) => 'a list',
  const (Map<String, Object?>) => 'an object',
  _ => '$T',
};
