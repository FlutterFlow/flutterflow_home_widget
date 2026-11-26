## Unreleased

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
