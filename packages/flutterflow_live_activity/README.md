# flutterflow_live_activity

Live Activities for a Flutter app, generated from one spec:

- **iOS**: an ActivityKit widget extension (Lock Screen and Dynamic Island)
  drawn in SwiftUI, and the Xcode project text that adds it as a target.
- **Android**: Live Updates (a promoted ongoing notification on Android 16+,
  an ordinary ongoing notification below that): the system's standard
  layout filled from the card's values, or the card's own layout drawn with
  RemoteViews.
- **Dart**: the `ff_live_activity` plugin the app starts, updates and ends
  them with (`FFLiveActivity.start`, `update`, `end`).

An activity uses one of four fixed templates (progress, ETA timer, score,
queue status), or is a Custom card with its own values and one layout per
surface. Custom cards are drawn from the layout model of
`flutterflow_native_layout` (`../flutterflow_native_layout`), the same model
home screen widgets are drawn from.

FlutterFlow generates its apps' Live Activities with this package.

## Quick start

```sh
dart pub global activate --source git https://github.com/FlutterFlow/flutterflow_home_widget.git --git-path packages/flutterflow_live_activity
flutter create --org com.example my_app
flutterflow_live_activity validate live_activities.json
flutterflow_live_activity apply live_activities.json my_app
```

`apply` writes the plugin under `packages/ff_live_activity/` (with the
typed API, below) and the widget extension under `ios/LiveActivity/`, adds
the plugin to `pubspec.yaml`, adds the extension target to
`ios/Runner.xcodeproj` (signed with the Runner's development team), and adds
`NSSupportsLiveActivities` to the Runner's `Info.plist`. When a Custom card
has an Image value it also adds the shared keychain group to `Info.plist`
and `Runner.entitlements`. Android needs nothing more: the plugin's
manifest is merged into the app's.

Running `apply` again only rewrites what changed. It works everything out
before writing, so a project it cannot change (no `pubspec.yaml`, an Xcode
project that is not a `flutter create` one, or a `LiveActivity` target added
for a spec that has since gained or lost its Custom cards or Image values)
is left as it was; remove the old target in Xcode first in the last case.
`generate` writes the same files under a directory without touching an app.
Both refuse a spec with problems; warnings do not stop them.

[`example/live_activities.json`](example/live_activities.json) is a complete
spec: a delivery card with a photo, a Stages bar, a countdown, a count-up
text and all five surfaces, and an upload that uses the progress template.

## In the app: the typed API

`apply` and `generate` also write `package:ff_live_activity/live_activities.dart`:
one class per activity, named after its key (`delivery` ->
`DeliveryLiveActivity`), with a typed parameter per value, named after the
value's key in lowerCamelCase (`String`, `int`, `double`, `bool`,
`DateTime`, `Color`; an Image value takes a web address, a file path, an
asset or bytes).

```dart
import 'package:ff_live_activity/live_activities.dart';

await DeliveryLiveActivity.start(
  eta: DateTime.now().add(const Duration(minutes: 25)),
  courier: 'https://example.com/couriers/42.jpg',
);
await DeliveryLiveActivity.update(stage: 1, within: 0.3, status: 'On the way');
await DeliveryLiveActivity.end(dismissal: LiveActivityDismissal.systemDefault);
```

A value the spec marks `required` is required by `start`; `update` changes
only what is not null. The template, accent colour, icon, Android channel
name and the values' defaults come from the spec. The class only fills in
`FFLiveActivity.start`, `update` and `end`: the plugin and what it sends are
the same as when the app calls them itself.

## From Dart

```dart
import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';

final app = liveActivityAppFromJson(json); // or build LiveActivityApp directly
final problems = validateLiveActivityApp(app);
final files = {
  ...generateLiveActivityFiles(app), // path -> content
  ...liveActivityTypedApiFiles(app),
};
final back = liveActivityAppToJson(app); // generates the same files
```

`package:flutterflow_live_activity/io.dart` has `applyLiveActivities`, what
the `apply` command runs, and the functions it changes `project.pbxproj`,
`Info.plist` and `Runner.entitlements` with. The main library does not use
`dart:io`.

Built in Dart:

```dart
import 'package:flutterflow_live_activity/flutterflow_live_activity.dart';

final app = LiveActivityApp(
  iosBundleId: 'com.example.rides',
  routes: const LiveActivityRoutes(scheme: 'rides'),
  activities: [
    const LiveActivityDefinition(
      key: 'order',
      template: LiveActivityTemplate.etaTimer,
    ),
    LiveActivityDefinition(
      key: 'ride',
      template: LiveActivityTemplate.custom,
      values: const [
        LiveActivityValue(key: 'driver', type: LiveActivityValueType.string),
        LiveActivityValue(key: 'eta', type: LiveActivityValueType.dateTime),
      ],
      surfaces: {LiveActivitySurface.lockScreen: rideLayout},
    ),
  ],
);

// Path (relative to the app's root) to content.
final files = generateLiveActivityFiles(app);
```

The files are the plugin under `packages/ff_live_activity/` and the widget
extension under `ios/LiveActivity/`. Without `apply`, the app also needs:

- a path dependency on the plugin (`kLiveActivityPluginPubspecDependency`);
- the extension target in `ios/Runner.xcodeproj/project.pbxproj`
  (`liveActivityPbxprojFragments`, one fragment per slot of
  `kLiveActivityPbxprojSlots`);
- the entries of `ios/Runner/Info.plist`
  (`liveActivityRunnerInfoPlistEntries`);
- when a Custom card has an Image value, the shared keychain group
  (`LiveActivityApp.keychainGroup`) in the Runner's entitlements.

## The spec

| Type | What it is |
| --- | --- |
| `LiveActivityApp` | `specVersion`, the iOS bundle id and device family, the deep link routes, the activities |
| `LiveActivityDefinition` | key, name, template, accent colour, icon, Android channel name; for a Custom card its values, its layouts by surface and its Android settings |
| `LiveActivityValue` | key, name, type, default (as the wire string), whether it is required |
| `LiveActivitySurface` | Lock Screen, expanded island, compact leading and trailing, minimal |
| `LiveActivityAndroid` | standard or custom presentation, and the value each part of the standard Live Update shows |

The channel contract between the plugin's Dart, Swift and Kotlin sides
(channel, methods, argument keys, template names and value keys) is in
`lib/src/contract.dart`.

## The JSON spec

The command line reads, and `liveActivityAppFromJson` / `liveActivityAppToJson`
read and write, the spec as JSON. A field the reader does not know is an
error, with where it is (`$.activities[0].surfaces.lockScreen.root.value`).

```json
{
  "specVersion": 1,
  "iosBundleId": "com.example.courier",
  "iosDeviceFamily": "1",
  "routes": { "scheme": "courier", "host": "courier.example.com" },
  "activities": [
    { "key": "upload", "template": "progress", "accentColor": "#FF34C759" },
    { "key": "delivery", "template": "custom", "values": [], "surfaces": {} }
  ]
}
```

- **App**: `specVersion` (required; this package reads and writes 1),
  `iosBundleId`, `iosDeviceFamily` (`"1"` iPhone, `"1,2"` iPhone and iPad),
  `routes` (the deep link `scheme` and `host` a tap that opens a page uses,
  and `encodeTwice`), `activities`.
- **Activity**: `key` (stable across builds: it names the native types),
  `name` (the key when left out), `description`, `template`, `accentColor`
  (`#AARRGGBB`), `icon` (an asset), `androidChannelName`.
- **Templates**: `progress`, `etaTimer`, `score` and `queueStatus` are
  presets: they have their own values and views and take no `values`,
  `surfaces`, `android` or `androidDefaults`. `custom` draws the card's own
  layouts.
- **Values** of a Custom card: `key`, `name`, `type` (`string`, `integer`,
  `double`, `boolean`, `dateTime`, `color`, `image`), `default` (the wire
  string: `"3"`, `"0.5"`, `"true"`, milliseconds since the epoch, `"#AARRGGBB"`;
  for an image, the asset shown until the app sends a picture) and
  `required`.
- **Surfaces**: a layout for each of `lockScreen`, `islandExpanded`,
  `islandCompactLeading`, `islandCompactTrailing` and `islandMinimal`. Left
  out, `islandExpanded` is the `lockScreen` layout drawn on the island: dark
  colours, on black, without the card's own fill. `"islandExpanded": null`
  means none.
- **Layouts** are the home widget's layout JSON (`root` node, optional
  `tap`; see [`doc/spec.md`](../../doc/spec.md)), with what only a card
  draws:
  - a `text` with `"countUp": true` counts up from its `dateTime` value;
  - an `image` with `"value"` shows an Image value, and `"asset"` until the
    app sends one;
  - a `progress` with `"timed": {"start": "sent", "end": "eta"}` fills
    between two `dateTime` values on its own;
  - a `progress` with `"stages"` is a Stages bar: `current` (an integer
    value), optional `progress` (a double value: how far into the current
    stage), `trackerIcon`, `upcomingColor`, `showLabels`, `labelSize`,
    `labelColor` or `preferredLabelColor` (used when it reads on what is
    behind it), `upcomingLabelColor` or `preferredUpcomingLabelColor`, and
    2 to 6 `items` (`key`, `label`: a text or `{"value": key}`, `icon`).
  - A tap only opens a page: `{"openPage": "/orders", "params": [...]}`.
  - `stagesSpecs`, when written, says how Android draws each Stages bar of
    the layout; left out, it is what the bars draw.
- **android**: `presentation` (`standard`: the system's Live Update filled
  from the card's values; `custom`: the Lock Screen layout drawn with
  RemoteViews) and `slots`, the value each part of the standard Live Update
  shows (`title`, `text`, `progress`, `countdown`, `shortText`,
  `largeIcon`). `androidDefaults`, when written, is what Android shows for a
  value the app has not sent; left out, the values' own defaults.

The writer leaves out what the reader would fill in the same way (the
expanded island read from the Lock Screen, Android defaults and Stages specs
that are the derived ones), so a spec read, written and read again
generates the same files.

## Validate

`validateLiveActivityApp` (the `validate` command) lists every problem with
its path. Problems stop `generate` and `apply`:

- the spec version, an empty bundle id, no activities, a key that is empty
  or has another's native name;
- an accent colour that is not `#AARRGGBB`, an icon or image that is not an
  asset;
- a preset with values, layouts or Android settings;
- more than 24 values or 4 Image values on a card, a value key used twice, a
  default that is not of the value's type;
- a Custom card without a `lockScreen` or `islandExpanded` layout;
- a layout with more than 80 nodes, no root, two nodes with one key, a node
  reading a value of the wrong type (a text, colour, bar, visibility, timed
  bar, image, count-up, stage, or route parameter);
- a Stages bar that is a ring, has fewer than 2 or more than 6 stages, or
  reads its current stage from a non-integer;
- a tap that is a button, or opens a page without a route scheme or a path
  that does not start with `/`;
- a layout taller than its surface for sure (160 points on the Lock Screen,
  122 on the expanded island);
- an Android slot or default that names no value, or a value of the wrong
  type.

Warnings do not stop them: a card that may be cut off once every
conditional node shows, a Stages bar with unnamed stages and labels shown,
a drawn Android card that opens a page on tap (Android shows the standard
Live Update instead, as a drawn one cannot be tapped), values the standard
Live Update does not show, and activity or value keys whose Dart names
clash (the typed API numbers them).
