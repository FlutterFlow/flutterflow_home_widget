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

## Use

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
extension under `ios/LiveActivity/`. The app also needs:

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
