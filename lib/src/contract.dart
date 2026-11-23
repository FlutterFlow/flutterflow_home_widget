/// The wire contract between the three halves of generated home screen
/// widgets: the Dart API of the local `ff_home_widget` plugin package, its
/// Swift side (plugin + WidgetKit extension) and its Kotlin side (plugin +
/// AppWidgetProviders).
///
/// This file is the single source of truth. The Dart, Swift and Kotlin
/// generators interpolate these constants; none of them spells a channel name,
/// a method name or a key as its own literal.
///
/// Wire shape: the app sends a definition key and a flat `Map<String, String>`
/// of the widget's parameter values, keyed by parameter key. The native side stores that map as JSON (iOS: a
/// keychain item in a group the app and the extension share; Android:
/// SharedPreferences) and redraws the widget, which reads it back. Everything
/// else (name, sizes and each size's layout) is fixed at build time and
/// generated into the native code.
library;

import 'package:flutterflow_home_widget/src/spec.dart';

// --- Plugin package -------------------------------------------------------

/// Name of the local plugin package, written to `packages/ff_home_widget` in
/// the generated app and added to its pubspec as a path dependency.
const kHomeWidgetPluginPackage = 'ff_home_widget';

/// Directory of the plugin package, relative to the generated app's root.
const kHomeWidgetPluginPackagePath = 'packages/$kHomeWidgetPluginPackage';

/// The pubspec dependency entry of the generated app, in the same
/// `name: value` form `allDependencies` returns.
const kHomeWidgetPluginPubspecDependency =
    '$kHomeWidgetPluginPackage: \n    path: $kHomeWidgetPluginPackagePath';

/// Dart class the generated action code calls (`FFHomeWidget.update(...)`).
const kHomeWidgetDartClass = 'FFHomeWidget';

/// Dart library the generated action code imports.
const kHomeWidgetDartImport =
    'package:$kHomeWidgetPluginPackage/$kHomeWidgetPluginPackage.dart';

/// Plugin class name, the same on iOS (Swift) and Android (Kotlin).
const kHomeWidgetPluginClass = 'FFHomeWidgetPlugin';

/// Kotlin package of the Android plugin and providers.
const kHomeWidgetAndroidPackage = 'io.flutterflow.home_widget';

/// Name of the iOS widget-extension target and of its folder under `ios/`.
/// Its bundle id is the app's bundle id plus `.` plus this name.
const kHomeWidgetIosExtensionTarget = 'HomeWidget';

/// Lowest iOS version that shows home screen widgets (WidgetKit). The
/// extension target's deployment target; the plugin does nothing below it.
const kHomeWidgetMinIosVersion = '14.0';

// --- Shared storage ---------------------------------------------------------

/// iOS: keychain service of the stored values (one generic-password item per
/// widget, its account is the definition key). Android: name of the
/// SharedPreferences file (one string per widget, its key is the definition
/// key).
const kHomeWidgetStorageName = 'io.flutterflow.home_widget';

/// Suffix of the iOS keychain access group the app and the extension share:
/// `$(AppIdentifierPrefix)<app bundle id>.homewidget`. A keychain group under
/// the team prefix needs no setup in the Apple Developer portal (every
/// provisioning profile allows `<team id>.*`), unlike an App Group.
const kHomeWidgetKeychainGroupSuffix = 'homewidget';

/// Info.plist key (in the app's and in the extension's Info.plist) whose value
/// is the full keychain access group, team prefix included. Xcode expands
/// `$(AppIdentifierPrefix)` in it at build time.
const kHomeWidgetKeychainGroupInfoPlistKey = 'FFHomeWidgetKeychainGroup';

/// Key of the stored JSON object that holds the values map.
const kHomeWidgetStoredValues = 'values';

/// Key of the stored JSON object that holds when the values were written, in
/// milliseconds since the Unix epoch.
const kHomeWidgetStoredUpdatedAt = 'updatedAt';

/// Where a choice's own values are stored: the definition key, this, then
/// the choice's id (a fixed choice's key or the app's own id). A copy of the
/// widget showing that choice reads them over the shared values.
const kHomeWidgetStoredChoiceInfix = '/choice/';

/// Where the choices the app added are stored: the definition key, then
/// this. Its values map is choice id to the name the picker shows.
const kHomeWidgetStoredChoicesSuffix = '/choices';

/// WidgetKit `kind` of a definition's widget: this prefix plus the definition
/// key. The plugin reloads the timeline of exactly this kind.
const kHomeWidgetIosKindPrefix = 'FFHomeWidget.';

// --- Method channel ---------------------------------------------------------

const kHomeWidgetChannelName = 'flutterflow/home_widget';

/// Returns `bool`: whether the device can show home screen widgets.
const kHomeWidgetMethodIsSupported = 'isSupported';

/// Returns `bool`: false when the values could not be stored.
const kHomeWidgetMethodUpdate = 'update';

/// Returns nothing. Clearing a widget that shows nothing is not an error.
const kHomeWidgetMethodClear = 'clear';

const kHomeWidgetMethods = [
  kHomeWidgetMethodIsSupported,
  kHomeWidgetMethodUpdate,
  kHomeWidgetMethodClear,
];

// --- Argument keys ----------------------------------------------------------

/// `String`, required on update and clear: the widget's key
/// ([HomeWidgetDefinition.key]).
const kHomeWidgetArgDefinitionKey = 'definitionKey';

/// `Map<String, String>`, on update: the parameters' values, by parameter
/// key. Replaces what the widget showed; a value left out shows the
/// parameter's default.
const kHomeWidgetArgValues = 'values';

/// `String`, optional on update and clear: the choice the values are for. On
/// update they show only on the copies showing it; on clear only its values
/// go. Unset, update sets the values every copy shares and clear removes
/// everything the widget stored.
const kHomeWidgetArgChoiceId = 'choiceId';

/// `String`, optional on update with a choice id: the name the picker shows
/// for it. A choice the app sends values for is added to the picker, named
/// this or else its id.
const kHomeWidgetArgChoiceName = 'choiceName';

/// Argument keys per method, in the order generators emit them.
const kHomeWidgetMethodArguments = <String, List<String>>{
  kHomeWidgetMethodIsSupported: [],
  kHomeWidgetMethodUpdate: [
    kHomeWidgetArgDefinitionKey,
    kHomeWidgetArgValues,
    kHomeWidgetArgChoiceId,
    kHomeWidgetArgChoiceName,
  ],
  kHomeWidgetMethodClear: [kHomeWidgetArgDefinitionKey, kHomeWidgetArgChoiceId],
};

// --- Values -----------------------------------------------------------------

/// How a value travels in the `values` string map, per type. The Dart plugin
/// encodes with these; Swift and Kotlin decode the same way.
/// - string: as is.
/// - integer: decimal (`42`).
/// - double: Dart `double.toString()` (`0.5`).
/// - boolean: `true` or `false`.
/// - dateTime: milliseconds since the Unix epoch, decimal.
/// - color: `#AARRGGBB`, upper case.
///
/// The encoder of each type is [HomeWidgetValueType.encoder].
