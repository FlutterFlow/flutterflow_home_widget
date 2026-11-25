import 'package:flutterflow_home_widget/src/contract.dart';
import 'package:flutterflow_home_widget/src/ios/pbxproj_fragments.dart';
import 'package:flutterflow_home_widget/src/refresh.dart';
import 'package:flutterflow_home_widget/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

// Short names for the contract constants the Swift below interpolates. No
// channel name, method name, argument key, value key or template name is
// spelled in this file as its own literal. The Swift avoids `\(...)` string
// interpolation, so `$` and `\` here only ever mean Dart.
const _plugin = kHomeWidgetPluginClass;
const _package = kHomeWidgetPluginPackage;
const _target = kHomeWidgetIosExtensionTarget;
const _minIos = kHomeWidgetMinIosVersion;
const _groupKey = kHomeWidgetKeychainGroupInfoPlistKey;

/// Directory of the widget extension, relative to the generated app's root.
const kHomeWidgetIosExtensionPath = 'ios/$_target';

/// Directory of the plugin's Swift sources, relative to the generated app's
/// root. One layout serves both CocoaPods and Swift Package Manager.
const kHomeWidgetIosPluginPath = '$kHomeWidgetPluginPackagePath/ios';
const kHomeWidgetIosPluginSourcesPath =
    '$kHomeWidgetIosPluginPath/$_package/Sources/$_package';

/// The iOS files of the feature, path (relative to the app's root) to
/// content: the widget extension under `ios/HomeWidget/` and the iOS side of
/// the `ff_home_widget` plugin package.
///
/// `HomeWidgetBundle.swift` lists the project's widgets (one WidgetKit kind
/// per definition, with its name and sizes) and `HomeWidgetLayouts.swift`
/// draws each size's layout; `HomeWidgetViews.swift` is the same for every
/// project.
Map<String, String> homeWidgetIosFiles(HomeWidgetApp app) => {
  // Widget extension target. The pbxproj fragments list exactly these files.
  '$kHomeWidgetIosExtensionPath/Info.plist': homeWidgetExtensionInfoPlist(app),
  '$kHomeWidgetIosExtensionPath/$kHomeWidgetIosEntitlementsFile':
      homeWidgetExtensionEntitlements(app),
  '$kHomeWidgetIosExtensionPath/$kHomeWidgetIosBundleSwiftFile':
      homeWidgetBundleSwift(app.widgets),
  '$kHomeWidgetIosExtensionPath/$kHomeWidgetIosLayoutsSwiftFile':
      homeWidgetLayoutsSwift(app),
  '$kHomeWidgetIosExtensionPath/$kHomeWidgetIosViewsSwiftFile':
      homeWidgetViewsSwift,
  // iOS side of the plugin package.
  '$kHomeWidgetIosPluginPath/$_package.podspec': kHomeWidgetPodspec,
  '$kHomeWidgetIosPluginPath/$_package/Package.swift': kHomeWidgetPackageSwift,
  '$kHomeWidgetIosPluginSourcesPath/$_plugin.swift': homeWidgetPluginSwift,
};

/// `Info.plist` of the widget extension target. Carries the shared keychain
/// group with its team prefix, which the extension reads its values from.
String homeWidgetExtensionInfoPlist(HomeWidgetApp app) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>\$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>$_target</string>
	<key>CFBundleExecutable</key>
	<string>\$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>\$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>\$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>$_groupKey</key>
	<string>${app.keychainGroup}</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
''';

/// The extension's entitlements: the keychain group it shares with the app.
String homeWidgetExtensionEntitlements(HomeWidgetApp app) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array>
		<string>${app.keychainGroup}</string>
	</array>
</dict>
</plist>
''';

/// CocoaPods manifest of the plugin's iOS side.
const kHomeWidgetPodspec =
    '''
Pod::Spec.new do |s|
  s.name             = '$_package'
  s.version          = '0.0.1'
  s.summary          = 'FlutterFlow home screen widget bridge.'
  s.description      = 'Method channel over WidgetKit for the generated app.'
  s.homepage         = 'https://flutterflow.io'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'FlutterFlow' => 'support@flutterflow.io' }
  s.source           = { :path => '.' }
  s.source_files     = '$_package/Sources/$_package/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.weak_frameworks  = 'WidgetKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
''';

/// Swift Package Manager manifest of the plugin's iOS side.
final kHomeWidgetPackageSwift =
    '''
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "$_package",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "${_package.split('_').join('-')}", targets: ["$_package"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "$_package",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
''';

/// Reads and writes a widget's values: one keychain item per widget in the
/// group the app and the extension share. The plugin and the extension each
/// compile a copy.
const _storeSwift =
    '''
/// A widget's values, stored as JSON in a keychain item of the group the app
/// and the widget extension share. The group's name (with the team prefix
/// Xcode fills in) is in Info.plist; without it the default group is used,
/// which only the process that wrote the item can read.
enum FFHomeWidgetStore {
  static let service = "$kHomeWidgetStorageName"

  static var accessGroup: String? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "$_groupKey") as? String,
      !group.isEmpty, !group.hasPrefix("\$(")
    else { return nil }
    return group
  }

  private static func query(_ key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    if let group = accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }
    return query
  }

  private static func object(_ key: String) -> [String: Any]? {
    var query = query(key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  static func read(_ key: String) -> [String: String]? {
    object(key)?["$kHomeWidgetStoredValues"] as? [String: String]
  }

  /// The values the app sent with [key]'s scheduled values that are due at
  /// [date] laid over them, in time order.
  static func read(_ key: String, at date: Date) -> [String: String]? {
    guard let object = object(key),
      var values = object["$kHomeWidgetStoredValues"] as? [String: String]
    else { return nil }
    for entry in schedule(object) where entry.at <= date {
      values.merge(entry.values) { _, new in new }
    }
    return values
  }

  /// When [key]'s scheduled values take effect.
  static func scheduleDates(_ key: String) -> [Date] {
    object(key).map { object in schedule(object).map { entry in entry.at } } ?? []
  }

  private static func schedule(_ object: [String: Any]) -> [(at: Date, values: [String: String])] {
    let list = object["$kHomeWidgetStoredSchedule"] as? [[String: Any]] ?? []
    return list.compactMap { entry in
      guard let millis = (entry["$kHomeWidgetScheduleAt"] as? NSNumber)?.doubleValue,
        let values = entry["$kHomeWidgetScheduleValues"] as? [String: String]
      else { return nil }
      return (at: Date(timeIntervalSince1970: millis / 1000), values: values)
    }.sorted { a, b in a.at < b.at }
  }

  /// Stores [values]. [schedule] replaces the scheduled values; nil keeps
  /// them (a button or a fetch changes the values, not the schedule).
  @discardableResult
  static func write(_ key: String, values: [String: String], schedule: [[String: Any]]? = nil) -> Bool {
    var object: [String: Any] = [
      "$kHomeWidgetStoredValues": values,
      "$kHomeWidgetStoredUpdatedAt": Int64(Date().timeIntervalSince1970 * 1000),
    ]
    if let kept = schedule ?? (Self.object(key)?["$kHomeWidgetStoredSchedule"] as? [[String: Any]]),
      !kept.isEmpty
    {
      object["$kHomeWidgetStoredSchedule"] = kept
    }
    guard let data = try? JSONSerialization.data(withJSONObject: object) else { return false }
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      // The widget redraws while the phone is locked.
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    var status = SecItemUpdate(query(key) as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var add = query(key)
      add.merge(attributes) { _, new in new }
      status = SecItemAdd(add as CFDictionary, nil)
    }
    if status != errSecSuccess {
      NSLog("$kHomeWidgetDartClass: could not store values (%d)", Int(status))
    }
    return status == errSecSuccess
  }

  static func delete(_ key: String) {
    SecItemDelete(query(key) as CFDictionary)
  }

  /// Where the values of [key]'s choice [choice] are stored.
  static func choiceKey(_ key: String, _ choice: String) -> String {
    key + "$kHomeWidgetStoredChoiceInfix" + choice
  }

  /// Where [key]'s choices the app added are stored: id to name.
  static func choicesKey(_ key: String) -> String { key + "$kHomeWidgetStoredChoicesSuffix" }

  /// Everything stored for [key]: its values, each choice's and the app's
  /// choices.
  static func deleteAll(_ key: String) {
    delete(key)
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitAll,
    ]
    if let group = accessGroup {
      query[kSecAttrAccessGroup as String] = group
    }
    var items: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
      let found = items as? [[String: Any]]
    else { return }
    for item in found {
      if let account = item[kSecAttrAccount as String] as? String, account.hasPrefix(key + "/") {
        delete(account)
      }
    }
  }
}
''';

/// The app side: the method channel over the store and WidgetCenter.
const homeWidgetPluginSwift =
    '''
// Generated by FlutterFlow.
import Flutter
import Foundation
import Security
import UIKit

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Method channel `$kHomeWidgetChannelName`: stores a home screen widget's
/// values and asks WidgetKit to redraw it.
public class $_plugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "$kHomeWidgetChannelName",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate($_plugin(), channel: channel)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(reloadPending),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS $_minIos, *) else {
      switch call.method {
      case "$kHomeWidgetMethodIsSupported", "$kHomeWidgetMethodUpdate",
        "$kHomeWidgetMethodIsPinSupported", "$kHomeWidgetMethodRequestPin":
        result(false)
      case "$kHomeWidgetMethodClear": result(nil)
      case "$kHomeWidgetMethodPlacedWidgets": result([])
      default: result(FlutterMethodNotImplemented)
      }
      return
    }
    switch call.method {
    case "$kHomeWidgetMethodIsSupported":
      result(true)
      return
    // Only the person adds widgets on iOS.
    case "$kHomeWidgetMethodIsPinSupported", "$kHomeWidgetMethodRequestPin":
      result(false)
      return
    case "$kHomeWidgetMethodPlacedWidgets":
      Self.placedWidgets(result)
      return
    default:
      break
    }
    let args = call.arguments as? [String: Any] ?? [:]
    guard let key = args["$kHomeWidgetArgDefinitionKey"] as? String, !key.isEmpty else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "$kHomeWidgetArgDefinitionKey is required",
          details: nil
        )
      )
      return
    }
    let choice = (args["$kHomeWidgetArgChoiceId"] as? String).flatMap { id in id.isEmpty ? nil : id }
    switch call.method {
    case "$kHomeWidgetMethodUpdate":
      let values = (args["$kHomeWidgetArgValues"] as? [String: Any] ?? [:])
        .compactMapValues { value in value as? String }
      let schedule = (args["$kHomeWidgetArgSchedule"] as? [[String: Any]] ?? []).map { entry in
        [
          "$kHomeWidgetScheduleAt": (entry["$kHomeWidgetScheduleAt"] as? NSNumber)?.int64Value ?? 0,
          "$kHomeWidgetScheduleValues": (entry["$kHomeWidgetScheduleValues"] as? [String: Any] ?? [:])
            .compactMapValues { value in value as? String },
        ] as [String: Any]
      }
      guard let choice = choice else {
        let stored = FFHomeWidgetStore.write(key, values: values, schedule: schedule)
        Self.reload(key)
        result(stored)
        return
      }
      // A choice's own values, and the choice in the picker.
      let stored = FFHomeWidgetStore.write(
        FFHomeWidgetStore.choiceKey(key, choice), values: values, schedule: schedule)
      let choicesKey = FFHomeWidgetStore.choicesKey(key)
      var choices = FFHomeWidgetStore.read(choicesKey) ?? [:]
      if let name = args["$kHomeWidgetArgChoiceName"] as? String, !name.isEmpty {
        choices[choice] = name
      } else if choices[choice] == nil {
        choices[choice] = choice
      }
      FFHomeWidgetStore.write(choicesKey, values: choices)
      Self.reload(key)
      result(stored)
    case "$kHomeWidgetMethodClear":
      if let choice = choice {
        FFHomeWidgetStore.delete(FFHomeWidgetStore.choiceKey(key, choice))
        let choicesKey = FFHomeWidgetStore.choicesKey(key)
        var choices = FFHomeWidgetStore.read(choicesKey) ?? [:]
        choices.removeValue(forKey: choice)
        FFHomeWidgetStore.write(choicesKey, values: choices)
      } else {
        FFHomeWidgetStore.deleteAll(key)
      }
      Self.reload(key)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Every copy of the app's widgets WidgetKit has, with its size.
  private static func placedWidgets(_ result: @escaping FlutterResult) {
    #if canImport(WidgetKit)
    if #available(iOS $_minIos, *) {
      WidgetCenter.shared.getCurrentConfigurations { found in
        var list: [[String: Any]] = []
        if case .success(let infos) = found {
          for info in infos where info.kind.hasPrefix("$kHomeWidgetIosKindPrefix") {
            var item: [String: Any] = [
              "$kHomeWidgetPlacedDefinitionKey": String(info.kind.dropFirst("$kHomeWidgetIosKindPrefix".count))
            ]
            if let size = sizeName(info.family) {
              item["$kHomeWidgetPlacedSize"] = size
            }
            list.append(item)
          }
        }
        DispatchQueue.main.async { result(list) }
      }
      return
    }
    #endif
    result([])
  }

  #if canImport(WidgetKit)
  @available(iOS $_minIos, *)
  private static func sizeName(_ family: WidgetFamily) -> String? {
    switch family {
    case .systemSmall: return "small"
    case .systemMedium: return "medium"
    case .systemLarge: return "large"
    default: break
    }
    if #available(iOS 16.0, *) {
      switch family {
      case .accessoryCircular: return "accessoryCircular"
      case .accessoryRectangular: return "accessoryRectangular"
      case .accessoryInline: return "accessoryInline"
      default: break
      }
    }
    return nil
  }
  #endif

  private static func reload(_ key: String) {
    #if canImport(WidgetKit)
    if #available(iOS $_minIos, *) {
      let kind = "$kHomeWidgetIosKindPrefix" + key
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
      // WidgetKit may put off a redraw asked for in the background (a silent
      // push), so it is asked again once the app is open.
      if UIApplication.shared.applicationState != .active {
        let defaults = UserDefaults.standard
        var pending = Set(defaults.stringArray(forKey: pendingReloadsKey) ?? [])
        pending.insert(kind)
        defaults.set(Array(pending), forKey: pendingReloadsKey)
      }
    }
    #endif
  }

  /// Where the widgets to redraw when the app is next open are kept, so
  /// they survive the app being closed in between.
  private static let pendingReloadsKey = "$kHomeWidgetPluginPackage.pendingReloads"

  @objc private static func reloadPending() {
    let defaults = UserDefaults.standard
    guard let pending = defaults.stringArray(forKey: pendingReloadsKey) else { return }
    defaults.removeObject(forKey: pendingReloadsKey)
    #if canImport(WidgetKit)
    if #available(iOS $_minIos, *) {
      for kind in pending {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      }
    }
    #endif
  }
}

$_storeSwift''';

/// `HomeWidgetBundle.swift`: the project's widgets. One `Widget` struct per
/// definition (WidgetKit creates widgets with `init()`, so each one carries
/// its definition), all in one bundle.
String homeWidgetBundleSwift(List<HomeWidgetDefinition> definitions) {
  final structs = StringBuffer();
  for (final definition in definitions) {
    final layouts = definition.sizedLayouts;
    final key = definition.key;
    // The Lock Screen families are iOS 16+, so they are added, and picked,
    // behind an availability check.
    final home = [
      for (final layout in layouts)
        if (!layout.$1.isLockScreen) layout,
    ];
    final lock = [
      for (final layout in layouts)
        if (layout.$1.isLockScreen) layout,
    ];
    final families = home.map((l) => _swiftFamily(l.$1)).join(', ');
    final lockFamilies = lock.map((l) => _swiftFamily(l.$1)).join(', ');
    String view((HomeWidgetSize, Object) layout) =>
        '${swiftLayoutViewName(key, layout.$1.tag)}(values: values)';
    // The Lock Screen families are iOS 16+, so they are checked before the
    // switch, which then sits one level deeper.
    final pad = lock.isEmpty ? '' : '  ';
    final lockBranches = [
      for (final layout in lock)
        'if #available(iOSApplicationExtension 16.0, *), '
            'family == ${_swiftFamily(layout.$1)} {\n'
            '        ${view(layout)}\n'
            '      }',
    ];
    final familySwitch = [
      '      ${pad}switch family {',
      for (final layout in home)
        '      ${pad}case ${_swiftFamily(layout.$1)}: ${view(layout)}',
      '      ${pad}default: ${view(layouts.first)}',
      '      $pad}',
    ].join('\n');
    final layoutBody = lock.isEmpty
        ? familySwitch
        : '      ${lockBranches.join(' else ')} else {\n'
              '$familySwitch\n'
              '      }';
    final defaults = definition.defaultValues;
    final defaultsCode = defaults.isEmpty
        ? '[:]'
        : '[${defaults.entries.map((e) => '${swiftString(e.key)}: ${swiftString(e.value)}').join(', ')}]';
    final refreshPlan = definition.refresh;
    final refreshCode = refreshPlan == null
        ? ''
        : ',\n    refresh: ${_swiftRefresh(refreshPlan, refreshPlan.urlKeys([for (final v in definition.values) v.key]))}';
    final configurable = definition.isConfigurable;
    final choicesCode = configurable ? _swiftChoices(definition) : '';
    structs.write('''

struct ${definition.swiftType}: Widget {
  static let definition = FFHomeWidgetDefinition(
    key: ${swiftString(key)},
    placeholder: ${swiftString(definition.placeholder)},
    defaults: $defaultsCode$refreshCode$choicesCode
  )

  struct Layout: View {
    let values: FFValues
    @Environment(\\.widgetFamily) private var family

    var body: some View {
$layoutBody
    }
  }

  static var families: [WidgetFamily] {
    var families: [WidgetFamily] = [$families]
${lock.isEmpty ? '' : '    if #available(iOSApplicationExtension 16.0, *) {\n      families += [$lockFamilies]\n    }\n'}    return families
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: Self.definition.kind,
      provider: FFHomeWidgetProvider(definition: Self.definition)
    ) { entry in
      FFHomeWidgetView(entry: entry) { values in Layout(values: values) }
    }
    .configurationDisplayName(${swiftString(definition.displayName)})
    .description(${swiftString(definition.description.trim())})
    .supportedFamilies(Self.families)
    .ffContentMarginsDisabled()
  }
}
''');
    if (configurable) {
      structs.write(_swiftConfigurableWidget(definition));
    }
  }
  final types = [for (final d in definitions) '${d.swiftType}()'];
  // On iOS 17+ a widget a person picks a choice for is configured with an
  // App Intent. WidgetKit has no if/else between widgets, so the extension
  // starts the bundle that fits the OS; both give each widget the same kind.
  final configurable = definitions.any((d) => d.isConfigurable);
  final choiceTypes = [
    for (final d in definitions)
      d.isConfigurable ? '${d.swiftType}_Configurable()' : '${d.swiftType}()',
  ];
  // The buttons look a widget's defaults up by its key.
  final byKey = [
    for (final d in definitions)
      '  ${swiftString(d.key)}: ${d.swiftType}.definition,',
  ];
  final byKeyCode = byKey.isEmpty
      ? 'let kFFHomeWidgetDefinitionsByKey: [String: FFHomeWidgetDefinition] = [:]'
      : 'let kFFHomeWidgetDefinitionsByKey: [String: FFHomeWidgetDefinition] = [\n${byKey.join('\n')}\n]';
  final main = configurable
      ? '''
@main
struct ${_target}Main {
  @MainActor static func main() {
    if #available(iOS 17.0, *) {
      ${_target}ChoiceBundle.main()
    } else {
      ${_target}Bundle.main()
    }
  }
}
${_swiftBundle('${_target}Bundle', 'FFHomeWidgetGroup', types)}${_swiftBundle('${_target}ChoiceBundle', 'FFHomeWidgetChoiceGroup', choiceTypes, available: '@available(iOS 17.0, *)\n')}'''
      : '''
@main
${_swiftBundle('${_target}Bundle', 'FFHomeWidgetGroup', types)}''';
  return '''
// Generated by FlutterFlow from Settings > Home Screen Widgets.
${configurable ? 'import AppIntents\n' : ''}import SwiftUI
import WidgetKit

$byKeyCode
$main$structs${types.isEmpty ? _emptyWidgetSwift : ''}''';
}

/// A `WidgetBundle` named [name] of [types] (or `EmptyWidget()` when there
/// are none). A bundle body takes at most 10 widgets, so a longer list is
/// split into nested bundles of 10, named [groupName] and a number.
String _swiftBundle(
  String name,
  String groupName,
  List<String> types, {
  String available = '',
}) {
  final chunks = [
    for (var i = 0; i < types.length; i += 10)
      types.sublist(i, i + 10 > types.length ? types.length : i + 10),
  ];
  String lines(List<String> items) => items.map((t) => '    $t').join('\n');
  final body = switch (chunks.length) {
    0 => lines(['EmptyWidget()']),
    1 => lines(chunks.single),
    _ => lines([for (var i = 0; i < chunks.length; i++) '$groupName$i().body']),
  };
  final groups = StringBuffer();
  if (chunks.length > 1) {
    for (var i = 0; i < chunks.length; i++) {
      groups.write('''

${available}struct $groupName$i: WidgetBundle {
  var body: some Widget {
${lines(chunks[i])}
  }
}
''');
    }
  }
  return '''${available}struct $name: WidgetBundle {
  var body: some Widget {
$body
  }
}
$groups''';
}

/// The `choices:` and `appChoices:` arguments of [definition]'s Swift
/// definition.
String _swiftChoices(HomeWidgetDefinition definition) {
  final configuration = definition.configuration!;
  final choices = [
    for (final choice in configuration.choices)
      'FFHomeWidgetChoice(id: ${swiftString(choice.id)}, '
          'name: ${swiftString(choice.name)}, values: '
          '${_swiftMap(definition.choiceValues(choice))})',
  ];
  return ',\n    choices: [${choices.join(', ')}]'
      ',\n    appChoices: ${configuration.appChoices}';
}

String _swiftMap(Map<String, String> map) => map.isEmpty
    ? '[:]'
    : '[${map.entries.map((e) => '${swiftString(e.key)}: ${swiftString(e.value)}').join(', ')}]';

/// The iOS 17 version of a widget a person picks a choice for: the choice
/// as an App Entity the edit sheet lists, the configuration intent that holds
/// it, and the widget configured by it, with the same kind, layouts and
/// families as the widget below iOS 17.
String _swiftConfigurableWidget(HomeWidgetDefinition definition) {
  final type = definition.swiftType;
  final title = swiftString(definition.choiceTitle);
  return '''

@available(iOS 17.0, *)
struct ${type}_Choice: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = $title
  static var defaultQuery = ${type}_ChoiceQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name))
  }
}

@available(iOS 17.0, *)
struct ${type}_ChoiceQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [${type}_Choice] {
    try await suggestedEntities().filter { choice in identifiers.contains(choice.id) }
  }

  func suggestedEntities() async throws -> [${type}_Choice] {
    // The table, not the widget's static: a query runs off the main actor.
    let definition = kFFHomeWidgetDefinitionsByKey[${swiftString(definition.key)}]
    return (definition.map(FFHomeWidgetChoices.all) ?? []).map { choice in
      ${type}_Choice(id: choice.id, name: choice.name)
    }
  }
}

@available(iOS 17.0, *)
struct ${type}_Configuration: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = $title

  @Parameter(title: $title) var choice: ${type}_Choice?

  init() {}
}

@available(iOS 17.0, *)
struct ${type}_Configurable: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: $type.definition.kind,
      intent: ${type}_Configuration.self,
      provider: FFHomeWidgetChoiceProvider<${type}_Configuration>(definition: $type.definition) {
        configuration in configuration.choice?.id
      }
    ) { entry in
      FFHomeWidgetView(entry: entry) { values in $type.Layout(values: values) }
    }
    .configurationDisplayName(${swiftString(definition.displayName)})
    .description(${swiftString(definition.description.trim())})
    .supportedFamilies($type.families)
    .ffContentMarginsDisabled()
  }
}
''';
}

/// `HomeWidgetLayouts.swift`: one view per layout, drawn from the layout's
/// design on the canvas.
String homeWidgetLayoutsSwift(HomeWidgetApp app) {
  final views = StringBuffer();
  for (final definition in app.widgets) {
    for (final (size, model) in definition.sizedLayouts) {
      views.write(
        swiftLayoutView(
          swiftLayoutViewName(definition.key, size.tag),
          model,
          widgetKey: definition.key,
          countdown: SwiftCountdownStyle.fullWidth,
        ),
      );
    }
  }
  return '''
// Generated by FlutterFlow from each home screen widget's layouts.
import SwiftUI
import WidgetKit

/// The app's deep links (App Settings > App Details > Routing & Deep Linking).
let kFFRouteScheme = ${swiftString(app.routes.scheme)}
let kFFRouteHost = ${swiftString(app.routes.host)}
/// Whether each value is encoded twice. iOS hands the app a widget's link as
/// a pushed route, and the router decodes a pushed route once more than one
/// it is given as is. FlutterFlow Dynamic Links gives the router the link as
/// is.
let kFFRouteEncodeTwice = ${app.routes.encodeTwice}

$kNativeLayoutSwiftPageUrl$views''';
}

const _emptyWidgetSwift =
    '''

/// Keeps the bundle valid with no widget defined; never offered.
struct EmptyWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "$kHomeWidgetIosKindPrefix",
      provider: FFHomeWidgetProvider(
        definition: FFHomeWidgetDefinition(key: "", placeholder: "", defaults: [:])
      )
    ) { entry in
      FFHomeWidgetView(entry: entry) { _ in Color.clear }
    }
    .supportedFamilies([])
  }
}
''';

/// The Swift `FFHomeWidgetRefresh(...)` of [plan].
String _swiftRefresh(HomeWidgetRefreshPlan plan, List<String> keys) {
  final headers = plan.headers.isEmpty
      ? '[:]'
      : '[${plan.headers.entries.map((e) => '${swiftString(e.key)}: ${swiftString(e.value)}').join(', ')}]';
  final values = [
    for (final value in plan.values)
      'FFFetchedValue(key: ${swiftString(value.key)}, type: .${_fetchedType(value.type)}, '
          'path: [${value.path.map((step) => switch (step) {
            JsonKey(:final name) => '.key(${swiftString(name)})',
            JsonIndex(:final index) => '.index($index)',
          }).join(', ')}])',
  ];
  final keysCode = keys.isEmpty
      ? ''
      : ', keys: [${keys.map(swiftString).join(', ')}]';
  return 'FFHomeWidgetRefresh(url: ${swiftString(plan.url)}, headers: $headers, '
      'interval: ${plan.intervalMinutes * 60}, values: [${values.join(', ')}]$keysCode)';
}

/// The native name of a fetched value's type.
String _fetchedType(HomeWidgetValueType type) => switch (type) {
  HomeWidgetValueType.integer => 'integer',
  HomeWidgetValueType.double => 'double',
  HomeWidgetValueType.boolean => 'bool',
  HomeWidgetValueType.dateTime => 'date',
  HomeWidgetValueType.color => 'color',
  HomeWidgetValueType.string => 'text',
};

String _swiftFamily(HomeWidgetSize size) => switch (size) {
  HomeWidgetSize.small => '.systemSmall',
  HomeWidgetSize.medium => '.systemMedium',
  HomeWidgetSize.large => '.systemLarge',
  HomeWidgetSize.accessoryCircular => '.accessoryCircular',
  HomeWidgetSize.accessoryRectangular => '.accessoryRectangular',
  HomeWidgetSize.accessoryInline => '.accessoryInline',
};

/// `HomeWidgetViews.swift`: what every layout is built from, the provider and
/// the store. The same for every project.
final homeWidgetViewsSwift =
    '''
// Generated by FlutterFlow.
import AppIntents
import CoreText
import Foundation
import Security
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Definition, values and entry

/// One widget as Settings > Home Screen Widgets defines it.
struct FFHomeWidgetDefinition {
  let key: String
  /// Shown until the app first sends values.
  let placeholder: String
  /// The parameters' default values, as the app would send them.
  let defaults: [String: String]
  /// What the widget fetches by itself; nil when only the app updates it.
  var refresh: FFHomeWidgetRefresh? = nil
  /// The choices set in FlutterFlow that a person picks one of for each copy.
  var choices: [FFHomeWidgetChoice] = []
  /// Whether the choices the app adds are in the picker too.
  var appChoices: Bool = false

  var kind: String { "$kHomeWidgetIosKindPrefix" + key }
}

/// A choice set in FlutterFlow, and the values it sets.
struct FFHomeWidgetChoice {
  let id: String
  let name: String
  let values: [String: String]
}

/// What a copy of a widget shows for the choice it was given.
enum FFHomeWidgetChoices {
  /// The picker's choices: those set in FlutterFlow, then the app's by name.
  static func all(_ definition: FFHomeWidgetDefinition) -> [(id: String, name: String)] {
    var list = definition.choices.map { choice in (id: choice.id, name: choice.name) }
    guard definition.appChoices else { return list }
    let fixed = Set(definition.choices.map { choice in choice.id })
    let added = (FFHomeWidgetStore.read(FFHomeWidgetStore.choicesKey(definition.key)) ?? [:])
      .filter { entry in !fixed.contains(entry.key) }
      .map { entry in (id: entry.key, name: entry.value) }
      .sorted { a, b in a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending }
    list += added
    return list
  }

  /// The values every copy shares, then the choice's set in FlutterFlow,
  /// then those the app sent for it. nil until there are any.
  static func values(
    _ definition: FFHomeWidgetDefinition, choice: String?, at date: Date = Date()
  ) -> FFValues? {
    let shared = FFHomeWidgetStore.read(definition.key, at: date)
    guard let choice = choice else {
      return shared.map { raw in FFValues(raw: raw, defaults: definition.defaults) }
    }
    let fixed = definition.choices.first { item in item.id == choice }?.values
    let own = FFHomeWidgetStore.read(FFHomeWidgetStore.choiceKey(definition.key, choice), at: date)
    if shared == nil && fixed == nil && own == nil { return nil }
    var raw = shared ?? [:]
    raw.merge(fixed ?? [:]) { _, new in new }
    raw.merge(own ?? [:]) { _, new in new }
    return FFValues(raw: raw, defaults: definition.defaults, choice: choice)
  }

  /// When the scheduled values a copy showing [choice] reads take effect.
  static func scheduleDates(_ definition: FFHomeWidgetDefinition, choice: String?) -> [Date] {
    var dates = FFHomeWidgetStore.scheduleDates(definition.key)
    if let choice = choice {
      dates += FFHomeWidgetStore.scheduleDates(FFHomeWidgetStore.choiceKey(definition.key, choice))
    }
    return dates
  }
}

// MARK: - Fetching values

/// A widget fetching its own values every [interval] seconds from [url].
struct FFHomeWidgetRefresh {
  let url: String
  let headers: [String: String]
  let interval: TimeInterval
  let values: [FFFetchedValue]
  /// The values the URL reads, as `{key}`. A URL that reads any is fetched
  /// for each choice on its own, and stores what it fetched for that choice.
  var keys: [String] = []
}

enum FFJSONStep {
  case key(String)
  case index(Int)
}

enum FFFetchedType {
  case text, integer, double, bool, date, color
}

/// One value the widget fetches: where it is in the response.
struct FFFetchedValue {
  let key: String
  let type: FFFetchedType
  let path: [FFJSONStep]
}

/// Fetches a widget's values and stores them, as the app would send them.
enum FFHomeWidgetFetcher {
  static func fetch(
    _ definition: FFHomeWidgetDefinition, choice: String? = nil, done: @escaping () -> Void
  ) {
    guard let refresh = definition.refresh else {
      done()
      return
    }
    var address = refresh.url
    if !refresh.keys.isEmpty {
      let current = FFHomeWidgetChoices.values(definition, choice: choice)
        ?? FFValues(raw: [:], defaults: definition.defaults, choice: choice)
      var allowed = CharacterSet.alphanumerics
      allowed.insert(charactersIn: "-._~")
      for key in refresh.keys {
        let value = current.text(key).addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        address = address.replacingOccurrences(of: "{" + key + "}", with: value)
      }
    }
    // What a URL that reads a choice's values fetched belongs to that choice.
    let target = refresh.keys.isEmpty || choice == nil
      ? definition.key : FFHomeWidgetStore.choiceKey(definition.key, choice!)
    guard let url = URL(string: address) else {
      done()
      return
    }
    var request = URLRequest(url: url, timeoutInterval: 15)
    for (name, value) in refresh.headers {
      request.setValue(value, forHTTPHeaderField: name)
    }
    URLSession.shared.dataTask(with: request) { data, response, _ in
      defer { done() }
      guard let data = data,
        let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
        let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
      else { return }
      var values = FFHomeWidgetStore.read(target) ?? [:]
      for value in refresh.values {
        if let found = walk(json, value.path), let text = convert(found, value.type) {
          values[value.key] = text
        }
      }
      FFHomeWidgetStore.write(target, values: values)
    }.resume()
  }

  private static func walk(_ json: Any, _ path: [FFJSONStep]) -> Any? {
    var current: Any? = json
    for step in path {
      switch step {
      case .key(let name): current = (current as? [String: Any])?[name]
      case .index(let index):
        guard let list = current as? [Any], index < list.count else { return nil }
        current = list[index]
      }
    }
    return current is NSNull ? nil : current
  }

  private static func number(_ value: Any) -> Double? {
    if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
      return number.doubleValue
    }
    return (value as? String).flatMap { Double(\$0) }
  }

  /// [value] as the app would send it for [type] (see the channel contract).
  private static func convert(_ value: Any, _ type: FFFetchedType) -> String? {
    switch type {
    case .text:
      if let text = value as? String { return text }
      if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
        return number.boolValue ? "true" : "false"
      }
      if let number = number(value) {
        return number == number.rounded() && abs(number) < 1e15
          ? String(Int64(number)) : String(number)
      }
      return nil
    case .integer: return number(value).map { String(Int64(\$0.rounded())) }
    case .double: return number(value).map { String(\$0) }
    case .bool:
      if let number = value as? NSNumber { return number.boolValue ? "true" : "false" }
      if let text = value as? String { return text.lowercased() == "true" ? "true" : "false" }
      return nil
    case .date:
      if let text = value as? String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        return date.map { String(Int64(\$0.timeIntervalSince1970 * 1000)) }
      }
      // A number: milliseconds, or seconds when it is too small to be.
      return number(value).map { String(Int64(\$0 > 1e11 ? \$0 : \$0 * 1000)) }
    case .color:
      guard var hex = value as? String, hex.hasPrefix("#") else { return nil }
      hex.removeFirst()
      if hex.count == 6 { hex = "FF" + hex }
      return hex.count == 8 && UInt32(hex, radix: 16) != nil ? "#" + hex.uppercased() : nil
    }
  }
}

$kNativeLayoutSwiftValues
struct FFHomeWidgetEntry: TimelineEntry {
  let date: Date
  let definition: FFHomeWidgetDefinition
  /// nil until the app sends values (or after it clears them).
  let values: FFValues?
}

$kNativeLayoutSwiftColor
// MARK: - Timeline

/// One entry with the stored values, one at each scheduled change, and one
/// at each date among the values, so a countdown stops at zero instead of
/// counting up. The app reloads the timeline whenever it sends new values,
/// so the policy is `.never`.
enum FFHomeWidgetTimeline {
  static func placeholder(_ definition: FFHomeWidgetDefinition) -> FFHomeWidgetEntry {
    FFHomeWidgetEntry(
      date: Date(), definition: definition,
      values: FFValues(raw: [:], defaults: definition.defaults))
  }

  /// The gallery shows the defaults until the app sends values.
  static func snapshot(
    _ definition: FFHomeWidgetDefinition, choice: String?, preview: Bool
  ) -> FFHomeWidgetEntry {
    let stored = FFHomeWidgetChoices.values(definition, choice: choice)
    let shown = preview && stored == nil
      ? FFValues(raw: [:], defaults: definition.defaults, choice: choice) : stored
    return FFHomeWidgetEntry(date: Date(), definition: definition, values: shown)
  }

  static func load(
    _ definition: FFHomeWidgetDefinition, choice: String?,
    completion: @escaping (Timeline<FFHomeWidgetEntry>) -> Void
  ) {
    guard let refresh = definition.refresh else {
      completion(timeline(definition, choice: choice, policy: .never))
      return
    }
    // A widget that fetches its values does so on each reload, then asks
    // for the next one after its interval.
    FFHomeWidgetFetcher.fetch(definition, choice: choice) {
      completion(
        timeline(
          definition, choice: choice,
          policy: .after(Date().addingTimeInterval(refresh.interval))))
    }
  }

  private static func timeline(
    _ definition: FFHomeWidgetDefinition, choice: String?, policy: TimelineReloadPolicy
  ) -> Timeline<FFHomeWidgetEntry> {
    let now = Date()
    func entry(_ date: Date) -> FFHomeWidgetEntry {
      FFHomeWidgetEntry(
        date: date, definition: definition,
        values: FFHomeWidgetChoices.values(definition, choice: choice, at: date))
    }
    // Each scheduled change, and each countdown's end in every state the
    // schedule leads to.
    var dates = Set(FFHomeWidgetChoices.scheduleDates(definition, choice: choice).filter { \$0 > now })
    for date in [now] + Array(dates) {
      for end in entry(date).values?.dates ?? [] where end > now {
        dates.insert(end)
      }
    }
    let entries = [entry(now)] + dates.sorted().map(entry)
    return Timeline(entries: entries, policy: policy)
  }
}

struct FFHomeWidgetProvider: TimelineProvider {
  let definition: FFHomeWidgetDefinition

  func placeholder(in context: Context) -> FFHomeWidgetEntry {
    FFHomeWidgetTimeline.placeholder(definition)
  }

  func getSnapshot(in context: Context, completion: @escaping (FFHomeWidgetEntry) -> Void) {
    completion(FFHomeWidgetTimeline.snapshot(definition, choice: nil, preview: context.isPreview))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FFHomeWidgetEntry>) -> Void) {
    FFHomeWidgetTimeline.load(definition, choice: nil, completion: completion)
  }
}

/// The timeline of a copy that shows the choice a person picked in its edit
/// sheet (iOS 17+).
@available(iOS 17.0, *)
struct FFHomeWidgetChoiceProvider<Intent: WidgetConfigurationIntent>: AppIntentTimelineProvider {
  let definition: FFHomeWidgetDefinition
  let choice: (Intent) -> String?

  func placeholder(in context: Context) -> FFHomeWidgetEntry {
    FFHomeWidgetTimeline.placeholder(definition)
  }

  func snapshot(for configuration: Intent, in context: Context) async -> FFHomeWidgetEntry {
    FFHomeWidgetTimeline.snapshot(
      definition, choice: choice(configuration), preview: context.isPreview)
  }

  func timeline(for configuration: Intent, in context: Context) async -> Timeline<FFHomeWidgetEntry> {
    let picked = choice(configuration)
    return await withCheckedContinuation { continuation in
      FFHomeWidgetTimeline.load(definition, choice: picked) { timeline in
        continuation.resume(returning: timeline)
      }
    }
  }
}

// MARK: - Container

/// The layout on the system widget background, or the placeholder text until
/// the app sends values.
struct FFHomeWidgetView<Layout: View>: View {
  let entry: FFHomeWidgetEntry
  @ViewBuilder let layout: (FFValues) -> Layout
  @Environment(\\.widgetFamily) private var family

  /// The Lock Screen draws its own background behind a widget.
  private var lockScreen: Bool {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(family)
    }
    return false
  }

  var body: some View {
    Group {
      if let values = entry.values {
        layout(values)
      } else {
        Text(entry.definition.placeholder)
          .font(.system(size: lockScreen ? 12 : 14))
          .foregroundColor(.secondary)
          .padding(lockScreen ? 0 : 16)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      }
    }
    .environment(\\.ffNow, entry.date)
    .ffWidgetBackground(clear: lockScreen)
  }
}

$kNativeLayoutSwiftNow
extension View {
  /// The system widget background. The layout draws its own fill on top.
  /// [clear] on the Lock Screen, which draws its own.
  @ViewBuilder func ffWidgetBackground(clear: Bool = false) -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) {
        clear ? Color.clear : Color(UIColor.systemBackground)
      }
    } else {
      background(clear ? Color.clear : Color(UIColor.systemBackground))
    }
  }
}

extension WidgetConfiguration {
  /// The layout is designed edge to edge, so iOS 17's content margins are off.
  func ffContentMarginsDisabled() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return contentMarginsDisabled()
    }
    return self
  }
}

// MARK: - Building blocks of layouts

${nativeLayoutSwiftBuildingBlocks(_target, countdown: SwiftCountdownStyle.fullWidth)}
// MARK: - Buttons

/// Changes a widget's stored values in place: what its buttons do. A value
/// the app never sent starts from its default.
enum FFHomeWidgetButtons {
  static func apply(
    widget: String, choice: String?, kind: String, value: String, step: Double,
    min: Double?, max: Double?, integer: Bool
  ) {
    // A copy showing a choice changes that choice's own values.
    let store = choice.map { id in FFHomeWidgetStore.choiceKey(widget, id) } ?? widget
    if kind == "clear" {
      FFHomeWidgetStore.delete(store)
      return
    }
    let definition = kFFHomeWidgetDefinitionsByKey[widget]
    let shown = definition.flatMap { d in FFHomeWidgetChoices.values(d, choice: choice)?.raw } ?? [:]
    var values = FFHomeWidgetStore.read(store) ?? [:]
    let current = values[value] ?? shown[value] ?? definition?.defaults[value]
    switch kind {
    case "toggle":
      values[value] = current == "true" ? "false" : "true"
    case "step":
      var number = current.flatMap { Double(\$0) } ?? 0
      number += step
      if let min = min { number = Swift.max(number, min) }
      if let max = max { number = Swift.min(number, max) }
      values[value] = integer ? String(Int(number.rounded())) : String(number)
    default:
      return
    }
    FFHomeWidgetStore.write(store, values: values)
  }
}

/// Runs a button in the widget extension; WidgetKit then redraws the widget.
@available(iOS 17.0, *)
struct FFHomeWidgetButtonIntent: AppIntent {
  static var title: LocalizedStringResource = "Change a home screen widget"
  static var isDiscoverable: Bool = false

  @Parameter(title: "Widget") var widget: String
  @Parameter(title: "Choice") var choice: String?
  @Parameter(title: "Kind") var kind: String
  @Parameter(title: "Value") var value: String
  @Parameter(title: "Step") var step: Double
  @Parameter(title: "Lowest") var min: Double?
  @Parameter(title: "Highest") var max: Double?
  @Parameter(title: "Whole number") var integer: Bool

  init() {}

  init(
    widget: String, choice: String?, kind: String, value: String, step: Double,
    min: Double?, max: Double?, integer: Bool
  ) {
    self.widget = widget
    self.choice = choice
    self.kind = kind
    self.value = value
    self.step = step
    self.min = min
    self.max = max
    self.integer = integer
  }

  func perform() async throws -> some IntentResult {
    FFHomeWidgetButtons.apply(
      widget: widget, choice: choice, kind: kind, value: value, step: step,
      min: min, max: max, integer: integer)
    return .result()
  }
}

/// A button of a widget's layout: [label] as is, tappable on iOS 17 and
/// later. Earlier, a tap on it does what a tap on the widget does.
struct FFButton<Label: View>: View {
  let widget: String
  let choice: String?
  let kind: String
  let value: String
  let step: Double
  let min: Double?
  let max: Double?
  let integer: Bool
  @ViewBuilder let label: () -> Label

  var body: some View {
    if #available(iOS 17.0, *) {
      Button(
        intent: FFHomeWidgetButtonIntent(
          widget: widget, choice: choice, kind: kind, value: value, step: step,
          min: min, max: max, integer: integer)
      ) {
        label()
      }
      .buttonStyle(.plain)
    } else {
      label()
    }
  }
}

// MARK: - Store

$_storeSwift''';
