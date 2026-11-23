# flutterflow_home_widget

Native home screen widgets for a Flutter app, generated from one spec:

- **iOS**: a WidgetKit extension (Home Screen and Lock Screen sizes) drawn in
  SwiftUI, added to the app's Xcode project.
- **Android**: one app widget per widget, drawn with RemoteViews.
- **Dart**: the `ff_home_widget` plugin the app updates its widgets with
  (`FFHomeWidget.update`, `clear`), including from a silent push.

You describe each widget (its values, its choices, how it refreshes itself
and one layout per size) and the package writes the native code. Both
platforms draw from the same layout model, so a widget looks the same on
both, and anything one of them cannot draw is reported instead of shipped.

FlutterFlow generates its apps' home screen widgets with this package; other
tools can write the spec as JSON.

## Quick start

```sh
dart pub global activate --source git https://github.com/FlutterFlow/flutterflow_home_widget.git
flutter create --org com.example my_app
flutterflow_home_widget validate widgets.json
flutterflow_home_widget apply widgets.json my_app
```

`apply` writes the plugin under `packages/ff_home_widget/` and the
extension under `ios/HomeWidget/`, adds the plugin to `pubspec.yaml`, adds
the extension target to `ios/Runner.xcodeproj`, and adds the shared keychain
group to the Runner's `Info.plist` and `Runner.entitlements`. Running it
again only rewrites what changed. `generate` writes the files without
touching the app.

Then, in the app:

```dart
import 'package:ff_home_widget/ff_home_widget.dart';

await FFHomeWidget.update(
  definitionKey: 'water',
  values: {
    'glasses': FFHomeWidget.encodeInt(4),
    'progress': FFHomeWidget.encodeDouble(0.5),
    'status': '4 of 8 glasses',
  },
);
```

[`example/widgets.json`](example/widgets.json) is a complete spec: one
widget in two Home Screen sizes and two Lock Screen sizes, with a button
that adds a glass without opening the app.

## From Dart

```dart
import 'package:flutterflow_home_widget/flutterflow_home_widget.dart';

final app = homeWidgetAppFromJson(json); // or build HomeWidgetApp directly
final problems = validateHomeWidgetApp(app);
final files = generateHomeWidgetFiles(app); // path -> content
```

`package:flutterflow_home_widget/io.dart` has `applyHomeWidgets`, what the
`apply` command runs. The main library does not use `dart:io`.

## The spec

[`doc/spec.md`](doc/spec.md) describes every field. In short:

- **App**: the iOS bundle id, the device family, the deep link scheme and
  host that a tap opening a page uses, and the widgets.
- **Widget**: a key (stable across builds: it names the native types), a
  name, its **values** (`string`, `integer`, `double`, `boolean`,
  `dateTime`, `color`), and one **layout** per size: `small`, `medium`,
  `large` (iOS and Android), `accessoryCircular`, `accessoryRectangular`,
  `accessoryInline` (iOS Lock Screen).
- **Layout**: a tree of `box`, `row`, `column`, `stack`, `text`, `image`,
  `icon`, `spacer`, `divider` and `progress` nodes. A text, color, progress
  or visibility can read a value. A node can open a page of the app, or be a
  button that toggles a boolean, steps a number or clears the widget.
- Optional **refresh**: the widget fetches JSON on a schedule and reads its
  values out of it, natively, with the app closed.
- Optional **configuration**: choices a person picks when placing the widget
  (built-in, or added by the app at run time).

## What the app still needs

- **iOS signing**: the extension is its own target, `<bundle id>.HomeWidget`,
  with its own App ID and provisioning profile, and both targets need the
  Keychain Sharing capability (the group is `<bundle id>.homewidget`). The
  values the app sends are stored in that keychain group.
- **iOS 14** or later for widgets, **16** for the Lock Screen sizes and
  **17** for buttons and picking a choice. Below that the app works and the
  widgets are not offered.
- **Images** a layout shows must be Flutter assets the app bundles
  (`assets/...`). **Icons** are Material Icons code points; the plugin keeps
  their glyphs in the app's icon font.

## Versions

Tags are releases (`v0.1.1`). Depend on a tag:

```yaml
dependencies:
  flutterflow_home_widget:
    git:
      url: https://github.com/FlutterFlow/flutterflow_home_widget.git
      ref: v0.1.1
```

The generated native code and the Dart plugin it talks to are one unit, so
an app is regenerated whole when it moves to a new version.
