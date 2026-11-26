/// The Kotlin a native layout's binder needs at run time, as source text.
///
/// `remoteViewsLayout` (remote_views_emitter.dart) writes binders that call
/// these. A module that draws layouts puts each of them in its sources once,
/// in one package with the binders. Home screen widgets and Live Activity
/// cards draw from the same run time.
library;

/// The imports of a file that holds the helpers below: everything they
/// need, and more (the rest is what a home screen widget's provider needs).
const kNativeLayoutKotlinImports = '''
import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.text.SpannableString
import android.text.format.DateUtils
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.text.style.UnderlineSpan
import android.util.SizeF
import android.widget.RemoteViews
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
''';

/// `FFLayoutBinder`: what each layout's generated binder implements.
const kNativeLayoutKotlinBinder = '''
/** The binder of one layout: its layout resource and what it sets. */
internal interface FFLayoutBinder {
    val layout: Int
    fun bind(ctx: Context, views: RemoteViews, v: FFValues)
}
''';

/// `FFValues`: the values a layout reads, decoded per type.
const kNativeLayoutKotlinValues = '''
/**
 * The values the app sent, decoded per type as the channel contract says. A
 * value the app did not send is the parameter's default, else empty.
 */
internal class FFValues(
    private val raw: Map<String, String>,
    private val defaults: Map<String, String>,
    /** Drawn once and never redrawn (the picker preview). */
    val frozen: Boolean = false,
    /** The choice this copy of the widget shows; null for the shared values. */
    val choice: String? = null,
) {
    private fun string(key: String): String? = raw[key] ?: defaults[key]

    fun text(key: String): String = string(key) ?: ""

    fun double(key: String): Double = string(key)?.toDoubleOrNull() ?: 0.0

    fun bool(key: String): Boolean = string(key) == "true"

    fun date(key: String): Long? = string(key)?.toLongOrNull()

    fun color(key: String): Int {
        val hex = string(key) ?: return Color.TRANSPARENT
        if (!hex.startsWith("#")) return Color.TRANSPARENT
        return hex.substring(1).toLongOrNull(16)?.toInt() ?: Color.TRANSPARENT
    }

    // A value as a page's route reads it (the app's `deserializeParam`);
    // null when the widget has no value for it.

    fun routeText(key: String): String? = string(key)

    fun routeDate(key: String): String? = string(key)?.let { "l" + it }

    fun routeColor(key: String): String? {
        val hex = string(key) ?: return null
        if (!hex.startsWith("#") || hex.length != 9) return null
        val argb = hex.substring(1).toLongOrNull(16) ?: return null
        val alpha = (argb shr 24) and 0xFF
        val rgb = String.format(Locale.US, "%06X", argb and 0xFFFFFF)
        if (alpha == 0xFFL) return "#" + rgb
        return String.format(
            Locale.US,
            "rgba(%d, %d, %d, %.3f)",
            (argb shr 16) and 0xFF, (argb shr 8) and 0xFF, argb and 0xFF,
            alpha / 255.0,
        )
    }

    /** Every date among the values in the future. */
    fun futureDates(): List<Long> {
        val now = System.currentTimeMillis()
        return raw.values.mapNotNull { it.toLongOrNull() }.filter { it > 1000000000000L && it > now }
    }
}
''';

/// `FFLayoutViews`: what the binders draw with. Its two tap helpers
/// (`openPage`, `button`) start the home widget plugin's
/// `FFHomeWidgetOpenActivity` and `FFHomeWidgetButtonReceiver`; a module
/// without those passes [taps] false and must not read a layout with taps.
///
/// [cards] adds what a Live Activity card's nodes draw with and a home
/// screen widget's do not: `valueImage` (an Image value's picture) and
/// `stages` (a ProgressBar in Stages mode). Without it the text is a home
/// screen widget's.
String nativeLayoutKotlinViews({bool taps = true, bool cards = false}) {
  if (!cards) {
    return '$_viewsHead${taps ? _viewsTaps : ''}$_viewsDrawing';
  }
  // The object ends with a closing brace on its own line; the additions go
  // in before it (they call its private `decode`, `drawn` and `icon`).
  const close = '}\n';
  assert(_viewsDrawing.endsWith(close));
  final drawing = _viewsDrawing.substring(
    0,
    _viewsDrawing.length - close.length,
  );
  return '$_viewsHead${taps ? _viewsTaps : ''}$drawing\n$_viewsCards$close';
}

/// `FFLayoutImageBinder`: what the binder of a layout that shows Image
/// values also implements.
///
/// The host loads each picture (off the main thread, already shrunk), then
/// builds the card: `bind(ctx, views, v)`, then
/// `bindImages(ctx, views, images)` with the pictures it has, by value key.
/// A value with no picture is left out of the map and draws its fallback.
/// Both are called on every post: `bind` alone leaves the Image values'
/// views empty.
const kNativeLayoutKotlinImageBinder = '''
/** The binder of a layout that shows Image values. */
internal interface FFLayoutImageBinder {
    /** The Image values the layout shows, by key. */
    val imageKeys: List<String>

    /**
     * Draws each Image value: its picture in [images] (by value key), else
     * its fallback asset, else a neutral block.
     */
    fun bindImages(ctx: Context, views: RemoteViews, images: Map<String, Bitmap>)
}
''';

const _viewsCards = '''
    /**
     * Counts up from [start] on its own. Before [start], and when [frozen],
     * it shows fixed text (0:00 before the start: a Chronometer cannot wait
     * for a time, so it starts counting at the next post after it).
     */
    fun countUp(views: RemoteViews, id: Int, start: Long?, frozen: Boolean = false) {
        val elapsed = if (start == null) -1L else System.currentTimeMillis() - start
        if (elapsed >= 0 && !frozen) {
            views.setChronometer(id, SystemClock.elapsedRealtime() - elapsed, null, true)
            if (Build.VERSION.SDK_INT >= 24) views.setChronometerCountDown(id, false)
        } else {
            views.setChronometer(id, SystemClock.elapsedRealtime(), null, false)
            views.setTextViewText(id, DateUtils.formatElapsedTime(maxOf(elapsed, 0L) / 1000))
        }
    }

    /**
     * How far now is between [start] and [end], 0 to 1. Without a start
     * before the end: 1 once the end has passed, else 0. A snapshot: the
     * bar moves when the card is posted again.
     */
    fun timedFraction(start: Long?, end: Long?): Double {
        val now = System.currentTimeMillis()
        if (end == null) return 0.0
        if (start == null || start >= end) return if (end <= now) 1.0 else 0.0
        return ((now - start).toDouble() / (end - start).toDouble()).coerceIn(0.0, 1.0)
    }

    /**
     * The picture of an Image value: [bitmap], which the host loaded, else
     * the [fallback] asset, else the [placeholder] drawable. Sized and
     * fitted as [image] does.
     */
    fun valueImage(
        ctx: Context,
        views: RemoteViews,
        id: Int,
        bitmap: Bitmap?,
        fallback: String?,
        placeholder: Int,
        widthDp: Float,
        heightDp: Float,
        fit: String,
        radiusDp: Float,
    ) {
        if (bitmap != null) {
            val sized = widthDp > 0 && heightDp > 0
            views.setImageViewBitmap(
                id,
                if (sized) drawn(ctx, bitmap, widthDp, heightDp, fit, radiusDp) else bitmap,
            )
        } else if (fallback != null) {
            image(ctx, views, id, fallback, widthDp, heightDp, fit, radiusDp)
        } else {
            views.setImageViewResource(id, placeholder)
        }
    }

    private fun resourceColor(ctx: Context, id: Int): Int =
        if (Build.VERSION.SDK_INT >= 23) ctx.getColor(id) else ctx.resources.getColor(id)

    /**
     * A stages bar. [current] is the current stage as the app sent it: 0 is
     * the first, below 0 none has started, the number of stages or more all
     * are done. Done and current [segments] get [doneDrawable], the others
     * [upcomingDrawable]. [trackers] holds each stage's tracker views (one,
     * or three: start, middle, end); the one on the current stage where
     * [inside] (0 to 1, the middle when null) says shows [trackerIcon].
     * [labels], [icons], [stageIcons] and [texts] are empty when labels are
     * hidden; a done stage's icon is a check mark. Colours are resources.
     */
    fun stages(
        ctx: Context,
        views: RemoteViews,
        current: Double,
        inside: Double?,
        segments: IntArray,
        doneDrawable: Int,
        upcomingDrawable: Int,
        trackers: IntArray,
        trackerIcon: Int,
        labels: IntArray,
        icons: IntArray,
        stageIcons: IntArray,
        texts: Array<String>,
        labelSizeDp: Float,
        doneColor: Int,
        labelColor: Int,
        upcomingLabelColor: Int,
    ) {
        val count = segments.size
        val index = if (current.isNaN()) 0 else Math.floor(current).coerceIn(-1.0, count.toDouble()).toInt()
        val places = if (count == 0) 0 else trackers.size / count
        val along = (inside ?: 0.5).let { if (it.isNaN()) 0.5 else it }
        val place = if (places <= 1) 0 else if (along < 1.0 / 3) 0 else if (along < 2.0 / 3) 1 else 2
        for (i in 0 until count) {
            views.setInt(segments[i], "setBackgroundResource", if (i <= index) doneDrawable else upcomingDrawable)
            for (p in 0 until places) {
                val tracker = trackers[i * places + p]
                val shown = i == index && p == place
                views.setViewVisibility(tracker, if (shown) android.view.View.VISIBLE else android.view.View.GONE)
                if (shown) icon(ctx, views, tracker, trackerIcon, 14f)
            }
            if (labels.isEmpty()) continue
            val color = resourceColor(ctx, if (i <= index) labelColor else upcomingLabelColor)
            val text = SpannableString(texts[i])
            if (i == index && text.length > 0) {
                text.setSpan(
                    android.text.style.StyleSpan(Typeface.BOLD), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                )
            }
            views.setTextViewText(labels[i], text)
            views.setTextColor(labels[i], color)
            val glyph = if (i < index) 0xe159 else stageIcons[i]
            views.setViewVisibility(icons[i], if (glyph == 0) android.view.View.GONE else android.view.View.VISIBLE)
            if (glyph != 0) {
                icon(ctx, views, icons[i], glyph, labelSizeDp)
                tint(views, icons[i], if (i < index) resourceColor(ctx, doneColor) else color)
            }
        }
    }
''';

const _viewsHead = '''
/** What the layouts' binders draw with. */
internal object FFLayoutViews {
    private val bitmaps = HashMap<String, Bitmap>()
    private var iconFont: Typeface? = null

    private fun px(ctx: Context, dp: Float): Int =
        Math.max(1, Math.round(dp * ctx.resources.displayMetrics.density))

''';

const _viewsTaps = '''
    /**
     * A tap on view [id] opens the page at [path] in the app with [params].
     * [key] tells this tap's intent apart from every other widget's.
     */
    fun openPage(
        ctx: Context,
        views: RemoteViews,
        id: Int,
        key: String,
        path: String,
        params: List<Pair<String, String?>>,
        choice: String?,
    ) {
        val given = params.filter { it.second != null }
        val intent = Intent(ctx, FFHomeWidgetOpenActivity::class.java)
            .putExtra(FFHomeWidgetOpenActivity.EXTRA_PATH, path)
            .putExtra(FFHomeWidgetOpenActivity.EXTRA_NAMES, given.map { it.first }.toTypedArray())
            .putExtra(FFHomeWidgetOpenActivity.EXTRA_VALUES, given.map { it.second!! }.toTypedArray())
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        // Copies showing different choices open the page with their own values.
        val code = (key + "/" + (choice ?: "")).hashCode()
        views.setOnClickPendingIntent(id, PendingIntent.getActivity(ctx, code, intent, flags))
    }

    /**
     * A tap on view [id] is a button of widget [widget]: it changes the
     * widget's values in place (see FFHomeWidgetButtonReceiver). [key] tells
     * this tap's intent apart from every other.
     */
    fun button(
        ctx: Context,
        views: RemoteViews,
        id: Int,
        key: String,
        widget: String,
        kind: String,
        value: String,
        step: Double,
        min: Double?,
        max: Double?,
        integer: Boolean,
        choice: String?,
    ) {
        val intent = Intent(ctx, FFHomeWidgetButtonReceiver::class.java)
            .putExtra(FFHomeWidgetButtonReceiver.EXTRA_WIDGET, widget)
            .putExtra(FFHomeWidgetButtonReceiver.EXTRA_KIND, kind)
            .putExtra(FFHomeWidgetButtonReceiver.EXTRA_VALUE, value)
            .putExtra(FFHomeWidgetButtonReceiver.EXTRA_STEP, step)
            .putExtra(FFHomeWidgetButtonReceiver.EXTRA_INTEGER, integer)
        if (min != null) intent.putExtra(FFHomeWidgetButtonReceiver.EXTRA_MIN, min)
        if (max != null) intent.putExtra(FFHomeWidgetButtonReceiver.EXTRA_MAX, max)
        if (choice != null) intent.putExtra(FFHomeWidgetButtonReceiver.EXTRA_CHOICE, choice)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        // Copies showing different choices change their own values.
        val code = (key + "/" + (choice ?: "")).hashCode()
        views.setOnClickPendingIntent(id, PendingIntent.getBroadcast(ctx, code, intent, flags))
    }

''';

const _viewsDrawing = '''
    fun tintBackground(views: RemoteViews, id: Int, color: Int) {
        if (Build.VERSION.SDK_INT >= 31) {
            views.setColorStateList(id, "setBackgroundTintList", ColorStateList.valueOf(color))
        } else {
            views.setInt(id, "setBackgroundColor", color)
        }
    }

    /** Tints a white image, its alpha included, as src_in does. */
    fun tint(views: RemoteViews, id: Int, color: Int) {
        if (Build.VERSION.SDK_INT >= 31) {
            views.setColorStateList(id, "setImageTintList", ColorStateList.valueOf(color))
        } else {
            views.setInt(id, "setColorFilter", color)
        }
    }

    /**
     * Counts down to [end], or shows zero when it has passed. [frozen] (the
     * picker preview, which is never redrawn) shows the time left without
     * ticking. A stopped Chronometer recomputes its text from its base
     * whenever the launcher inflates it, so a stopped one gets fixed text.
     */
    fun countdown(views: RemoteViews, id: Int, end: Long?, frozen: Boolean = false) {
        val remaining = if (end == null) 0L else end - System.currentTimeMillis()
        if (remaining > 0 && !frozen && Build.VERSION.SDK_INT >= 24) {
            views.setChronometer(id, SystemClock.elapsedRealtime() + remaining, null, true)
            views.setChronometerCountDown(id, true)
        } else {
            views.setChronometer(id, SystemClock.elapsedRealtime(), null, false)
            views.setTextViewText(id, DateUtils.formatElapsedTime(maxOf(remaining, 0L) / 1000))
        }
    }

    /**
     * An asset image. With a size ([widthDp] and [heightDp] above zero) it
     * is drawn at that size, fitted ("contain", "cover" or "fill") and with
     * rounded corners, as Flutter draws it; without one the view fits it.
     */
    fun image(
        ctx: Context,
        views: RemoteViews,
        id: Int,
        asset: String,
        widthDp: Float,
        heightDp: Float,
        fit: String,
        radiusDp: Float,
    ) {
        val cacheKey = asset + "@" + widthDp + "x" + heightDp + fit + radiusDp
        val bitmap = bitmaps[cacheKey] ?: decode(ctx, asset)?.let { source ->
            if (widthDp > 0 && heightDp > 0) {
                drawn(ctx, source, widthDp, heightDp, fit, radiusDp)
            } else {
                source
            }
        }
        if (bitmap != null) {
            bitmaps[cacheKey] = bitmap
            views.setImageViewBitmap(id, bitmap)
        }
    }

    /** [text] underlined and/or struck through. */
    fun decorated(text: CharSequence, underline: Boolean, strike: Boolean): CharSequence {
        val spanned = SpannableString(text)
        if (underline) {
            spanned.setSpan(UnderlineSpan(), 0, spanned.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        if (strike) {
            spanned.setSpan(StrikethroughSpan(), 0, spanned.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        return spanned
    }

    /** A Material Icons glyph, white, to be tinted by the view. */
    fun icon(ctx: Context, views: RemoteViews, id: Int, codePoint: Int, sizeDp: Float) {
        val cacheKey = "icon" + codePoint + "@" + sizeDp
        val cached = bitmaps[cacheKey]
        if (cached != null) {
            views.setImageViewBitmap(id, cached)
            return
        }
        val font = iconFont ?: try {
            Typeface.createFromAsset(ctx.assets, "flutter_assets/fonts/MaterialIcons-Regular.otf")
        } catch (e: Exception) {
            null
        }
        iconFont = font
        if (font == null) return
        val size = px(ctx, sizeDp)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = font
            textSize = size.toFloat()
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
        }
        val glyph = String(Character.toChars(codePoint))
        val y = size / 2f - (paint.descent() + paint.ascent()) / 2f
        Canvas(bitmap).drawText(glyph, size / 2f, y, paint)
        bitmaps[cacheKey] = bitmap
        views.setImageViewBitmap(id, bitmap)
    }

    /**
     * An arc covering [value] of a circle, white, to be tinted. It starts
     * [startDeg] degrees clockwise from the top, as percent_indicator's.
     */
    fun ring(
        views: RemoteViews,
        id: Int,
        value: Double,
        sizeDp: Float,
        thicknessDp: Float,
        startDeg: Float,
        ctx: Context,
    ) {
        val size = px(ctx, sizeDp)
        val stroke = px(ctx, thicknessDp).toFloat()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            color = Color.WHITE
        }
        val inset = stroke / 2
        val bounds = RectF(inset, inset, size - inset, size - inset)
        val sweep = (360 * value.coerceIn(0.0, 1.0)).toFloat()
        if (sweep > 0) Canvas(bitmap).drawArc(bounds, -90f + startDeg, sweep, false, paint)
        views.setImageViewBitmap(id, bitmap)
    }

    private fun decode(ctx: Context, asset: String): Bitmap? = try {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.assets.open(asset).use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (Math.max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 600) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        ctx.assets.open(asset).use { BitmapFactory.decodeStream(it, null, options) }
    } catch (e: Exception) {
        null
    }

    /**
     * [source] drawn into a bitmap of the view's size: fitted as Flutter's
     * BoxFit does, then clipped to rounded corners of [radiusDp].
     */
    private fun drawn(
        ctx: Context,
        source: Bitmap,
        widthDp: Float,
        heightDp: Float,
        fit: String,
        radiusDp: Float,
    ): Bitmap {
        val w = px(ctx, widthDp)
        val h = px(ctx, heightDp)
        val output = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val sw = source.width.toFloat()
        val sh = source.height.toFloat()
        val dest = when (fit) {
            "fill" -> RectF(0f, 0f, w.toFloat(), h.toFloat())
            else -> {
                val scale = if (fit == "cover") Math.max(w / sw, h / sh) else Math.min(w / sw, h / sh)
                val dw = sw * scale
                val dh = sh * scale
                RectF((w - dw) / 2f, (h - dh) / 2f, (w + dw) / 2f, (h + dh) / 2f)
            }
        }
        val canvas = Canvas(output)
        val r = radiusDp * ctx.resources.displayMetrics.density
        if (r > 0) {
            val clip = android.graphics.Path().apply {
                addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, android.graphics.Path.Direction.CW)
            }
            canvas.clipPath(clip)
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(source, null, dest, paint)
        return output
    }
}
''';
