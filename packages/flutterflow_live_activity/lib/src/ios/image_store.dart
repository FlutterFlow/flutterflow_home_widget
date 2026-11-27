/// The pictures of Image card values on iOS.
///
/// The widget extension has no network and a small memory budget, and the
/// card's state is about 4 KB of strings. So the app (the plugin) fetches a
/// picture, shrinks it to what the card draws, and stores it as a keychain
/// item in an access group the extension shares; the card's state only
/// carries the item's name. Everything here is generated only when a Custom
/// card has an Image value.
library;

import 'dart:math' as math;

import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

const _attributes = kLiveActivityAttributesType;
const _minIos = kLiveActivityMinIosVersion;
const _log = kLiveActivityDartClass;

/// Info.plist key (Runner and extension) that holds the access group with
/// the team prefix filled in by Xcode, so the code knows its full name.
const kLiveActivityKeychainGroupInfoPlistKey = 'FFLiveActivityKeychainGroup';

/// Keychain service of the stored pictures. The item's account is the
/// picture's name.
const kLiveActivityImageKeychainService = 'io.flutterflow.live_activity.image';

/// How long Start waits for its pictures before it shows the card with the
/// fallback, in seconds.
const kLiveActivityImageStartWaitSeconds = 2;

/// Timeout of a picture's download, in seconds.
const kLiveActivityImageDownloadTimeoutSeconds = 5;

/// The longest side a stored picture may have, in pixels. A Live Activity
/// does not draw an image of about a megapixel or more.
const kLiveActivityImageMaxPixels = 900;

/// The longest side, in pixels, each Image value's picture is stored at: by
/// definition key, then by value key. It is the largest node that shows the
/// value, in points times 3 (the densest screen), at most
/// [kLiveActivityImageMaxPixels]. One picture is stored per value and every
/// surface draws it. Empty when no card has an Image value.
Map<String, Map<String, int>> liveActivityImageTargets(LiveActivityApp app) => {
  for (final card in app.imageCards) card.key: _imageTargets(card),
};

Map<String, int> _imageTargets(LiveActivityDefinition card) {
  final targets = <String, int>{
    for (final value in card.imageValues)
      // Not drawn by any node: nothing to size it by.
      value.key: kLiveActivityImageMaxPixels,
  };
  final points = <String, double>{};
  for (final (canvas, model) in card.layouts) {
    for (final node in model.nodes) {
      if (node case LayoutImage(
        :final paramKey?,
        :final width,
        :final height,
      )) {
        // A side that fits or fills can be as long as the surface.
        final side = math.max(
          width.points ?? canvas.width,
          height.points ?? canvas.height,
        );
        points[paramKey] = math.max(points[paramKey] ?? 0, side);
      }
    }
  }
  for (final entry in points.entries) {
    if (targets.containsKey(entry.key)) {
      targets[entry.key] = math.min(
        kLiveActivityImageMaxPixels,
        entry.value.isFinite
            ? (entry.value * 3).ceil()
            : kLiveActivityImageMaxPixels,
      );
    }
  }
  return targets;
}

/// The Info.plist entry that names the shared access group, for both
/// `ios/Runner/Info.plist` and the extension's. `''` when no card has an
/// Image value.
String liveActivityKeychainGroupInfoPlistEntry(
  LiveActivityApp app, {
  String indent = '    ',
}) =>
    app.hasImageValues
        ? liveActivityKeychainGroupInfoPlistEntryFor(
          app.iosBundleId,
          indent: indent,
        )
        : '';

/// The Info.plist entry that names the access group the app with bundle id
/// [iosBundleId] shares with its extension.
String liveActivityKeychainGroupInfoPlistEntryFor(
  String iosBundleId, {
  String indent = '    ',
}) => '''
$indent<key>$kLiveActivityKeychainGroupInfoPlistKey</key>
$indent<string>${liveActivityKeychainGroup(iosBundleId)}</string>
''';

/// The entitlements of the Live Activity extension target: the shared access
/// group. Only written when a card has an Image value.
String liveActivityExtensionEntitlements(LiveActivityApp app) => '''
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

/// The Swift both sides share: the access group's full name and the query
/// that finds a stored picture.
const _keychainSwift = '''
  /// The access group the app and the Live Activity extension share, with
  /// the team prefix: Xcode fills it into Info.plist. nil in a build without
  /// it.
  static let group: String? = {
    guard
      let group = Bundle.main.object(forInfoDictionaryKey: "$kLiveActivityKeychainGroupInfoPlistKey")
        as? String,
      !group.isEmpty, !group.hasPrefix("\$(")
    else { return nil }
    return group
  }()

  static func query(_ name: String?) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "$kLiveActivityImageKeychainService",
    ]
    if let name = name { query[kSecAttrAccount as String] = name }
    if let group = group { query[kSecAttrAccessGroup as String] = group }
    return query
  }
''';

/// The extension side: reads a stored picture by its name. Goes into the
/// cards file; the emitted image views call it.
const kLiveActivityExtensionImageStoreSwift = '''
// MARK: - Pictures of Image values

/// The pictures the app stored for the cards' Image values. A card's state
/// carries a picture's name; the picture itself is a keychain item in the
/// access group the app shares with this extension.
enum FFLiveActivityImages {
$_keychainSwift
  private static var cache: [String: UIImage] = [:]

  /// The picture stored under [name]; nil when there is none (the card then
  /// draws the value's fallback).
  static func image(named name: String) -> UIImage? {
    guard !name.isEmpty else { return nil }
    if let cached = cache[name] { return cached }
    var query = query(name)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data, let image = UIImage(data: data)
    else {
      NSLog("$_log: image %@ not readable (%d)", name, Int(status))
      return nil
    }
    // A card shows a few pictures; old names never come back.
    if cache.count >= 8 { cache.removeAll() }
    cache[name] = image
    return image
  }
}
''';

String _swiftPixels(Map<String, Map<String, int>> targets) => targets.entries
    .map(
      (card) =>
          '    ${swiftString(card.key)}: [${card.value.entries.map((e) => '${swiftString(e.key)}: ${e.value}').join(', ')}],',
    )
    .join('\n');

/// The app side: fetches, shrinks, stores and sweeps the pictures. Goes at
/// the end of the plugin's Swift file. [targets] is
/// [liveActivityImageTargets].
String liveActivityPluginImageStoreSwift(
  Map<String, Map<String, int>> targets,
) => '''

#if canImport(ActivityKit)
import ImageIO
import Security

// MARK: - Pictures of Image values

/// One call's pictures, by the key of the Image value each is for: the name
/// each was stored under once it is loaded, nil when it could not be.
typealias FFLiveActivityImageLoads = [String: Task<String?, Never>]

/// Stores the pictures of the cards' Image values where the Live Activity
/// extension can read them: as keychain items in the access group the two
/// share. A card's state only carries a picture's name.
@available(iOS $_minIos, *)
@MainActor
enum FFLiveActivityImageStore {
$_keychainSwift
  /// The longest side each value's picture is stored at, in pixels: three
  /// times the largest node that shows it, by definition key and value key.
  static let pixels: [String: [String: Int]] = [
${_swiftPixels(targets)}
  ]

  /// Counts the pictures asked for per card and value, so a picture that
  /// arrives after a newer one was asked for is dropped.
  private static var asked: [String: Int] = [:]
  /// The source and the stored name of the picture each card and value
  /// shows, so the same source is not fetched twice.
  private static var showing: [String: (source: String, name: String)] = [:]

  /// The newest picture stored for each Image value of each card. Right
  /// after an update the system can still report the card's earlier values,
  /// so the sweep does not go by those alone.
  private static var newest: [String: String] = [:]
  /// Stored names that no card shows yet: the sweep keeps them.
  private static var held: [String: Int] = [:]

  private static func slot(_ definitionKey: String, _ instanceId: String, _ key: String) -> String {
    definitionKey + "|" + instanceId + "|" + key
  }

  /// Starts loading [images] (the call's `$kLiveActivityArgImages` argument).
  static func load(
    _ images: [String: Any],
    definitionKey: String,
    instanceId: String
  ) -> FFLiveActivityImageLoads {
    var loads: FFLiveActivityImageLoads = [:]
    for (key, value) in images {
      guard let source = value as? [String: Any] else { continue }
      let slot = slot(definitionKey, instanceId, key)
      asked[slot, default: 0] += 1
      let identity = sourceIdentity(source)
      if let identity = identity, let shown = showing[slot], shown.source == identity,
        exists(shown.name)
      {
        // The picture now showing: nothing to fetch.
        held[shown.name, default: 0] += 1
        loads[key] = Task { shown.name }
        continue
      }
      let maxPixels = pixels[definitionKey]?[key] ?? $kLiveActivityImageMaxPixels
      loads[key] = Task {
        let name = await Task.detached(priority: .userInitiated) {
          await store(source, prefix: definitionKey, maxPixels: maxPixels)
        }.value
        if let name = name {
          held[name, default: 0] += 1
          newest[slot] = name
          if let identity = identity { showing[slot] = (identity, name) }
        }
        return name
      }
    }
    return loads
  }

  /// The names of the pictures of [loads] that are stored within [seconds],
  /// by value key. The others keep loading: see [late].
  static func ready(_ loads: FFLiveActivityImageLoads, within seconds: Double) async -> [String: String] {
    if loads.isEmpty { return [:] }
    final class Wait {
      var names: [String: String] = [:]
      var left: Int
      var continuation: CheckedContinuation<[String: String], Never>?
      init(_ left: Int) { self.left = left }
      func finish() {
        continuation?.resume(returning: names)
        continuation = nil
      }
    }
    let wait = Wait(loads.count)
    return await withCheckedContinuation { continuation in
      wait.continuation = continuation
      for (key, load) in loads {
        Task { @MainActor in
          let name = await load.value
          if wait.continuation != nil, let name = name { wait.names[key] = name }
          wait.left -= 1
          if wait.left == 0 { wait.finish() }
        }
      }
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        wait.finish()
      }
    }
  }

  /// Puts each picture of [loads] that is not in [applied] on the card when
  /// it arrives, unless the card ended or the value was set again meanwhile.
  static func late(
    _ loads: FFLiveActivityImageLoads,
    applied: [String: String],
    definitionKey: String,
    instanceId: String
  ) {
    for (key, load) in loads where applied[key] == nil {
      let slot = slot(definitionKey, instanceId, key)
      let turn = asked[slot] ?? 0
      Task { @MainActor in
        guard let name = await load.value else { return }
        if asked[slot] == turn {
          for activity in Activity<$_attributes>.activities
          where activity.attributes.definitionKey == definitionKey
            && activity.attributes.instanceId == instanceId
            && (activity.activityState == .active || activity.activityState == .stale)
          {
            let merged = activity.content.state.values.merging([key: name]) { _, new in new }
            await activity.update(ActivityContent(state: .init(values: merged), staleDate: nil))
          }
        }
        release([name])
        sweep()
      }
    }
  }

  /// The pictures [names] are on their card (or dropped): the sweep may
  /// remove them once no card shows them.
  static func release<S: Sequence>(_ names: S) where S.Element == String {
    for name in names {
      let count = (held[name] ?? 1) - 1
      held[name] = count > 0 ? count : nil
    }
  }

  /// Deletes every stored picture that no card shows. A card that ended but
  /// is still on the Lock Screen keeps its picture until it is dismissed.
  static func sweep() {
    var used = Set(held.keys)
    var cards: [String] = []
    for activity in Activity<$_attributes>.activities where activity.activityState != .dismissed {
      used.formUnion(activity.content.state.values.values)
      cards.append(slot(activity.attributes.definitionKey, activity.attributes.instanceId, ""))
    }
    for (slot, name) in newest {
      if cards.contains(where: { slot.hasPrefix(\$0) }) {
        used.insert(name)
      } else {
        newest[slot] = nil
        showing[slot] = nil
      }
    }
    var list = query(nil)
    list[kSecReturnAttributes as String] = true
    list[kSecMatchLimit as String] = kSecMatchLimitAll
    var items: CFTypeRef?
    guard SecItemCopyMatching(list as CFDictionary, &items) == errSecSuccess,
      let rows = items as? [[String: Any]]
    else { return }
    var removed = 0
    for row in rows {
      guard let name = row[kSecAttrAccount as String] as? String, !used.contains(name) else {
        continue
      }
      if SecItemDelete(query(name) as CFDictionary) == errSecSuccess { removed += 1 }
    }
    if removed > 0 {
      NSLog("$_log: image sweep removed %d of %d", removed, rows.count)
    }
  }

  private static func exists(_ name: String) -> Bool {
    SecItemCopyMatching(query(name) as CFDictionary, nil) == errSecSuccess
  }

  /// What tells two sources apart; nil for bytes, which are always stored.
  private static func sourceIdentity(_ source: [String: Any]) -> String? {
    for kind in ["$kLiveActivityImageSourceUrl", "$kLiveActivityImageSourcePath", "$kLiveActivityImageSourceAsset"] {
      if let value = source[kind] as? String { return kind + ":" + value }
    }
    return nil
  }

  /// Fetches [source], shrinks it and stores it under a fresh name, which a
  /// card's state then carries: a new name per picture makes the card
  /// redraw. nil when any step fails; the card then keeps what it shows.
  nonisolated private static func store(
    _ source: [String: Any],
    prefix: String,
    maxPixels: Int
  ) async -> String? {
    guard let data = await fetch(source) else { return nil }
    // ImageIO's thumbnail never holds the full bitmap.
    guard let image = CGImageSourceCreateWithData(data as CFData, nil),
      let small = CGImageSourceCreateThumbnailAtIndex(
        image, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
      )
    else {
      NSLog("$_log: image is not a picture (%d bytes)", data.count)
      return nil
    }
    let opaque: Bool
    switch small.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast: opaque = true
    default: opaque = false
    }
    let picture = UIImage(cgImage: small)
    guard let stored = opaque ? picture.jpegData(compressionQuality: 0.8) : picture.pngData()
    else { return nil }
    let name =
      prefix + "-" + UUID().uuidString.prefix(8).lowercased() + (opaque ? ".jpg" : ".png")
    var item = await query(name)
    item[kSecValueData as String] = stored
    // The card redraws while the phone is locked.
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else {
      NSLog("$_log: image not stored (%d)", Int(status))
      return nil
    }
    return name
  }

  nonisolated private static func fetch(_ source: [String: Any]) async -> Data? {
    if let bytes = source["$kLiveActivityImageSourceBytes"] as? FlutterStandardTypedData {
      return bytes.data
    }
    if let path = source["$kLiveActivityImageSourcePath"] as? String {
      return FileManager.default.contents(atPath: path)
    }
    if let asset = source["$kLiveActivityImageSourceAsset"] as? String {
      let key = FlutterDartProject.lookupKey(forAsset: asset)
      return Bundle.main.path(forResource: key, ofType: nil).flatMap {
        FileManager.default.contents(atPath: \$0)
      }
    }
    guard let link = source["$kLiveActivityImageSourceUrl"] as? String, let url = URL(string: link)
    else { return nil }
    var request = URLRequest(url: url)
    request.timeoutInterval = $kLiveActivityImageDownloadTimeoutSeconds
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        NSLog("$_log: image download failed (HTTP %d)", http.statusCode)
        return nil
      }
      return data
    } catch {
      NSLog("$_log: image download failed: %@", error.localizedDescription)
      return nil
    }
  }
}
#endif
''';
