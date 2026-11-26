/// The iOS views of the Live Activities whose template is Custom.
///
/// A Custom card is designed as one layout per surface. Each layout is
/// written as a SwiftUI view by the shared emitter (`flutterflow_native_layout`),
/// into one more Swift file of the widget extension. The fixed templates keep
/// their hand-written views: an app without a Custom card generates none of
/// this.
library;

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/ios/image_store.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

const _target = kLiveActivityIosExtensionTarget;
const _attributes = kLiveActivityAttributesType;

typedef _Surface = LiveActivitySurface;

/// The size iOS gives a compact side of the Dynamic Island and its minimal
/// form, in points: the canvas a layout for it is designed on.
const _kCompactWidth = 52;
const _kCompactHeight = 36;
const _kMinimalSide = 36;

/// Swift struct of the view the emitter writes for a card's surface.
String liveActivityCardViewName(
  LiveActivityDefinition definition,
  LiveActivitySurface surface,
) => 'FFCard_${definition.nativeKey}_${surface.swiftName}';

String _swiftMap(Map<String, String> map, String indent) =>
    map.isEmpty
        ? '[:]'
        : '[\n${map.entries.map((e) => '$indent  ${swiftString(e.key)}: ${swiftString(e.value)},').join('\n')}\n$indent]';

/// The `LiveActivityCards.swift` of [app]: what the emitted views are built
/// from, each Custom card's views, and the views that pick a card's surface
/// by its definition key. Only called when the app has a Custom card.
String liveActivityCardsSwift(LiveActivityApp app) {
  final cards = app.customCards;
  final images = liveActivityImageTargets(app);
  final views = StringBuffer();
  final lockScreen = <String>[];
  final expanded = <String>[];
  final compactLeading = <String>[];
  final compactTrailing = <String>[];
  final minimal = <String>[];

  for (final card in cards) {
    final key = swiftString(card.key);
    String name(_Surface surface) => liveActivityCardViewName(card, surface);
    void emit(
      _Surface surface,
      NativeLayoutModel model, {
      bool fitHeight = true,
    }) => views.write(
      swiftLayoutView(
        name(surface),
        model,
        widgetKey: card.key,
        rootMode:
            fitHeight
                ? const LayoutRootMode(fitHeight: true, background: false)
                : LayoutRootMode.widget,
      ),
    );

    // The view of a surface, with the card's values and, when its layout
    // shows an Image value, the card's pictures.
    String init(_Surface surface, NativeLayoutModel model) =>
        swiftLayoutViewInit(
          name(surface),
          model,
          values: 'card.values',
          images: 'card.images',
        );

    views.writeln(
      '\n// MARK: - ${escapeEach(card.name, const {'\n': ' ', '\r': ' '})}',
    );

    // Lock Screen (also the banner on a phone without a Dynamic Island).
    // The top widget's fixed fill is the card's background, so it reaches
    // the card's rounded corners.
    final lock = card.surfaces[_Surface.lockScreen];
    var lockView = 'EmptyView()';
    if (lock != null) {
      emit(_Surface.lockScreen, lock);
      lockView = init(_Surface.lockScreen, lock);
      if (lock.root case LayoutBox(background: LayoutPaint(:final color?))) {
        lockView += '\n          .activityBackgroundTint(${swiftColor(color)})';
      }
    }
    lockScreen.add('      case $key:\n        $lockView');

    // Expanded island. The island is black, so the top widget's fill is
    // not drawn.
    final model = card.surfaces[_Surface.islandExpanded];
    var expandedView = 'EmptyView()';
    if (model != null) {
      // The fill is dropped from this model itself, so a model shared with
      // another surface would lose its fill there too.
      for (final MapEntry(key: surface, value: other)
          in card.surfaces.entries) {
        if (surface != _Surface.islandExpanded && identical(other, model)) {
          throw ArgumentError.value(
            card.key,
            'surfaces',
            'The ${_Surface.islandExpanded.name} layout is the same object '
                'as the ${surface.name} layout; give it a copy of its own',
          );
        }
      }
      if (model.root case final LayoutBox box) {
        box.background = null;
        // Its stage labels are now over the island, not that fill.
        fitStageLabelColors(model, behind: const LayoutColor.same(0xFF000000));
      }
      emit(_Surface.islandExpanded, model);
      expandedView = init(_Surface.islandExpanded, model);
    }
    expanded.add('      case $key:\n        $expandedView');

    // Compact and minimal: the designed layout in the size iOS gives it,
    // else what the card's values and icon give.
    String designed(_Surface surface, int width, int height, String alignment) {
      emit(surface, card.surfaces[surface]!, fitHeight: false);
      return '${init(surface, card.surfaces[surface]!)}\n'
          '          .frame(width: $width, height: $height, alignment: $alignment)';
    }

    compactLeading.add(
      '      case $key:\n        '
      '${card.surfaces.containsKey(_Surface.islandCompactLeading) ? designed(_Surface.islandCompactLeading, _kCompactWidth, _kCompactHeight, '.leading') : _kDerivedIcon}',
    );
    compactTrailing.add(
      '      case $key:\n        '
      '${card.surfaces.containsKey(_Surface.islandCompactTrailing) ? designed(_Surface.islandCompactTrailing, _kCompactWidth, _kCompactHeight, '.trailing') : _derivedTrailing(card)}',
    );
    minimal.add(
      '      case $key:\n        '
      '${card.surfaces.containsKey(_Surface.islandMinimal) ? designed(_Surface.islandMinimal, _kMinimalSide, _kMinimalSide, '.center') : 'FFIconView(card: card.fixed, size: 18)'}',
    );
  }

  // The island is black in light mode too, so its views are always drawn in
  // the dark colour scheme; the Lock Screen follows the phone.
  String picker(
    String type,
    String doc,
    List<String> cases, {
    bool island = true,
  }) => '''

$doc
struct $type: View {
  let card: FFCustomCard

  var body: some View {
    Group {
      switch card.key {
${cases.join('\n')}
      default:
        EmptyView()
      }
    }
    // Countdowns and timed bars start from the moment the card is drawn.
    .environment(\\.ffNow, Date())${island ? '\n    .environment(\\.colorScheme, .dark)' : ''}
  }
}
''';

  final timed = cards.any(
    (card) => card.anyNode(
      (node) => switch (node) {
        LayoutTextNode(content: LayoutParamText(isCountUp: true)) => true,
        LayoutProgress(isTimed: true) => true,
        _ => false,
      },
    ),
  );

  // With an Image value, a card carries the pictures the app stored for
  // them: a value holds its picture's name.
  final imagesProperty =
      images.isEmpty
          ? ''
          : '''
  /// The picture of each Image value that has one, by value key. A value
  /// without a picture draws its fallback.
  let images: [String: UIImage]
''';
  final imagesInit =
      images.isEmpty
          ? ''
          : '''
    var pictures: [String: UIImage] = [:]
    for value in kFFCardImageValues[key] ?? [] {
      pictures[value] = FFLiveActivityImages.image(named: state.values[value] ?? "")
    }
    images = pictures
''';
  final imageKeys =
      images.isEmpty
          ? ''
          : '''

/// The Image values of each card, by definition key.
let kFFCardImageValues: [String: [String]] = [
${images.entries.map((card) => '  ${swiftString(card.key)}: [${card.value.keys.map(swiftString).join(', ')}],').join('\n')}
]
''';
  final valueImages = cards.any(
    (card) =>
        card.anyNode((node) => node is LayoutImage && node.paramKey != null),
  );
  final stages = cards.any(
    (card) =>
        card.anyNode((node) => node is LayoutProgress && node.stages != null),
  );

  return '''
// Generated by FlutterFlow.
//
// The Live Activities designed as Custom cards: one SwiftUI view per card
// and surface, written from the card's layouts.
import ActivityKit
import CoreText
${images.isEmpty ? '' : 'import Security\n'}import SwiftUI
import UIKit
import WidgetKit

// The app's deep link, which a tap on a card opens a page with.
let kFFRouteScheme = ${swiftString(app.routes.scheme)}
let kFFRouteHost = ${swiftString(app.routes.host)}
// Whether a route value is percent-encoded twice: the app's router decodes
// a link once before it reads the values, unless the link service delivers
// the link itself.
let kFFRouteEncodeTwice = ${app.routes.encodeTwice}

$kNativeLayoutSwiftPageUrl
$kNativeLayoutSwiftValues
$kNativeLayoutSwiftColor
$kNativeLayoutSwiftNow
${nativeLayoutSwiftBuildingBlocks(_target)}${timed ? '\n$kNativeLayoutSwiftTimed' : ''}${valueImages ? '\n$kNativeLayoutSwiftValueImage' : ''}${stages ? '\n$kNativeLayoutSwiftStages' : ''}${images.isEmpty ? '' : '\n$kLiveActivityExtensionImageStoreSwift'}
// MARK: - Cards

/// The default of each card's values, by definition key: what a value shows
/// when the app did not send it.
let kFFCardDefaults: [String: [String: String]] = [
${cards.map((card) => '  ${swiftString(card.key)}: ${_swiftMap(card.iosDefaults, '  ')},').join('\n')}
]
$imageKeys
/// A running card whose template is Custom: its definition key picks the
/// views, its values fill them. nil for a fixed template, and for a card this
/// version of the app does not know.
struct FFCustomCard {
  let key: String
  let values: FFValues
$imagesProperty  /// The card's accent colour and icon, as the fixed templates read them.
  let fixed: FFCard

  init?(_ attributes: $_attributes, _ state: $_attributes.ContentState) {
    guard attributes.template == "$kLiveActivityCustomTemplateName",
      let defaults = kFFCardDefaults[attributes.definitionKey]
    else { return nil }
    key = attributes.definitionKey
    values = FFValues(raw: state.values, defaults: defaults)
$imagesInit    fixed = FFCard(attributes, state)
  }
}
${picker('FFCustomLockScreen', '/// The Lock Screen card, and the banner on devices without a Dynamic Island.', lockScreen, island: false)}${picker('FFCustomExpanded', '/// The expanded Dynamic Island, under the sensor row.', expanded)}${picker('FFCustomCompactLeading', '/// The compact island, left of the sensors.', compactLeading)}${picker('FFCustomCompactTrailing', '/// The compact island, right of the sensors.', compactTrailing)}${picker('FFCustomMinimal', '/// The minimal island, when two apps share it.', minimal)}
/// The time left until [end], for a compact island that has no layout of
/// its own. The system redraws it every second.
struct FFCustomCountdown: View {
  let end: Date?

  var body: some View {
    if let end = end {
      Text(timerInterval: min(Date(), end)...end, countsDown: true)
        .monospacedDigit()
        .lineLimit(1)
    } else {
      Text("--:--")
        .monospacedDigit()
    }
  }
}
$views''';
}

/// The compact leading side of a card without a layout for it: the card's
/// icon.
const _kDerivedIcon =
    'FFIconView(card: card.fixed, size: 18)\n'
    '          .ffCompactFit(width: 22, alignment: .leading)';

/// The compact trailing side of a card without a layout for it: a countdown
/// to its first date value, else a ring of its first Double value, else
/// nothing.
String _derivedTrailing(LiveActivityDefinition definition) {
  final date =
      definition.valuesOfType(LiveActivityValueType.dateTime).firstOrNull;
  if (date != null) {
    return 'FFCustomCountdown(end: card.values.date(${swiftString(date.key)}))\n'
        '          .font(.caption2)\n'
        '          .foregroundStyle(card.fixed.accent)\n'
        '          .multilineTextAlignment(.trailing)\n'
        '          .ffCompactFit(width: 44, alignment: .trailing)';
  }
  final fraction =
      definition.valuesOfType(LiveActivityValueType.double).firstOrNull;
  if (fraction != null) {
    return 'FFRingProgress(\n'
        '          value: card.values.double(${swiftString(fraction.key)}),\n'
        '          color: card.fixed.accent, track: card.fixed.accent.opacity(0.3),\n'
        '          diameter: 18, thickness: 3\n'
        '        )\n'
        '          .ffCompactFit(width: 22, alignment: .trailing)';
  }
  return 'EmptyView()';
}

/// The Live Activity widget of an app with Custom cards: a Custom card draws
/// its own views, any other card the fixed templates'. Replaces the widget
/// of an app without Custom cards in the extension's bundle file.
const liveActivityCustomWidgetSwift = '''
/// The app's Live Activity. A card whose template is Custom draws the views
/// written from its layouts (${_target}Cards.swift); for any other the start
/// call's template picks the layout.
struct FFLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: $_attributes.self) { context in
      // Lock screen, and the banner on devices without a Dynamic Island.
      if let custom = FFCustomCard(context.attributes, context.state) {
        FFCustomLockScreen(card: custom)
      } else {
        FFLockScreenView(card: FFCard(context.attributes, context.state))
          .padding(16)
          .activityBackgroundTint(Color.black.opacity(0.75))
          .activitySystemActionForegroundColor(.white)
      }
    } dynamicIsland: { context in
      let card = FFCard(context.attributes, context.state)
      let custom = FFCustomCard(context.attributes, context.state)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          if custom == nil {
            FFExpandedLeading(card: card)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          if custom == nil {
            FFExpandedTrailing(card: card)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          // A Custom card is one layout: it takes the whole width under the
          // sensors.
          if let custom = custom {
            FFCustomExpanded(card: custom)
          } else {
            FFExpandedBottom(card: card)
          }
        }
      } compactLeading: {
        if let custom = custom {
          FFCustomCompactLeading(card: custom)
        } else {
          FFCompactLeading(card: card)
        }
      } compactTrailing: {
        if let custom = custom {
          FFCustomCompactTrailing(card: custom)
        } else {
          FFCompactTrailing(card: card)
        }
      } minimal: {
        if let custom = custom {
          FFCustomMinimal(card: custom)
        } else {
          FFMinimal(card: card)
        }
      }
      .keylineTint(card.accent)
    }
  }
}
''';
