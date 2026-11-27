## 0.3.0

- A new package in this repository, `flutterflow_live_activity`
  (`packages/flutterflow_live_activity/`), generates iOS Live Activities and
  Android Live Updates from a typed spec, drawing Custom cards with
  `flutterflow_native_layout`. It is versioned with this package.
- The layout model, the SwiftUI and RemoteViews emitters, escaping and the
  shared Swift and Kotlin run time move into a new package,
  `flutterflow_native_layout` (`packages/flutterflow_native_layout/`), which
  this package depends on by path. `layout.dart` and the main library
  re-export it, so existing imports keep working.
- `native_layout.dart` re-exports the parts of the core that code drawing
  native layouts of its own (such as Live Activity cards) uses.
- `HomeWidgetValueType` is a typedef of the core's `LayoutValueType`; `id`,
  `encoder` and `isNumber` come from the `HomeWidgetValueTypeWire` extension.
- A carriage return in a text, a widget name or a description is escaped in
  Kotlin strings (`\r`) and Android XML (`\u000D`) instead of being written
  raw, which broke the Android build. Generated files are otherwise
  unchanged.
- `homeWidgetViewsSwift` is `final` instead of `const`.
- `flutterflow_native_layout` reads and writes the layout JSON
  (`nativeLayoutFromJson`, `nativeLayoutToJson`); this package's JSON uses
  it (`layout_json.dart`), so the format is the same. The forms only a Live Activity card draws
  (`countUp`, an image `value`, `timed` and `stages` bars) are an error in a
  widget's layout instead of being ignored.
- `flutterflow_live_activity` can be used on its own, as this package can:
  - a JSON spec (`liveActivityAppFromJson`, `liveActivityAppToJson`) with
    `specVersion`; fixed templates are presets; reading, writing and reading
    again generates the same files;
  - `validateLiveActivityApp`: the spec's limits (24 values, 4 Image values,
    80 nodes a layout, 2 to 6 stages), value types, surfaces, Android slots,
    taps and card heights, with paths, and warnings that do not stop
    generation;
  - a `flutterflow_live_activity` command with `validate`, `generate` and
    `apply` (`applyLiveActivities` in `io.dart`), which adds the Live
    Activities to a `flutter create` app and changes nothing when run again;
  - a typed API, `package:ff_live_activity/live_activities.dart`: one class
    per activity with typed `start`, `update` and `end` over
    `FFLiveActivity`. `generateLiveActivityFiles` does not include it
    (`liveActivityTypedApiFiles` does), so its output is unchanged;
  - `example/live_activities.json`.
- `flutterflow_live_activity apply` checks `iosBundleId` against the
  Runner's `PRODUCT_BUNDLE_IDENTIFIER` in every build configuration before it
  writes anything, and refuses with both ids when it does not match (the
  extension is `<iosBundleId>.LiveActivity`, and iOS rejects one whose id is
  not prefixed with the app's). A Runner id that is a build setting
  (`$(...)`) is a warning (`applyLiveActivities` takes `onWarning`). The
  example spec's `iosBundleId` is now `com.example.courier`, the id
  `flutter create --org com.example courier` makes.
- `SpecJsonReader`, `NativeLayoutJsonException`, `nativeLayoutFromJson`,
  `nativeLayoutToJson`, `layoutColorToJson` and `layoutHex` are no longer
  exported from `package:flutterflow_native_layout/flutterflow_native_layout.dart`
  (nor through the main libraries of the two packages that re-export it).
  Import `package:flutterflow_native_layout/layout_json.dart` for them.

## 0.2.0

- `FFHomeWidget.update` takes a `schedule`: values that take effect later,
  without the app running (WidgetKit timeline entries on iOS, an alarm on
  Android, exact when the app may set exact alarms).
- `FFHomeWidget.isPinSupported`, `requestPin` (Android 8+) and
  `placedWidgets` (the copies on the home screen, with size and, on Android,
  choice).
- A refresh URL can read the widget's values as `{key}`: each copy fetches
  with its own choice's values and keeps what it fetched for that choice.
  An Android copy fetches as soon as its choice is picked.
- `apply` gives the widget extension the Runner's development team, so it
  signs like the app.
- The test fixture no longer carries a development team.

## 0.1.1

- The repository is now `FlutterFlow/flutterflow_home_widget`, the package's
  name.

## 0.1.0

- First release: the home screen widget generator FlutterFlow's codegen used
  internally, as a package. A JSON form of the spec, validation, and `apply`
  for apps made by `flutter create` are new.
