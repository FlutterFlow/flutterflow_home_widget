import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';
import 'package:flutterflow_native_layout/flutterflow_native_layout.dart';

// The Android side of Custom Live Activity cards: a per-card spec table
// (standard Live Update slot mapping, stages bar, image fallbacks), the
// runtime image loader, and for a card with Custom drawing its RemoteViews
// layout, resources and binder.
//
// The wire is the channel contract's "Custom cards" section: start carries
// `kLiveActivityCustomTemplateName` as the template and the card's values as
// strings; `kLiveActivityArgImages` holds the Image values' sources,
// `{valueKey: {url | path | bytes | asset: ...}}`.

/// Whether a Custom card of [app] is drawn by its own layout on Android
/// (Custom drawing, and a design it can draw). The plugin's drawing code is
/// emitted only then: it needs the layout runtime, which an app whose cards
/// all use the standard Live Update does not get.
bool liveActivityHasDrawnCustomCards(LiveActivityApp app) =>
    app.customCards.any((card) => _drawing(card, const {}) != null);

const _root = '$kLiveActivityPluginPackagePath/android/src/main';

String _ks(String value) => '"${escapeEach(value, kKotlinStringEscapes)}"';

String _argb(int argb) =>
    '0x${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}.toInt()';

/// The Lock Screen layout of [definition] as Android's Custom drawing reads
/// it, or null when the card is not set to Custom drawing or has no Lock
/// Screen layout.
NativeLayoutModel? _drawingModel(LiveActivityDefinition definition) =>
    definition.android.presentation == LiveActivityAndroidPresentation.custom
        ? definition.surfaces[LiveActivitySurface.lockScreen]
        : null;

/// The key of the first widget of [definition]'s Lock Screen layout whose
/// tap opens a page, when that tap is why a card set to Custom drawing is
/// shown as the Standard Live Update on Android instead. Null when the card
/// keeps its drawing, is not set to Custom drawing, or has no layout.
String? liveActivityAndroidTapDroppingDrawing(
  LiveActivityDefinition definition,
) {
  final model = _drawingModel(definition);
  if (model == null || model.root == null || model.taps.isEmpty) {
    return null;
  }
  // The tap of the design's top widget is the tap on the whole card.
  return model.tap != null
      ? model.root!.nodeKey
      : model.nodes.firstWhere((node) => node.tap != null).nodeKey;
}

/// The Lock Screen layout of [definition] as RemoteViews, or null when the
/// card does not use Custom drawing, cannot (it has taps) or has no layout.
({RemoteViewsLayout layout, String tag})? _drawing(
  LiveActivityDefinition definition,
  Map<String, String> defaults,
) {
  final model = _drawingModel(definition);
  // Taps need the home widget plugin's activity and receiver; not in a card.
  if (model == null || model.root == null || model.taps.isNotEmpty) {
    return null;
  }
  final tag = definition.nativeKey.toLowerCase();
  return (
    layout: remoteViewsLayout(
      'la_$tag',
      model,
      defaults: defaults,
      widgetKey: definition.key,
      rootMode: const LayoutRootMode(fitHeight: true, background: false),
    ),
    tag: tag,
  );
}

/// What the standard Live Update of [definition] takes from the timed
/// widgets of its Lock Screen layout.
///
/// - [countUp]: the value in the countdown place is shown by the design as a
///   count-up text (and nowhere as a countdown), so the header's chronometer
///   counts up from it.
/// - [timedStart] / [timedEnd]: the dates of the design's first progress
///   bar when that bar is timed. The standard bar shows how far now is
///   between them, worked out each time the card is posted. Only when the
///   card names no value for the bar itself and has no Stages bar; null
///   otherwise.
({bool countUp, String? timedStart, String? timedEnd})
liveActivityAndroidStandardTimed(LiveActivityDefinition definition) {
  const none = (countUp: false, timedStart: null, timedEnd: null);
  final model = definition.surfaces[LiveActivitySurface.lockScreen];
  if (model == null) {
    return none;
  }
  final texts =
      model.nodes
          .whereType<LayoutTextNode>()
          .map((text) => text.content)
          .whereType<LayoutParamText>()
          .toList();
  final shown =
      definition.androidSlotValues[LiveActivityAndroidSlot.countdown]?.key;
  final countUp =
      shown != null &&
      texts.any((t) => t.paramKey == shown && t.isCountUp) &&
      !texts.any((t) => t.paramKey == shown && t.isCountdown);
  // The standard bar follows the design's first bar: timed when that one is.
  final bars = model.nodes.whereType<LayoutProgress>().toList();
  final first = bars.firstOrNull;
  final timed =
      first != null &&
      first.isTimed &&
      !definition.android.slots.containsKey(LiveActivityAndroidSlot.progress) &&
      !bars.any((bar) => bar.stages != null);
  return (
    countUp: countUp,
    timedStart: timed ? first.timedStart : null,
    timedEnd: timed ? first.timedEnd : null,
  );
}

String _stagesSpec(NativeLayoutModel? model) {
  final spec = model?.stagesSpecs.firstOrNull;
  if (spec == null) {
    return 'null';
  }
  String list(Iterable<String> items) => 'listOf(${items.map(_ks).join(', ')})';
  final done = spec.doneArgb;
  final upcoming = spec.upcomingArgb;
  return 'FFStagesSpec(${list(spec.labels)}, '
      '${list(spec.labelParamKeys)}, '
      '${_ks(spec.currentParamKey)}, '
      '${_ks(spec.progressParamKey)}, '
      '${spec.trackerCodePoint}, '
      '${done == null ? 'null' : _argb(done)}, '
      '${upcoming == null ? 'null' : _argb(upcoming)}, ${spec.hideLabels})';
}

/// Files of the custom half, path to content; empty without a Custom card.
Map<String, String> liveActivityAndroidCustomFiles(LiveActivityApp app) {
  final cards = app.customCards;
  if (cards.isEmpty) {
    return {};
  }
  final files = <String, String>{};
  final drawables = <String, String>{};
  final colors = <String, LayoutColor>{};
  final binders = StringBuffer();
  final specs = <String>[];
  var anyDrawing = false;
  for (final card in cards) {
    final key = card.key;
    final defaults = card.androidValueDefaults;
    final imageFallbacks = card.imageFallbacks;
    final drawing = _drawing(card, defaults);
    String binderRef = 'null';
    if (drawing != null) {
      anyDrawing = true;
      final layout = drawing.layout;
      files['$_root/res/layout/${layout.layoutName}.xml'] = layout.xml;
      drawables.addAll(layout.drawables);
      colors.addAll(layout.colors);
      binders.write(layout.binder);
      binderRef = kotlinBinderName('la_${drawing.tag}');
    }
    final slots = card.androidSlotValues;
    final model = card.surfaces[LiveActivitySurface.lockScreen];
    final timed = liveActivityAndroidStandardTimed(card);
    String map(Map<String, String> entries) =>
        'mapOf(${entries.entries.map((e) => '${_ks(e.key)} to ${_ks(e.value)}').join(', ')})';
    specs.add(
      '        ${_ks(key)} to FFCardSpec(\n'
      '            ${map({for (final e in slots.entries) e.key.name: e.value.key})},\n'
      '            ${map(defaults)},\n'
      '            ${map(imageFallbacks)},\n'
      '            ${_stagesSpec(model)},\n'
      '            $binderRef,\n'
      '            ${timed.countUp},\n'
      '            ${timed.timedStart == null ? 'null' : _ks(timed.timedStart!)},\n'
      '            ${timed.timedEnd == null ? 'null' : _ks(timed.timedEnd!)},\n'
      '        )',
    );
  }
  files['$_root/kotlin/$kLiveActivityAndroidKotlinDir/FFLiveActivityCustom.kt'] =
      _customKotlin(specs, binders.toString(), anyDrawing);
  if (anyDrawing) {
    for (final entry in drawables.entries) {
      files['$_root/res/drawable/${entry.key}.xml'] = entry.value;
    }
    files['$_root/res/values/ff_live_activity_colors.xml'] =
        remoteViewsColorResources(colors, night: false);
    files['$_root/res/values-night/ff_live_activity_colors.xml'] =
        remoteViewsColorResources(colors, night: true);
  }
  return files;
}

String _customKotlin(List<String> specs, String binders, bool anyDrawing) => '''
package $kLiveActivityAndroidPackage

${_imports(anyDrawing)}

/**
 * Custom Live Activity cards, generated: what each card's standard Live Update
 * shows, its stages bar, the fallback picture of each Image value and, for a
 * card with Custom drawing, its RemoteViews binder. Do not edit by hand.
 */
internal class FFStagesSpec(
    val labels: List<String>,
    // Card value that supplies a stage's label, or empty for the fixed text.
    val labelKeys: List<String>,
    val currentKey: String,
    val progressKey: String,
    val trackerCodePoint: Int,
    val doneColor: Int?,
    val upcomingColor: Int?,
    val hideLabels: Boolean,
)

internal class FFCardSpec(
    // Standard Live Update slot (title, text, progress, countdown, shortText, largeIcon) to card value key.
    val slots: Map<String, String>,
    // Default of every non-image value, by key.
    val defaults: Map<String, String>,
    // Flutter asset path of every Image value's fallback, by key.
    val imageFallbacks: Map<String, String>,
    val stages: FFStagesSpec?,
    // Custom drawing; null for the standard Live Update only.
    val binder: ${anyDrawing ? 'FFLayoutBinder' : 'Any'}?,
    // The countdown place's value counts up from its date instead.
    val countUp: Boolean,
    // The dates the standard bar fills between; null when it shows a value.
    val timedStartKey: String?,
    val timedEndKey: String?,
)

internal object FFCustomCards {
    val specs: Map<String, FFCardSpec> = mapOf(
${specs.join(',\n')}
    )
}

/** What the standard Live Update shows for one card, from its values. */
internal class FFStd(
    val title: String,
    val text: String,
    val subText: String,
    // 0..100 for a plain bar, null when the card has none.
    val percent: Int?,
    val chip: String?,
    val countdown: Long?,
    // The date the header counts up from; null when it does not.
    val countUpFrom: Long?,
    val stageIndex: Int,
    // stageIndex * 100 + inside the stage, 0 without stages.
    val stageProgress: Int,
)

internal object FFCustomStandard {
    private fun value(spec: FFCardSpec, v: Map<String, String>, key: String?): String? {
        if (key.isNullOrEmpty()) return null
        return v[key] ?: spec.defaults[key]
    }

    fun map(spec: FFCardSpec, v: Map<String, String>): FFStd {
        fun slot(name: String): String? = value(spec, v, spec.slots[name])
        val progress = slot("progress")?.toDoubleOrNull()?.let { Math.max(0.0, Math.min(1.0, it)) }
        val end = slot("countdown")?.toLongOrNull()
        val now = System.currentTimeMillis()
        var chip = slot("shortText")
        var sub = ""
        var percent = progress?.let { (it * 100).toInt() }
        var stage = -1
        var stageProgress = 0
        val stages = spec.stages
        if (stages == null && spec.timedEndKey != null) {
            // A snapshot as of this post: the bar moves on the next update.
            val from = value(spec, v, spec.timedStartKey)?.toLongOrNull()
            val to = value(spec, v, spec.timedEndKey)?.toLongOrNull()
            percent = when {
                to == null -> 0
                from == null || from >= to -> if (to <= now) 100 else 0
                else -> (Math.max(0.0, Math.min(1.0, (now - from).toDouble() / (to - from).toDouble())) * 100).toInt()
            }
        }
        if (stages != null) {
            val n = stages.labels.size
            val current = value(spec, v, stages.currentKey)?.toIntOrNull() ?: 0
            stage = Math.max(-1, Math.min(n, current))
            val inside = value(spec, v, stages.progressKey)?.toDoubleOrNull()?.let { Math.max(0.0, Math.min(1.0, it)) } ?: 0.5
            val shown = Math.max(0, Math.min(n - 1, stage))
            stageProgress = if (stage < 0) 0 else if (stage >= n) n * 100 else shown * 100 + (inside * 100).toInt()
            percent = stageProgress / n
            if (stage in 0 until n && !stages.hideLabels) {
                val label = value(spec, v, stages.labelKeys[shown]).takeIf { !stages.labelKeys[shown].isEmpty() } ?: stages.labels[shown]
                sub = label
                if (chip == null) chip = label
            }
        }
        return FFStd(
            slot("title").orEmpty(),
            slot("text").orEmpty(),
            sub,
            percent,
            chip,
            if (!spec.countUp && end != null && end > now) end else null,
            // Before its date the header shows no time: it starts at the next post after it.
            if (spec.countUp && end != null && end <= now) end else null,
            stage,
            stageProgress,
        )
    }

    /** The picture slot's bitmap: the sent one, else the value's fallback asset. */
    fun largeIcon(ctx: Context, spec: FFCardSpec?, images: Map<String, Bitmap>): Bitmap? {
        val key = spec?.slots?.get("largeIcon") ?: return null
        return images[key] ?: spec.imageFallbacks[key]?.let { FFCardImages.fallback(ctx, it, FFCardImages.LARGE_ICON_PX) }
    }

    /** API 36: the stages as ProgressStyle segments, points and a tracker. */
    fun stagesStyle(ctx: Context, stages: FFStagesSpec, std: FFStd, accent: Int?): Notification.ProgressStyle {
        val on = stages.doneColor ?: accent ?: Color.BLUE
        val off = stages.upcomingColor ?: 0xFFB8C0CC.toInt()
        val n = stages.labels.size
        val segments = (0 until n).map { i ->
            Notification.ProgressStyle.Segment(100).setColor(if (i <= std.stageIndex) on else off)
        }
        val points = (1 until n).map { i ->
            Notification.ProgressStyle.Point(i * 100).setColor(if (i <= std.stageIndex) on else off)
        }
        val style = Notification.ProgressStyle()
            .setStyledByProgress(false)
            .setProgressSegments(segments)
            .setProgressPoints(points)
            .setProgress(std.stageProgress)
        if (stages.trackerCodePoint != 0) {
            val glyph = glyph(ctx, stages.trackerCodePoint, 96, Color.BLACK, on)
            if (glyph != null) style.setProgressTrackerIcon(Icon.createWithBitmap(glyph))
        }
        return style
    }

    private var iconFont: Typeface? = null

    private fun glyph(ctx: Context, codePoint: Int, px: Int, color: Int, disc: Int): Bitmap? {
        val font = iconFont ?: try {
            Typeface.createFromAsset(ctx.assets, "flutter_assets/fonts/MaterialIcons-Regular.otf")
        } catch (e: Exception) {
            null
        } ?: return null
        iconFont = font
        val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = disc
        canvas.drawCircle(px / 2f, px / 2f, px / 2f, paint)
        val size = px * 0.62f
        paint.color = color
        paint.typeface = font
        paint.textSize = size
        paint.textAlign = Paint.Align.CENTER
        canvas.drawText(String(Character.toChars(codePoint)), px / 2f, px / 2f + size / 2f, paint)
        return bmp
    }
}

/**
 * Runtime pictures: a source (url, local file, bytes or Flutter asset) is read
 * off the main thread and shrunk so a notification stays far below the 1 MB
 * Binder limit.
 */
internal object FFCardImages {
    const val LARGE_ICON_PX = 256
    const val CUSTOM_MAX_PX = 384
    private const val URL_TIMEOUT_MS = 5000
    private const val MAX_DOWNLOAD_BYTES = 20 * 1024 * 1024

    private val fallbacks = ConcurrentHashMap<String, Bitmap>()

    /** Same source, same signature; null for an unusable source. */
    fun signature(source: Map<*, *>): String? {
        (source["url"] as? String)?.let { return "url:" + it }
        (source["path"] as? String)?.let { return "path:" + it }
        (source["asset"] as? String)?.let { return "asset:" + it }
        (source["bytes"] as? ByteArray)?.let { return "bytes:" + it.size + ":" + java.util.Arrays.hashCode(it) }
        return null
    }

    /** Blocking; call off the main thread. Null when the source cannot be read. */
    fun load(ctx: Context, source: Map<*, *>, maxPx: Int): Bitmap? =
        try {
            val url = source["url"] as? String
            val path = source["path"] as? String
            val asset = source["asset"] as? String
            val bytes = source["bytes"] as? ByteArray
            when {
                url != null -> decode(download(url), maxPx)
                path != null -> decode(java.io.File(path).readBytes(), maxPx)
                asset != null -> decode(ctx.assets.open("flutter_assets/" + asset).use { it.readBytes() }, maxPx)
                bytes != null -> decode(bytes, maxPx)
                else -> null
            }
        } catch (e: Exception) {
            null
        } catch (e: OutOfMemoryError) {
            null
        }

    /** The value's fallback asset, decoded once per size. */
    fun fallback(ctx: Context, asset: String, maxPx: Int): Bitmap? {
        val cacheKey = asset + "@" + maxPx
        fallbacks[cacheKey]?.let { return it }
        val bitmap = load(ctx, mapOf("asset" to asset), maxPx) ?: return null
        fallbacks[cacheKey] = bitmap
        return bitmap
    }

    private fun download(url: String): ByteArray {
        if (!url.startsWith("https://") && !url.startsWith("http://")) throw IllegalArgumentException("scheme")
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = URL_TIMEOUT_MS
        connection.readTimeout = URL_TIMEOUT_MS
        try {
            val out = java.io.ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    out.write(buffer, 0, n)
                    if (out.size() > MAX_DOWNLOAD_BYTES) throw IllegalStateException("too large")
                }
            }
            return out.toByteArray()
        } finally {
            connection.disconnect()
        }
    }

    /** [bytes] as a bitmap whose longer side is at most [maxPx]; never holds the full-size bitmap. */
    private fun decode(bytes: ByteArray, maxPx: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (Math.max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxPx) sample *= 2
        val rough = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: return null
        val longest = Math.max(rough.width, rough.height)
        if (longest <= maxPx) return rough
        val scale = maxPx.toFloat() / longest
        return Bitmap.createScaledBitmap(
            rough,
            Math.max(1, Math.round(rough.width * scale)),
            Math.max(1, Math.round(rough.height * scale)),
            true,
        )
    }
}
${anyDrawing ? _drawingRuntime(binders) : ''}''';

String _drawingRuntime(String binders) => '''

$kNativeLayoutKotlinBinder
$kNativeLayoutKotlinImageBinder
$kNativeLayoutKotlinValues
${nativeLayoutKotlinViews(taps: false, cards: true)}
$binders
''';

/// The imports of the Kotlin file, each once (a repeated one is an error): its
/// own, and the layout runtime's when a card has Custom drawing.
String _imports(bool anyDrawing) {
  final lines = <String>{
    'import android.app.Notification',
    'import android.content.Context',
    'import android.graphics.Bitmap',
    'import android.graphics.BitmapFactory',
    'import android.graphics.Canvas',
    'import android.graphics.Color',
    'import android.graphics.Paint',
    'import android.graphics.Typeface',
    'import android.graphics.drawable.Icon',
    'import java.net.HttpURLConnection',
    'import java.net.URL',
    'import java.util.concurrent.ConcurrentHashMap',
    if (anyDrawing) 'import android.view.View',
    if (anyDrawing) ...kNativeLayoutKotlinImports.trim().split('\n'),
  };
  return (lines.toList()..sort()).join('\n');
}
