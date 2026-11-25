/// The Swift of the layout nodes that move on their own between updates:
/// the count-up text and the timed progress indicators.
///
/// `swiftLayoutView` (swiftui_emitter.dart) writes views that call these when
/// a layout has a count-up text (`LayoutParamText.countUp`) or a timed
/// progress indicator (`LayoutProgress.isTimed`). An extension that draws
/// such layouts puts this in its sources once, after
/// `nativeLayoutSwiftBuildingBlocks` (it uses `FFBarProgress`,
/// `FFRingProgress` and the `ffNow` environment value).
library;

/// `FFCountUpText`, `FFTimedBarProgress`, `FFTimedRingProgress`.
const kNativeLayoutSwiftTimed = '''
/// Counts up from [start]; 0:00 before it. [alignment] is where the text
/// sits in its width: the text's own alignment.
struct FFCountUpText: View {
  let start: Date?
  var alignment: Alignment = .leading
  @Environment(\\.ffNow) private var now

  /// The text the count shows now, in zeros: the view's width.
  private func widest(_ start: Date) -> String {
    let seconds = max(Int(now.timeIntervalSince(start)), 0)
    let hours = seconds / 3600
    if hours > 0 {
      return String(repeating: "0", count: String(hours).count) + ":00:00"
    }
    return String(repeating: "0", count: String(seconds / 60).count) + ":00"
  }

  var body: some View {
    if let start = start {
      // As FFCountdownText: the view is as wide as its characters and the
      // ticking text is drawn over it, shrunk if it is ever wider.
      Text(widest(start))
        .hidden()
        .overlay(ticking(start).lineLimit(1).minimumScaleFactor(0.2), alignment: alignment)
    } else {
      Text("0:00")
    }
  }

  private func ticking(_ start: Date) -> Text {
    if #available(iOS 16.0, *) {
      // Stays at 0:00 until the start, then counts up.
      return Text(timerInterval: start...Date.distantFuture, countsDown: false)
    }
    return start <= now ? Text(start, style: .timer) : Text("0:00")
  }
}

/// How far [now] is between two dates, 0 to 1. Without a start before the
/// end: 1 once the end has passed, else 0.
private func ffTimedFraction(_ start: Date?, _ end: Date?, _ now: Date) -> Double {
  guard let end = end else { return 0 }
  guard let start = start, start < end else { return end <= now ? 1 : 0 }
  return min(max(now.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
}

/// A linear progress indicator that fills from [start] to [end] on its own:
/// the system redraws it, so it moves with no update from the app.
struct FFTimedBarProgress: View {
  let start: Date?
  let end: Date?
  let color: Color
  let track: Color
  let height: CGFloat
  let cornerRadius: CGFloat
  @Environment(\\.ffNow) private var now

  var body: some View {
    if #available(iOS 16.0, *), let start = start, let end = end, start < end, now < end {
      // Only the system's own bar moves between updates. It is 4 points
      // tall, so it is stretched to the height and cut to the corners.
      ProgressView(
        timerInterval: start...end,
        countsDown: false,
        label: { EmptyView() },
        currentValueLabel: { EmptyView() }
      )
      .progressViewStyle(.linear)
      .tint(color)
      .scaleEffect(x: 1, y: height / 4, anchor: .center)
      .frame(height: height)
      .background(track)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    } else {
      FFBarProgress(
        value: ffTimedFraction(start, end, now),
        color: color, track: track, height: height, cornerRadius: cornerRadius
      )
    }
  }
}

/// A circular progress indicator that fills from [start] to [end] on its
/// own. While it moves it is the system's ring: its stroke is the system's,
/// not [thickness], and it starts at the top.
struct FFTimedRingProgress: View {
  let start: Date?
  let end: Date?
  let color: Color
  let track: Color
  let diameter: CGFloat
  let thickness: CGFloat
  var startAngle: Double = 0
  @Environment(\\.ffNow) private var now

  var body: some View {
    if #available(iOS 16.0, *), let start = start, let end = end, start < end, now < end {
      ProgressView(
        timerInterval: start...end,
        countsDown: false,
        label: { EmptyView() },
        currentValueLabel: { EmptyView() }
      )
      .progressViewStyle(.circular)
      .tint(color)
      .frame(width: diameter, height: diameter)
    } else {
      FFRingProgress(
        value: ffTimedFraction(start, end, now),
        color: color, track: track, diameter: diameter, thickness: thickness,
        startAngle: startAngle
      )
    }
  }
}
''';
