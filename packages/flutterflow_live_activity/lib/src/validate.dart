/// Checks a [LiveActivityApp] before it is generated: what would not
/// compile, would draw differently on the two platforms, would not fit the
/// surface, or would silently do nothing.
library;

import 'package:flutterflow_live_activity/src/android/custom_card_templates.dart';
import 'package:flutterflow_live_activity/src/card_height.dart';
import 'package:flutterflow_live_activity/src/dart/typed_api.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

/// Something wrong with a spec. [path] says where (`activities[0]
/// ("delivery").surfaces.lockScreen node "title"`), [message] what, written
/// for the person who wrote it.
///
/// A [warning] does not stop generation: the card works, but not as the
/// spec may mean it to (a part Android leaves out, a card that may be cut
/// off).
class LiveActivityProblem {
  const LiveActivityProblem(this.path, this.message, {this.warning = false});

  final String path;
  final String message;
  final bool warning;

  @override
  String toString() => '${warning ? 'warning: ' : ''}$path: $message';
}

/// Every problem with [app], warnings included; generation should stop
/// when one is not a warning.
///
/// A layout's own `issues` (found by whatever built it) are reported too.
List<LiveActivityProblem> validateLiveActivityApp(LiveActivityApp app) {
  final problems = <LiveActivityProblem>[];
  void add(String path, String message, {bool warning = false}) =>
      problems.add(LiveActivityProblem(path, message, warning: warning));

  if (app.specVersion != kLiveActivitySpecVersion) {
    add(
      'specVersion',
      'is ${app.specVersion}; this package generates version '
          '$kLiveActivitySpecVersion.',
    );
  }
  if (app.iosBundleId.trim().isEmpty) {
    add(
      'iosBundleId',
      'is empty. The Live Activity extension is named after it.',
    );
  }
  if (app.activities.isEmpty) {
    add('activities', 'is empty.');
  }
  final nativeKeys = <String, String>{};
  final classNames = liveActivityDartClassNames(app);
  final classes = <String, String>{};
  for (final (i, activity) in app.activities.indexed) {
    final at = 'activities[$i] ("${activity.key}")';
    if (activity.key.isEmpty) {
      add(at, 'has no key.');
    } else if (nativeKeys[activity.nativeKey] case final other?) {
      add(
        at,
        'has the native name of "$other". Keys must differ in their letters, '
        'digits and underscores.',
      );
    } else {
      nativeKeys[activity.nativeKey] = activity.key;
    }
    final className = liveActivityDartClassName(activity.key);
    if (classes[className] case final other?) {
      add(
        at,
        'has the Dart class name of "$other", so it is '
        '${classNames[activity.key]} in the typed API.',
        warning: true,
      );
    } else {
      classes[className] = activity.key;
    }
    if (activity.accentColor case final color?
        when !RegExp(r'^#[0-9A-Fa-f]{8}$').hasMatch(color)) {
      add('$at.accentColor', 'is "$color", not #AARRGGBB.');
    }
    if (activity.icon case final icon? when !_isAsset(icon)) {
      add('$at.icon', _notAsset(icon));
    }
    if (activity.isCustom) {
      _validateCustomCard(at, activity, app.routes, add);
    } else {
      for (final (field, set) in [
        ('values', activity.values.isNotEmpty),
        ('surfaces', activity.surfaces.isNotEmpty),
        (
          'android',
          activity.android.presentation !=
                  LiveActivityAndroidPresentation.standard ||
              activity.android.slots.isNotEmpty,
        ),
        ('androidDefaults', activity.androidDefaults != null),
      ]) {
        if (set) {
          add(
            '$at.$field',
            'is set, but the ${activity.template.wireName} template has its '
                'own values and views. Only a custom card uses it.',
          );
        }
      }
    }
  }
  return problems;
}

typedef _Add = void Function(String path, String message, {bool warning});

void _validateCustomCard(
  String at,
  LiveActivityDefinition card,
  LiveActivityRoutes routes,
  _Add add,
) {
  // --- Values ---------------------------------------------------------------
  if (card.values.length > kLiveActivityMaxValues) {
    add(
      '$at.values',
      'has ${card.values.length} values. A card holds at most '
          '$kLiveActivityMaxValues.',
    );
  }
  if (card.imageValues.length > kLiveActivityMaxImageValues) {
    add(
      '$at.values',
      'has ${card.imageValues.length} image values. A card holds at most '
          '$kLiveActivityMaxImageValues.',
    );
  }
  final types = <String, LiveActivityValueType>{};
  final dartNames = <String, String>{};
  final names = liveActivityDartValueNames(card);
  for (final value in card.values) {
    final where = '$at.values "${value.key}"';
    if (value.key.isEmpty) {
      add('$at.values', 'has a value with no key.');
    } else if (types.containsKey(value.key)) {
      add('$at.values', 'has "${value.key}" twice.');
    }
    types[value.key] = value.type;
    final dartName = liveActivityDartValueName(value.key);
    if (dartNames[dartName] case final other? when other != value.key) {
      add(
        where,
        'has the Dart name of "$other", so it is ${names[value.key]} in the '
        'typed API.',
        warning: true,
      );
    } else {
      dartNames[dartName] = value.key;
    }
    if (value.defaultValue case final text?) {
      if (value.type == LiveActivityValueType.image) {
        if (!_isAsset(text)) {
          add(
            where,
            'has a default that is not an asset of the app: $text. The card '
            'shows it until the app sends a picture, so the app must bundle '
            'it (assets/…).',
          );
        }
      } else if (!_isWireValue(value.type, text)) {
        add(where, 'has a default that is not a ${value.type.name} ($text).');
      }
    }
  }

  // --- Surfaces -------------------------------------------------------------
  for (final surface in const [
    LiveActivitySurface.lockScreen,
    LiveActivitySurface.islandExpanded,
  ]) {
    if (!card.surfaces.containsKey(surface)) {
      add(
        '$at.surfaces',
        'has no ${surface.name} layout. iOS cannot show the card without it.',
      );
    }
  }
  for (final (surface, layout) in card.layouts) {
    _validateLayout(
      '$at.surfaces.${surface.name}',
      surface,
      layout,
      types,
      routes,
      add,
    );
  }

  // --- Android --------------------------------------------------------------
  for (final MapEntry(key: slot, value: key) in card.android.slots.entries) {
    final where = '$at.android.slots.${slot.name}';
    final type = types[key];
    if (type == null) {
      add(where, 'shows "$key", which is not one of the card\'s values.');
    } else if (type != slot.valueType) {
      add(
        where,
        'shows "$key", a ${type.name}; this part shows a '
        '${slot.valueType.name}.',
      );
    }
  }
  for (final key in card.androidDefaults?.keys ?? const <String>[]) {
    if (!types.containsKey(key)) {
      add(
        '$at.androidDefaults',
        'has a default for "$key", which is not one of the card\'s values.',
      );
    }
  }
  if (card.android.presentation == LiveActivityAndroidPresentation.custom) {
    if (liveActivityAndroidTapDroppingDrawing(card) case final nodeKey?) {
      add(
        '$at.android',
        'draws the Lock Screen layout, but its node "$nodeKey" (or the '
            'layout) opens a page on tap. A drawn Live Update cannot be '
            'tapped, so Android shows the standard one instead.',
        warning: true,
      );
    }
  } else if (card.surfaces[LiveActivitySurface.lockScreen] case final lock?) {
    final unshown = _androidStandardUnshown(card, lock);
    if (unshown != null) {
      add('$at.android', unshown, warning: true);
    }
  }
}

/// What the standard Android Live Update leaves out of [card]: it has
/// places for a title, a text, a bar, a countdown and one picture. Null
/// when it shows everything.
String? _androidStandardUnshown(
  LiveActivityDefinition card,
  NativeLayoutModel lock,
) {
  final shown = {for (final value in card.androidSlotValues.values) value.key};
  final timed = liveActivityAndroidStandardTimed(card);
  shown.addAll([
    if (timed.timedStart case final start?) start,
    if (timed.timedEnd case final end?) end,
  ]);
  final bars = lock.stageBars.toList();
  // The first Stages bar is drawn, with the values it reads.
  if (bars.firstOrNull?.stages case final stages?) {
    shown.addAll(stages.paramKeys);
  }
  final unshown = [
    for (final value in card.values)
      if (!shown.contains(value.key) &&
          // A Boolean or a Color only steers how something else draws.
          value.type != LiveActivityValueType.boolean &&
          value.type != LiveActivityValueType.color)
        '"${value.key}"',
  ];
  final stageExtras = bars.any(
    (bar) => bar.stages!.showLabels || bar.stages!.hasStageIcons,
  );
  if (unshown.isEmpty && !stageExtras) {
    return null;
  }
  return 'uses the standard Live Update, which has places for a title, a '
      'text, a bar, a countdown and one picture.'
      '${unshown.isEmpty ? '' : ' It does not show ${unshown.join(', ')}.'}'
      '${stageExtras ? ' Stage labels and icons are not drawn.' : ''}'
      ' Name the values its parts show (android.slots), or draw the card '
      '(android.presentation: custom).';
}

void _validateLayout(
  String at,
  LiveActivitySurface surface,
  NativeLayoutModel layout,
  Map<String, LiveActivityValueType> types,
  LiveActivityRoutes routes,
  _Add add,
) {
  for (final issue in layout.issues) {
    add('$at node "${issue.nodeKey}"', issue.message);
  }
  final root = layout.root;
  if (root == null) {
    add(at, 'has no root node.');
    return;
  }
  final count = root.all.length;
  if (count > kLiveActivityMaxLayoutNodes) {
    add(
      at,
      'has $count nodes. A card layout holds at most '
      '$kLiveActivityMaxLayoutNodes.',
    );
  }

  void needs(String where, String? key, Set<LiveActivityValueType> allowed) {
    if (key == null) {
      return;
    }
    final type = types[key];
    if (type == null) {
      add(where, 'reads "$key", which is not one of the card\'s values.');
    } else if (!allowed.contains(type)) {
      add(
        where,
        'reads "$key" as ${allowed.map((t) => t.name).join(' or ')}, but it '
        'is a ${type.name}.',
      );
    }
  }

  const shownAsText = {
    LiveActivityValueType.string,
    LiveActivityValueType.integer,
    LiveActivityValueType.double,
    LiveActivityValueType.boolean,
    LiveActivityValueType.dateTime,
    LiveActivityValueType.color,
  };

  void checkTap(String where, LayoutTap tap) {
    switch (tap) {
      case LayoutOpenPage(:final path, :final params):
        if (routes.scheme.isEmpty) {
          add(where, 'opens a page, but the app has no route scheme.');
        }
        if (!path.startsWith('/')) {
          add(where, 'opens "$path", which does not start with "/".');
        }
        for (final param in params) {
          needs('$where param "${param.name}"', param.paramKey, shownAsText);
        }
      case LayoutButton():
        add(
          where,
          'is a button. A card has no buttons: a tap can only open a page.',
        );
    }
  }

  if (layout.tap case final tap?) {
    checkTap('$at.tap', tap);
  }
  final keys = <String>{};
  for (final node in root.all) {
    final where = '$at node "${node.nodeKey}"';
    if (!keys.add(node.nodeKey)) {
      add(where, 'has the key of another node in the layout.');
    } else if (identifierPart(node.nodeKey).isEmpty) {
      add(where, 'needs a key with letters or digits.');
    }
    needs('$where visibleIf', node.visibleParam, {
      LiveActivityValueType.boolean,
    });
    if (node.tap case final tap?) {
      checkTap('$where tap', tap);
    }
    switch (node) {
      case LayoutTextNode(:final content, :final color):
        if (content case LayoutParamText(:final paramKey, :final countUp)) {
          needs(
            where,
            paramKey,
            countUp ? {LiveActivityValueType.dateTime} : shownAsText,
          );
        }
        needs('$where color', color.paramKey, {LiveActivityValueType.color});
      case LayoutIcon(:final color):
        needs('$where color', color.paramKey, {LiveActivityValueType.color});
      case LayoutBox(:final background):
        needs('$where background', background?.paramKey, {
          LiveActivityValueType.color,
        });
      case LayoutImage(:final assetPath, :final paramKey):
        needs(where, paramKey, {LiveActivityValueType.image});
        if ((paramKey == null || assetPath.isNotEmpty) &&
            !_isAsset(assetPath)) {
          add(where, _notAsset(assetPath));
        }
      case LayoutProgress(:final value, :final stages):
        needs(where, value.paramKey, {
          LiveActivityValueType.integer,
          LiveActivityValueType.double,
        });
        if (value.value case final fixed? when fixed < 0 || fixed > 1) {
          add(where, 'shows $fixed, outside 0 to 1.');
        }
        if ((node.timedStart == null) != (node.timedEnd == null)) {
          add(where, 'fills between two dates: set both, start and end.');
        }
        needs('$where timed start', node.timedStart, {
          LiveActivityValueType.dateTime,
        });
        needs('$where timed end', node.timedEnd, {
          LiveActivityValueType.dateTime,
        });
        if (stages != null) {
          _validateStages(where, node, stages, needs, add);
        }
      default:
        break;
    }
  }

  // Whether the card fits the surface: iOS cuts off what is below.
  final cap = _points(surface.height);
  if (root case LayoutBox(height: LayoutLength(:final points?))) {
    if (points > surface.height) {
      add(
        at,
        'is ${_points(points)} points tall. iOS shows $cap: what is below '
        'that is cut off.',
      );
    }
    return;
  }
  final height = liveActivityCardHeight(root);
  if (height == null) {
    return;
  }
  if (height.atLeast > surface.height) {
    add(
      at,
      'needs at least ${_points(height.atLeast.ceilToDouble())} points of '
      'height. iOS shows $cap: what is below that is cut off.',
    );
  } else if (height.likely > surface.height) {
    add(
      at,
      'is about ${_points(height.likely.ceilToDouble())} points tall with '
      'everything in it shown. iOS shows $cap: what is below that is cut '
      'off.',
      warning: true,
    );
  }
}

void _validateStages(
  String where,
  LayoutProgress bar,
  LayoutStages stages,
  void Function(String where, String? key, Set<LiveActivityValueType> allowed)
  needs,
  _Add add,
) {
  if (bar.circular) {
    add(where, 'is a ring. Only a linear bar can be drawn as stages.');
  }
  final count = stages.stages.length;
  if (count < kLiveActivityMinStages || count > kLiveActivityMaxStages) {
    add(
      where,
      'has $count stages. A bar has $kLiveActivityMinStages to '
      '$kLiveActivityMaxStages.',
    );
  }
  needs('$where current stage', stages.currentParamKey, {
    LiveActivityValueType.integer,
  });
  needs('$where progress in the stage', stages.progressParamKey, {
    LiveActivityValueType.double,
  });
  final unnamed = <int>[];
  final stageKeys = <String>{};
  for (final (i, stage) in stages.stages.indexed) {
    if (!stageKeys.add(stage.key)) {
      add(where, 'has the stage "${stage.key}" twice.');
    }
    switch (stage.label) {
      case LayoutParamText(:final paramKey):
        needs('$where stage "${stage.key}" label', paramKey, {
          LiveActivityValueType.string,
        });
      case LayoutStaticText(:final text) when text.trim().isEmpty:
        unnamed.add(i + 1);
      case LayoutStaticText():
        break;
    }
  }
  if (stages.showLabels && unnamed.isNotEmpty) {
    add(
      where,
      '${unnamed.length == 1 ? 'Stage' : 'Stages'} ${unnamed.join(', ')} '
      '${unnamed.length == 1 ? 'has' : 'have'} no label. Name '
      '${unnamed.length == 1 ? 'it' : 'them'}, or hide the labels.',
      warning: true,
    );
  }
}

bool _isAsset(String path) => path.startsWith('assets/');

String _notAsset(String path) =>
    'shows "$path". Use the Flutter asset path the app bundles the image '
    'under (assets/…).';

String _points(double value) =>
    value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();

/// Whether [text] is a wire string of [type] (see [LiveActivityValueType]).
bool _isWireValue(LiveActivityValueType type, String text) => switch (type) {
  LiveActivityValueType.string => true,
  LiveActivityValueType.integer => int.tryParse(text) != null,
  LiveActivityValueType.double => double.tryParse(text) != null,
  LiveActivityValueType.boolean => text == 'true' || text == 'false',
  LiveActivityValueType.dateTime => int.tryParse(text) != null,
  LiveActivityValueType.color => RegExp(r'^#[0-9A-Fa-f]{8}$').hasMatch(text),
  LiveActivityValueType.image => true,
};
