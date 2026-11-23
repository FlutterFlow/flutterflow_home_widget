/// Checks a [HomeWidgetApp] before it is generated: what would not compile,
/// would draw differently on the two platforms, or would silently do nothing.
library;

import 'package:flutterflow_home_widget/src/escape.dart';
import 'package:flutterflow_home_widget/src/layout/layout_model.dart';
import 'package:flutterflow_home_widget/src/refresh.dart';
import 'package:flutterflow_home_widget/src/spec.dart';

/// Something wrong with a spec. [path] says where (`widgets[0].layouts.small
/// node "Text_1"`), [message] what, written for the person who wrote it.
class HomeWidgetProblem {
  const HomeWidgetProblem(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Every problem with [app]; empty when it can be generated as it is.
///
/// A [HomeWidgetLayoutModel]'s own `issues` (found by whatever built it) are
/// reported too.
List<HomeWidgetProblem> validateHomeWidgetApp(HomeWidgetApp app) {
  final problems = <HomeWidgetProblem>[];
  void add(String path, String message) =>
      problems.add(HomeWidgetProblem(path, message));

  if (app.iosBundleId.trim().isEmpty) {
    add('iosBundleId', 'is empty. The widget extension is named after it.');
  }
  if (app.widgets.isEmpty) {
    add('widgets', 'is empty.');
  }
  final nativeKeys = <String, String>{};
  for (final (i, widget) in app.widgets.indexed) {
    final at = 'widgets[$i] ("${widget.key}")';
    if (widget.key.isEmpty) {
      add(at, 'has no key.');
    } else if (nativeKeys[widget.nativeKey] case final other?) {
      add(
        at,
        'has the native name of "$other". Keys must differ in their letters, '
        'digits and underscores.',
      );
    } else {
      nativeKeys[widget.nativeKey] = widget.key;
    }
    if (widget.layouts.isEmpty) {
      add(at, 'has no layout. Give it at least one size.');
    }
    final types = <String, HomeWidgetValueType>{};
    for (final value in widget.values) {
      if (types.containsKey(value.key)) {
        add('$at.values', 'has "${value.key}" twice.');
      }
      types[value.key] = value.type;
      if (value.defaultValue case final text?
          when !_isWireValue(value.type, text)) {
        add(
          '$at.values "${value.key}"',
          'has a default that is not a ${value.type.id} ($text).',
        );
      }
    }
    for (final (size, layout) in widget.sizedLayouts) {
      _validateLayout(
        '$at.layouts.${size.name}',
        size,
        layout,
        types,
        app.routes,
        add,
      );
    }
    if (widget.refresh case final refresh?) {
      if (refresh.intervalMinutes < kHomeWidgetMinRefreshMinutes) {
        add(
          '$at.refresh',
          'fetches every ${refresh.intervalMinutes} minutes. Android updates '
              'a widget at most every $kHomeWidgetMinRefreshMinutes.',
        );
      }
      if (Uri.tryParse(refresh.url)?.hasScheme != true) {
        add('$at.refresh', 'has a URL that is not absolute: ${refresh.url}');
      }
      for (final fetched in refresh.values) {
        if (types[fetched.key] case final type? when type != fetched.type) {
          add(
            '$at.refresh "${fetched.key}"',
            'fetches a ${fetched.type.id} into a ${type.id} value.',
          );
        } else if (!types.containsKey(fetched.key)) {
          add('$at.refresh', 'fetches "${fetched.key}", which is not a value.');
        }
      }
    }
    if (widget.configuration case final configuration?) {
      final ids = <String>{};
      for (final choice in configuration.choices) {
        if (!ids.add(choice.id)) {
          add('$at.configuration', 'has the choice "${choice.id}" twice.');
        }
        for (final key in choice.values.keys) {
          if (!types.containsKey(key)) {
            add(
              '$at.configuration "${choice.id}"',
              'sets "$key", which is not a value.',
            );
          }
        }
      }
    }
  }
  return problems;
}

void _validateLayout(
  String at,
  HomeWidgetSize size,
  HomeWidgetLayoutModel layout,
  Map<String, HomeWidgetValueType> types,
  HomeWidgetRoutes routes,
  void Function(String path, String message) add,
) {
  for (final issue in layout.issues) {
    add('$at node "${issue.nodeKey}"', issue.message);
  }
  final root = layout.root;
  if (root == null) {
    add(at, 'has no root node.');
    return;
  }
  // iOS opens one link for the whole widget in the small size and on the
  // Lock Screen: only the widget's own tap may open a page there.
  final elementTaps = size != HomeWidgetSize.small && !size.isLockScreen;
  if (size == HomeWidgetSize.accessoryInline && !_isOneLine(root)) {
    add(
      at,
      'The inline Lock Screen size shows one line: a text, with an icon '
      'before it if you like (in a row). iOS leaves anything else out.',
    );
  }

  void needs(String where, String? key, Set<HomeWidgetValueType> allowed) {
    if (key == null) {
      return;
    }
    final type = types[key];
    if (type == null) {
      add(where, 'reads "$key", which is not one of the widget\'s values.');
    } else if (!allowed.contains(type)) {
      add(
        where,
        'reads "$key" as ${allowed.map((t) => t.id).join(' or ')}, but it is '
        'a ${type.id}.',
      );
    }
  }

  void checkTap(String where, LayoutTap tap, {required bool element}) {
    switch (tap) {
      case LayoutOpenPage(:final path, :final params):
        if (element && !elementTaps) {
          add(
            where,
            'opens a page, but in the ${size.label.toLowerCase()} size iOS '
            'opens one page for the whole widget. Set the tap on the layout.',
          );
        }
        if (routes.scheme.isEmpty) {
          add(where, 'opens a page, but the app has no route scheme.');
        }
        if (!path.startsWith('/')) {
          add(where, 'opens "$path", which does not start with "/".');
        }
        for (final param in params) {
          needs('$where param "${param.name}"', param.paramKey, {
            ...HomeWidgetValueType.values,
          });
        }
      case LayoutToggle(:final paramKey):
        needs(where, paramKey, {HomeWidgetValueType.boolean});
      case LayoutStep(:final paramKey, :final step, :final min, :final max):
        needs(where, paramKey, {
          HomeWidgetValueType.integer,
          HomeWidgetValueType.double,
        });
        if (step == 0) {
          add(where, 'changes "$paramKey" by 0.');
        }
        if (min != null && max != null && min > max) {
          add(where, 'has a lowest value above its highest.');
        }
      case LayoutClear():
        break;
    }
  }

  if (layout.tap case final tap?) {
    checkTap('$at.tap', tap, element: false);
  }
  final keys = <String>{};
  for (final node in root.all) {
    final where = '$at node "${node.nodeKey}"';
    if (!keys.add(node.nodeKey)) {
      add(where, 'has the key of another node in the layout.');
    } else if (identifierPart(node.nodeKey).isEmpty) {
      add(where, 'needs a key with letters or digits.');
    }
    needs('$where visibleIf', node.visibleParam, {HomeWidgetValueType.boolean});
    if (node.tap case final tap?) {
      checkTap('$where tap', tap, element: true);
    }
    switch (node) {
      case LayoutTextNode(:final content, :final color):
        if (content case LayoutParamText(:final paramKey)) {
          needs(where, paramKey, {...HomeWidgetValueType.values});
        }
        needs('$where color', color.paramKey, {HomeWidgetValueType.color});
      case LayoutIcon(:final color):
        needs('$where color', color.paramKey, {HomeWidgetValueType.color});
      case LayoutBox(:final background):
        needs('$where background', background?.paramKey, {
          HomeWidgetValueType.color,
        });
      case LayoutProgress(:final value):
        needs(where, value.paramKey, {
          HomeWidgetValueType.integer,
          HomeWidgetValueType.double,
        });
        if (value.value case final fixed? when fixed < 0 || fixed > 1) {
          add(where, 'shows $fixed, outside 0 to 1.');
        }
      case LayoutImage(:final assetPath):
        if (!assetPath.startsWith('assets/')) {
          add(
            where,
            'shows "$assetPath". Use the Flutter asset path the app bundles '
            'the image under (assets/…).',
          );
        }
      default:
        break;
    }
  }
}

/// Whether [root] is what an inline Lock Screen widget can show: at most one
/// text and one icon, in boxes and rows.
bool _isOneLine(LayoutNode root) {
  var texts = 0;
  var icons = 0;
  for (final node in root.all) {
    switch (node) {
      case LayoutTextNode():
        texts++;
      case LayoutIcon():
        icons++;
      case LayoutBox():
        break;
      case LayoutFlex(:final horizontal) when horizontal:
        break;
      default:
        return false;
    }
  }
  return texts <= 1 && icons <= 1;
}

/// Whether [text] is a wire string of [type] (see [HomeWidgetValueType]).
bool _isWireValue(HomeWidgetValueType type, String text) => switch (type) {
  HomeWidgetValueType.string => true,
  HomeWidgetValueType.integer => int.tryParse(text) != null,
  HomeWidgetValueType.double => double.tryParse(text) != null,
  HomeWidgetValueType.boolean => text == 'true' || text == 'false',
  HomeWidgetValueType.dateTime => int.tryParse(text) != null,
  HomeWidgetValueType.color => RegExp(r'^#[0-9A-Fa-f]{8}$').hasMatch(text),
};
