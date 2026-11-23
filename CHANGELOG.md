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
