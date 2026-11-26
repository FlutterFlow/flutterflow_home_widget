/// The Swift a native layout's view needs at run time, as source text.
///
/// `swiftLayoutView` (swiftui_emitter.dart) writes views that call these. An
/// extension that draws layouts puts each of them in its sources once.
///
/// Home screen widgets and Live Activity cards draw from the same run time.
/// The one part that differs between them is `FFCountdownText`, chosen by
/// [SwiftCountdownStyle].
library;

/// How `FFCountdownText`, a text that counts down to a date, is drawn. The
/// view (`swiftLayoutView`) and the run time
/// (`nativeLayoutSwiftBuildingBlocks`) must be given the same style.
enum SwiftCountdownStyle {
  /// `Text(end, style: .timer)`: the text takes all the width it is offered.
  /// The view gives the countdown no alignment.
  fullWidth,

  /// As wide as the widest text the countdown shows from now on, with the
  /// ticking text in it where the text is aligned (`alignment:`).
  fitted,
}

/// `FFPageURL`: the app's deep link a tap opens. The file that includes it
/// declares `kFFRouteScheme`, `kFFRouteHost` and `kFFRouteEncodeTwice`.
const kNativeLayoutSwiftPageUrl = '''
/// The app's deep link to the page at [path]: a `:name` segment is filled
/// with that parameter, the others go in the query. A parameter without a
/// value is left out.
func FFPageURL(_ path: String, _ params: [(String, String?)]) -> URL {
  let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
  )
  func encodeOnce(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
  }
  func encode(_ value: String) -> String {
    kFFRouteEncodeTwice ? encodeOnce(encodeOnce(value)) : encodeOnce(value)
  }
  var query: [(String, String)] = params.compactMap { name, value in
    value.map { (name, \$0) }
  }
  let segments = path.split(separator: "/").map { segment -> String in
    guard segment.hasPrefix(":") else { return String(segment) }
    let name = String(segment.dropFirst())
    guard let index = query.firstIndex(where: { \$0.0 == name }) else { return "" }
    return encode(query.remove(at: index).1)
  }
  let base = kFFRouteScheme + "://" + kFFRouteHost + "/"
  var link = base + segments.joined(separator: "/")
  if !query.isEmpty {
    link += "?" + query.map { encode(\$0.0) + "=" + encode(\$0.1) }.joined(separator: "&")
  }
  return URL(string: link) ?? URL(string: base)!
}
''';

/// `FFValues`: the values a layout reads, decoded per type.
const kNativeLayoutSwiftValues = '''
/// The values the app sent, decoded per type as the channel contract says.
/// A value the app did not send is the parameter's default, else empty.
struct FFValues {
  let raw: [String: String]
  let defaults: [String: String]
  /// The choice this copy of the widget shows; nil for the shared values.
  var choice: String? = nil

  private func string(_ key: String) -> String? { raw[key] ?? defaults[key] }

  func text(_ key: String) -> String { string(key) ?? "" }

  func double(_ key: String) -> Double { string(key).flatMap { Double(\$0) } ?? 0 }

  func bool(_ key: String) -> Bool { string(key) == "true" }

  func date(_ key: String) -> Date? {
    guard let millis = string(key).flatMap({ Double(\$0) }) else { return nil }
    return Date(timeIntervalSince1970: millis / 1000)
  }

  func color(_ key: String) -> Color {
    guard var hex = string(key), hex.hasPrefix("#") else { return .clear }
    hex.removeFirst()
    guard let argb = UInt32(hex, radix: 16) else { return .clear }
    return FFColor(light: argb, dark: argb)
  }

  // A value as a page's route reads it (the app's `deserializeParam`); nil
  // when the widget has no value for it.

  func routeText(_ key: String) -> String? { string(key) }

  func routeDate(_ key: String) -> String? { string(key).map { "l" + \$0 } }

  func routeColor(_ key: String) -> String? {
    guard var hex = string(key), hex.hasPrefix("#") else { return nil }
    hex.removeFirst()
    guard hex.count == 8, let argb = UInt32(hex, radix: 16) else { return nil }
    let alpha = (argb >> 24) & 0xFF
    let rgb = String(format: "%06X", argb & 0xFFFFFF)
    if alpha == 0xFF { return "#" + rgb }
    return String(
      format: "rgba(%d, %d, %d, %.3f)",
      Int((argb >> 16) & 0xFF), Int((argb >> 8) & 0xFF), Int(argb & 0xFF),
      Double(alpha) / 255
    )
  }

  /// Every date among the values, for the timeline's countdown entries.
  var dates: [Date] {
    raw.values.compactMap { value in
      guard let millis = Double(value), millis > 1_000_000_000_000 else { return nil }
      return Date(timeIntervalSince1970: millis / 1000)
    }
  }
}
''';

/// `FFColor(light:dark:)`.
const kNativeLayoutSwiftColor = '''
/// A colour with its dark-mode twin, from 0xAARRGGBB.
func FFColor(light: UInt32, dark: UInt32) -> Color {
  func ui(_ argb: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
  if light == dark { return Color(ui(light)) }
  return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
}
''';

/// The `ffNow` environment value countdowns read: the time the view is drawn
/// for.
const kNativeLayoutSwiftNow = '''
private struct FFNowKey: EnvironmentKey {
  static let defaultValue = Date()
}

extension EnvironmentValues {
  /// The time the timeline entry is for; countdowns read it.
  var ffNow: Date {
    get { self[FFNowKey.self] }
    set { self[FFNowKey.self] = newValue }
  }
}
''';

/// What layouts are built from: `FFCountdownText`, `FFAssetImage`,
/// `FFIconText`, `FFRingProgress`, `ffLines`, `FFBarProgress`.
/// [extensionTarget] is the name of the extension target the code is in.
/// [countdown] is how `FFCountdownText` is drawn; the views must be written
/// with the same style. Needs SwiftUI, UIKit and CoreText, and
/// [kNativeLayoutSwiftNow].
String nativeLayoutSwiftBuildingBlocks(
  String extensionTarget, {
  SwiftCountdownStyle countdown = SwiftCountdownStyle.fitted,
}) => '''
/// The containing app's bundle, two levels above
/// `<App>.app/PlugIns/$extensionTarget.appex`. An extension may read it.
private let ffAppBundle = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()

${switch (countdown) {
  SwiftCountdownStyle.fullWidth => _countdownFullWidth,
  SwiftCountdownStyle.fitted => _countdownFitted,
}}
/// An image the app bundles as a Flutter asset.
struct FFAssetImage: View {
  let path: String
  /// .fit, .fill, or nil to stretch.
  let contentMode: ContentMode?

  private static var cache: [String: UIImage] = [:]

  private var image: UIImage? {
    if let cached = Self.cache[path] { return cached }
    let url = ffAppBundle.appendingPathComponent("Frameworks/App.framework/flutter_assets/" + path)
    guard let image = UIImage(contentsOfFile: url.path) else { return nil }
    // WidgetKit refuses an image of more than about a megapixel
    // (ArchivingError.imageTooLarge) and draws the placeholder instead. The
    // renderer draws at the screen's scale unless told otherwise, so the
    // size is in pixels and the scale 1.
    let longest = max(image.size.width * image.scale, image.size.height * image.scale)
    let factor = min(1, 900 / max(longest, 1))
    let size = CGSize(
      width: (image.size.width * image.scale * factor).rounded(),
      height: (image.size.height * image.scale * factor).rounded()
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    Self.cache[path] = small
    return small
  }

  var body: some View {
    if let image = image {
      if let mode = contentMode {
        Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
      } else {
        Image(uiImage: image).resizable()
      }
    } else {
      Color.clear
    }
  }
}

/// A Material Icons glyph, from the icon font the app bundles.
struct FFIconText: View {
  let codePoint: UInt32
  let size: CGFloat
  let color: Color

  private static let fontName: String = {
    let url = ffAppBundle.appendingPathComponent(
      "Frameworks/App.framework/flutter_assets/fonts/MaterialIcons-Regular.otf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    if let data = try? Data(contentsOf: url),
      let provider = CGDataProvider(data: data as CFData),
      let font = CGFont(provider),
      let name = font.postScriptName as String?
    {
      return name
    }
    return "MaterialIcons-Regular"
  }()

  var body: some View {
    Text(String(UnicodeScalar(codePoint).map(Character.init) ?? " "))
      .font(.custom(Self.fontName, fixedSize: size))
      .foregroundColor(color)
      .frame(width: size, height: size)
  }
}

/// A circular progress indicator: a track and an arc from the top.
struct FFRingProgress: View {
  let value: Double
  let color: Color
  let track: Color
  let diameter: CGFloat
  let thickness: CGFloat
  /// Degrees clockwise from the top, as percent_indicator's startAngle.
  var startAngle: Double = 0

  var body: some View {
    ZStack {
      Circle().stroke(track, lineWidth: thickness)
      Circle()
        .trim(from: 0, to: CGFloat(min(max(value, 0), 1)))
        .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
        .rotationEffect(.degrees(-90 + startAngle))
    }
    .frame(width: diameter - thickness, height: diameter - thickness)
    .frame(width: diameter, height: diameter)
  }
}

extension View {
  /// A text's lines as Flutter lays them out. With [height], each line is
  /// size × height tall, the extra leading split above and below the glyphs
  /// in the font's ascent-to-descent ratio (Flutter's proportional leading).
  /// With [clip], the text is cut off after that many lines with no "…", as
  /// Flutter's default clip overflow does.
  func ffLines(size: CGFloat, weight: Font.Weight, height: CGFloat?, clip: Int?) -> some View {
    modifier(FFLines(size: size, weight: weight, height: height, clip: clip))
  }
}

struct FFLines: ViewModifier {
  let size: CGFloat
  let weight: Font.Weight
  let height: CGFloat?
  let clip: Int?

  func body(content: Content) -> some View {
    let font = UIFont.systemFont(ofSize: size, weight: ffUIWeight(weight))
    let natural = font.lineHeight
    let extra = height.map { size * \$0 - natural } ?? 0
    let ascentShare = font.ascender / (font.ascender - font.descender)
    let spaced = content.lineSpacing(max(extra, 0))
    return Group {
      if let lines = clip {
        spaced
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
          .frame(
            maxHeight: natural * CGFloat(lines) + max(extra, 0) * CGFloat(lines - 1),
            alignment: .top
          )
          .clipped()
      } else {
        spaced
      }
    }
    .padding(.top, extra * ascentShare)
    .padding(.bottom, extra * (1 - ascentShare))
  }
}

private func ffUIWeight(_ weight: Font.Weight) -> UIFont.Weight {
  switch weight {
  case .ultraLight: return .ultraLight
  case .thin: return .thin
  case .light: return .light
  case .medium: return .medium
  case .semibold: return .semibold
  case .bold: return .bold
  case .heavy: return .heavy
  case .black: return .black
  default: return .regular
  }
}

/// A linear progress indicator.
struct FFBarProgress: View {
  let value: Double
  let color: Color
  let track: Color
  let height: CGFloat
  let cornerRadius: CGFloat

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: cornerRadius).fill(track)
        RoundedRectangle(cornerRadius: cornerRadius).fill(color)
          .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
      }
    }
    .frame(height: height)
  }
}
''';

/// `FFCountdownText` for [SwiftCountdownStyle.fullWidth].
const _countdownFullWidth = '''
/// Counts down to [end], stopping at zero.
struct FFCountdownText: View {
  let end: Date?
  @Environment(\\.ffNow) private var now

  var body: some View {
    if let end = end, end > now {
      Text(end, style: .timer)
    } else {
      Text("0:00")
    }
  }
}
''';

/// `FFCountdownText` for [SwiftCountdownStyle.fitted].
const _countdownFitted = '''
/// Counts down to [end], stopping at zero. [alignment] is where the text
/// sits in its width: the text's own alignment.
struct FFCountdownText: View {
  let end: Date?
  var alignment: Alignment = .leading
  @Environment(\\.ffNow) private var now

  /// The widest text the countdown shows from now on, in zeros.
  private func widest(_ end: Date) -> String {
    let seconds = Int(end.timeIntervalSince(now).rounded(.up))
    let hours = seconds / 3600
    if hours > 0 {
      return String(repeating: "0", count: String(hours).count) + ":00:00"
    }
    return String(repeating: "0", count: String(seconds / 60).count) + ":00"
  }

  var body: some View {
    if let end = end, end > now {
      // In a widget or a Live Activity a ticking text takes all the width it
      // is offered, where Flutter's text is as wide as its characters. So
      // the view is as wide as the widest text the countdown will show, and
      // the ticking text is drawn over it, in that width. On a locked or
      // dimmed screen iOS shows a slower form of the text: "9:--" from iOS
      // 16, which fits; before that "9 minutes", which is wider and shrinks
      // to the width instead of being cut.
      Text(widest(end))
        .hidden()
        .overlay(
          ticking(end)
            .lineLimit(1)
            .minimumScaleFactor(0.2),
          alignment: alignment
        )
    } else {
      Text("0:00")
    }
  }

  private func ticking(_ end: Date) -> Text {
    if #available(iOS 16.0, *) {
      return Text(timerInterval: now...end, countsDown: true)
    }
    return Text(end, style: .timer)
  }
}
''';

/// `FFValueImage`: the picture of an Image value, which the host loaded and
/// handed to the layout's view (`images`, see `swiftLayoutViewInit`), else
/// its fallback asset, else a neutral block. Needs `FFAssetImage` and
/// `FFColor`.
///
/// The host hands in a picture small enough to draw: an extension refuses
/// one of about a megapixel and up, so the app shrinks it before storing.
const kNativeLayoutSwiftValueImage = r'''
/// The picture of an Image value. [image] is the picture the host loaded
/// for it; without one the [fallback] asset is drawn, and without that a
/// neutral block.
struct FFValueImage: View {
  let image: UIImage?
  let fallback: String?
  /// .fit, .fill, or nil to stretch.
  let contentMode: ContentMode?

  var body: some View {
    if let image = image {
      if let mode = contentMode {
        Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
      } else {
        Image(uiImage: image).resizable()
      }
    } else if let path = fallback {
      FFAssetImage(path: path, contentMode: contentMode)
    } else {
      FFColor(light: 0xFFE0E3E7, dark: 0xFF2B3238)
    }
  }
}
''';

/// `FFStagesBar` and `FFStage`: a ProgressBar in Stages mode. Needs
/// `FFIconText`.
const kNativeLayoutSwiftStages = r'''
/// One stage of a stages bar: its label and, if it has one, its icon.
struct FFStage {
  let label: String
  var icon: UInt32? = nil
}

/// A progress bar drawn as stages. Stages before [current] are done, the
/// ones after it upcoming; done and current ones take [color]. The tracker
/// icon rides on the current stage, [inside] (0 to 1) of the way along it,
/// in the middle when not given. A done stage's label shows a check mark.
struct FFStagesBar: View {
  let stages: [FFStage]
  /// The current stage as the app sent it: 0 is the first, below 0 none
  /// has started, the number of stages or more all are done.
  let current: Double
  var inside: Double? = nil
  let color: Color
  let upcoming: Color
  let height: CGFloat
  let cornerRadius: CGFloat
  var tracker: UInt32? = nil
  var trackerColor: Color = .white
  var showLabels = true
  var labelSize: CGFloat = 11
  var labelColor: Color = .primary
  var upcomingLabelColor: Color = .secondary

  private let trackerSize: CGFloat = 22

  private var index: Int {
    guard current.isFinite else { return 0 }
    return Int(max(-1, min(current.rounded(.down), Double(stages.count))))
  }

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      ForEach(0..<stages.count, id: \.self) { i in
        VStack(alignment: .leading, spacing: 4) {
          segment(i)
          if showLabels {
            label(i)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func segment(_ i: Int) -> some View {
    let rowHeight = tracker == nil ? height : max(height, trackerSize)
    let along = CGFloat(min(max(inside ?? 0.5, 0), 1))
    return GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(i <= index ? color : upcoming)
          .frame(height: height)
        if i == index, let glyph = tracker {
          ZStack {
            Circle().fill(color)
            FFIconText(codePoint: glyph, size: 14, color: trackerColor)
          }
          .frame(width: trackerSize, height: trackerSize)
          .offset(x: max(0, geometry.size.width - trackerSize) * along)
        }
      }
      .frame(height: rowHeight)
    }
    .frame(height: rowHeight)
  }

  private func label(_ i: Int) -> some View {
    let tint = i <= index ? labelColor : upcomingLabelColor
    return HStack(spacing: 3) {
      if i < index {
        FFIconText(codePoint: 0xe159, size: labelSize, color: color)
      } else if let icon = stages[i].icon {
        FFIconText(codePoint: icon, size: labelSize, color: tint)
      }
      Text(stages[i].label)
        .font(.system(size: labelSize, weight: i == index ? .semibold : .regular))
        .foregroundColor(tint)
        .lineLimit(1)
    }
  }
}
''';
