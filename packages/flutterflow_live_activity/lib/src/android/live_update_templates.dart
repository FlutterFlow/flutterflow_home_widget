import 'package:flutterflow_live_activity/src/android/custom_card_templates.dart';
import 'package:flutterflow_live_activity/src/contract.dart';
import 'package:flutterflow_live_activity/src/spec.dart';

/// The Android files of [app]'s Live Activities, path (relative to the app's
/// root) to content: the Android side of the `ff_live_activity` plugin
/// package (Gradle module, manifest with its permissions, Kotlin plugin).
/// Names, channel and keys come from `contract.dart`.
///
/// Android 16 (API 36) and up: an ongoing notification with
/// `Notification.ProgressStyle` where a progress bar applies, and a request to
/// be promoted to a Live Update. Below 36: an ordinary ongoing notification
/// (`setProgress` / chronometer).
Map<String, String> liveActivityAndroidFiles(LiveActivityApp app) {
  const root = '$kLiveActivityPluginPackagePath/android';
  final kotlinDir = kLiveActivityAndroidKotlinDir;
  return {
    '$root/build.gradle': _buildGradle(),
    '$root/src/main/AndroidManifest.xml': _manifest(),
    '$root/src/main/kotlin/$kotlinDir/$kLiveActivityPluginClass.kt':
        _kotlinPlugin(
          custom: app.hasCustomCards,
          drawing: liveActivityHasDrawnCustomCards(app),
        ),
    ...liveActivityAndroidCustomFiles(app),
  };
}

String _buildGradle() => '''
group '$kLiveActivityAndroidPackage'
version '1.0'

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    namespace '$kLiveActivityAndroidPackage'
    // Notification.ProgressStyle and the promoted-ongoing request are API 36.
    compileSdk 36

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        minSdk 21
    }
}
''';

String _manifest() => '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Merged into the app manifest by the Android Gradle plugin, so the
         generated app manifest needs no edit for this feature. On Android 13+
         the plugin asks for POST_NOTIFICATIONS from `start` (only). -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.POST_PROMOTED_NOTIFICATIONS" />
</manifest>
''';

// The Kotlin below avoids `$` string templates (it concatenates instead) so
// that `$` in this file always means a Dart interpolation from the contract.
String _kotlinPlugin({required bool custom, required bool drawing}) {
  // Hooks for Custom cards. Each is empty without one, so an app with only
  // fixed templates generates the same Kotlin as before Custom existed.
  final cardBody =
      custom
          ? ''' {
        var spec: FFCardSpec? = null
        // Pictures of the card's Image values, by value key, and the source each shows.
        val images = ConcurrentHashMap<String, Bitmap>()
        val imageSigs = ConcurrentHashMap<String, String>()
        val imageSeq = ConcurrentHashMap<String, Int>()
    }'''
          : '';
  final startCall =
      custom
          ? 'startRouted(ctx, manager, call, result)'
          : 'result.success(start(ctx, manager, call))';
  final updateHook =
      custom
          ? '''

        loadImages(ctx, manager, tag, channelId, card, call, false, null)'''
          : '';
  final customMembers = custom ? _customMembers(drawing: drawing) : '';
  final customDecl =
      custom
          ? '''

        var customStd: FFStd? = null
        val drawn = card.spec?.binder != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N'''
          : '';
  final customBranch =
      custom
          ? '''

            "$kLiveActivityCustomTemplateName" -> {
                val spec = card.spec
                if (spec != null) {
                    val std = FFCustomStandard.map(spec, v)
                    customStd = std
                    title = std.title
                    text = std.text
                    subText = std.subText
                    // A drawn card draws its own bar.
                    percent = if (drawn) null else std.percent
                    criticalText = std.chip
                    countdownTo = std.countdown
                }
            }'''
          : '';
  final cardIconExpr =
      custom
          ? '(if (drawn) null else FFCustomStandard.largeIcon(ctx, card.spec, card.images)) ?: card.iconPath?.let { icons[it] }'
          : 'card.iconPath?.let { icons[it] }';
  final stagesStyle =
      custom
          ? '''

            val stagedBy = card.spec?.stages
            val std = customStd
            if (stagedBy != null && std != null) builder.setStyle(FFCustomStandard.stagesStyle(ctx, stagedBy, std, accent))'''
          : '';
  // A count-up shown by the header's chronometer: it ticks on its own.
  final countUpHook =
      custom
          ? '''

        val since = customStd?.countUpFrom
        if (since != null) builder.setWhen(since).setShowWhen(true).setUsesChronometer(true)'''
          : '';
  final promoteCond = custom ? ' && !drawn' : '';
  // Only with a drawn card: the binder types exist only then.
  final drawHook =
      drawing
          ? '''
        val drawSpec = card.spec
        val binder = drawSpec?.binder
        if (drawn && drawSpec != null && binder != null) {
            // Custom drawing: RemoteViews, never promoted.
            val views = RemoteViews(ctx.packageName, binder.layout)
            binder.bind(ctx, views, FFValues(v, drawSpec.defaults))
            (binder as? FFLayoutImageBinder)?.bindImages(ctx, views, card.images)
            builder.setStyle(Notification.DecoratedCustomViewStyle())
            builder.setCustomContentView(views)
            builder.setCustomBigContentView(views)
        }
'''
          : '';
  const progress = LiveActivityTemplate.progress;
  const eta = LiveActivityTemplate.etaTimer;
  const score = LiveActivityTemplate.score;
  const queue = LiveActivityTemplate.queueStatus;
  return '''
package $kLiveActivityAndroidPackage

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.ConcurrentHashMap
${drawing ? 'import android.widget.RemoteViews\n' : ''}
/**
 * Method channel `$kLiveActivityChannelName`: $kLiveActivityMethodIsSupported, $kLiveActivityMethodStart, $kLiveActivityMethodUpdate, $kLiveActivityMethodEnd.
 * Generated from the channel contract; do not edit by hand.
 *
 * Android 16 (API 36) and up: a Live Update, i.e. an ongoing notification that
 * asks to be promoted, with `Notification.ProgressStyle` where a progress bar
 * applies. Below that: an ordinary ongoing notification.
 *
 * One card = one notification, identified by a tag made of the definition key
 * and the optional instance id (a start without an instance id replaces the
 * definition's single card). The card's state is kept in memory so an update
 * can merge only the changed keys.
 *
 * Icons: the status bar (small) icon is always the app's own icon, because
 * Android draws it as a one-colour silhouette. The card's `$kLiveActivityArgIcon` (a Flutter
 * image asset, given on start) is shown in full colour as the notification's
 * large icon, and stays for the card's later updates and its end. It is decoded
 * once per asset, off the main thread, at the large-icon size. With no icon, or
 * one that is missing or cannot be decoded, the card shows the app icon only.
 *
 * Notification permission: on Android 13+ (API 33) the first start that finds
 * POST_NOTIFICATIONS not granted asks for it with the system prompt, then shows
 * the card if it was granted and returns false if not. Nothing else asks
 * (update, end and isSupported never do), there is no settings redirect, and
 * with no foreground Activity start returns false at once. Below API 33 the
 * system grants it implicitly and nothing changes.
 */
class $kLiveActivityPluginClass : FlutterPlugin, ActivityAware,
    MethodChannel.MethodCallHandler, PluginRegistry.RequestPermissionsResultListener {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var flutterAssets: FlutterPlugin.FlutterAssets? = null
    // start calls waiting for the permission dialog (main thread only).
    private val pendingStarts = ArrayList<Pair<MethodCall, MethodChannel.Result>>()
    private var requesting = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterAssets = binding.flutterAssets
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        flutterAssets = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        // The dialog's answer can no longer reach us: answer waiting starts with false.
        requesting = false
        val waiting = ArrayList(pendingStarts)
        pendingStarts.clear()
        waiting.forEach { it.second.success(false) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        requesting = false
        val waiting = ArrayList(pendingStarts)
        pendingStarts.clear()
        val ctx = context
        waiting.forEach { (call, result) ->
            if (ctx == null) {
                result.success(false)
            } else {
                val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                $startCall
            }
        }
        return true
    }

    /** True on API 33+ while POST_NOTIFICATIONS is not granted. */
    private fun needsPermissionPrompt(ctx: Context): Boolean =
        Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(NOTIFICATION_PERMISSION) != PackageManager.PERMISSION_GRANTED

    /** Start, asking for the notification permission first when it is needed and possible. */
    private fun startAskingPermission(ctx: Context, manager: NotificationManager, call: MethodCall, result: MethodChannel.Result) {
        if (tagOf(call) == null || call.argument<String>("$kLiveActivityArgTemplate") == null || !needsPermissionPrompt(ctx)) {
            $startCall
            return
        }
        val host = activity
        if (host == null || host.isFinishing) {
            result.success(false)
            return
        }
        pendingStarts.add(Pair(call, result))
        if (requesting) return
        requesting = true
        try {
            host.requestPermissions(arrayOf(NOTIFICATION_PERMISSION), PERMISSION_REQUEST_CODE)
        } catch (e: RuntimeException) {
            requesting = false
            pendingStarts.remove(Pair(call, result))
            result.success(false)
        }
    }

    private class Card(
        val template: String,
        val accent: String?,
        val channelName: String?,
        val values: MutableMap<String, String>,
        // Flutter asset path of the card's icon, null for the app icon only.
        val iconPath: String?,
    )$cardBody

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context
        if (ctx == null) {
            result.success(if (call.method == "$kLiveActivityMethodEnd") null else false)
            return
        }
        val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        when (call.method) {
            "$kLiveActivityMethodIsSupported" -> result.success(canPost(manager))
            "$kLiveActivityMethodStart" -> startAskingPermission(ctx, manager, call, result)
            "$kLiveActivityMethodUpdate" -> result.success(update(ctx, manager, call))
            "$kLiveActivityMethodEnd" -> {
                end(ctx, manager, call)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun tagOf(call: MethodCall): String? {
        val key = call.argument<String>("$kLiveActivityArgDefinitionKey")
        if (key.isNullOrEmpty()) return null
        val instance = call.argument<String>("$kLiveActivityArgInstanceId")
        return if (instance.isNullOrEmpty()) key else key + "#" + instance
    }

    private fun valuesOf(call: MethodCall): Map<String, String> {
        val raw = call.argument<Map<String, Any?>>("$kLiveActivityArgValues") ?: emptyMap()
        return raw.mapNotNull { (k, v) -> v?.let { k to it.toString() } }.toMap()
    }

    private fun canPost(manager: NotificationManager): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled()

    private fun isShowing(manager: NotificationManager, tag: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return manager.activeNotifications.any { it.id == NOTIFICATION_ID && it.tag == tag }
    }

    private fun start(ctx: Context, manager: NotificationManager, call: MethodCall): Boolean {
        val tag = tagOf(call) ?: return false
        val template = call.argument<String>("$kLiveActivityArgTemplate") ?: return false
        if (!canPost(manager)) return false
        val card = Card(
            template,
            call.argument<String>("$kLiveActivityArgAccentColor"),
            call.argument<String>("$kLiveActivityArgAndroidChannelName"),
            valuesOf(call).toMutableMap(),
            call.argument<String>("$kLiveActivityArgIcon")?.takeIf { it.isNotEmpty() },
        )
        val channelId = ensureChannel(manager, call.argument<String>("$kLiveActivityArgDefinitionKey")!!, card.channelName)
        if (channelId == null) return false
        cards[tag] = card
        manager.notify(tag, NOTIFICATION_ID, build(ctx, channelId, card, true))
        val iconPath = card.iconPath
        if (iconPath != null && !icons.containsKey(iconPath)) {
            // First use of this asset: the card is already up with the app icon;
            // show it again with its own icon once that is decoded.
            loadIcon(ctx, iconPath) {
                if (cards[tag] === card && isShowing(manager, tag)) {
                    manager.notify(tag, NOTIFICATION_ID, build(ctx, channelId, card, true))
                }
            }
        }
        return true
    }

    /**
     * Decodes the Flutter image asset [path] on a background thread and keeps it in
     * [icons]; then runs [then] on the main thread. A missing or undecodable
     * asset is skipped silently and [then] is not run.
     */
    private fun loadIcon(ctx: Context, path: String, then: () -> Unit) {
        val assetKey = flutterAssets?.getAssetFilePathByName(path) ?: return
        val size = try {
            ctx.resources.getDimensionPixelSize(android.R.dimen.notification_large_icon_width)
        } catch (e: RuntimeException) {
            0
        }.let { if (it > 0) it else FALLBACK_ICON_SIZE_PX }
        Thread {
            val bitmap = decodeIcon(ctx, assetKey, size)
            if (bitmap != null) {
                icons[path] = bitmap
                Handler(Looper.getMainLooper()).post(then)
            }
        }.start()
    }

    /** The asset as a bitmap whose longer side is at most [size] pixels; null when it cannot be read. */
    private fun decodeIcon(ctx: Context, assetKey: String, size: Int): Bitmap? =
        try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            ctx.assets.open(assetKey).use { BitmapFactory.decodeStream(it, null, bounds) }
            val longest = Math.max(bounds.outWidth, bounds.outHeight)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
                null
            } else {
                // Decode at a power-of-two fraction first, so a large image never
                // has to be held at full size.
                var sample = 1
                while (longest / (sample * 2) >= size) sample *= 2
                val options = BitmapFactory.Options().apply { inSampleSize = sample }
                val decoded = ctx.assets.open(assetKey).use { BitmapFactory.decodeStream(it, null, options) }
                val decodedLongest = if (decoded == null) 0 else Math.max(decoded.width, decoded.height)
                if (decoded == null || decodedLongest <= size) {
                    decoded
                } else {
                    Bitmap.createScaledBitmap(
                        decoded,
                        Math.max(1, decoded.width * size / decodedLongest),
                        Math.max(1, decoded.height * size / decodedLongest),
                        true,
                    )
                }
            }
        } catch (e: Exception) {
            null
        } catch (e: OutOfMemoryError) {
            null
        }

    private fun update(ctx: Context, manager: NotificationManager, call: MethodCall): Boolean {
        val tag = tagOf(call) ?: return false
        val card = cards[tag] ?: return false
        if (!isShowing(manager, tag)) {
            cards.remove(tag)
            return false
        }
        card.values.putAll(valuesOf(call))
        val channelId = ensureChannel(manager, call.argument<String>("$kLiveActivityArgDefinitionKey")!!, card.channelName)
        if (channelId == null) return false
        manager.notify(tag, NOTIFICATION_ID, build(ctx, channelId, card, true))$updateHook
        return true
    }

    /**
     * `$kLiveActivityDismissalImmediate` (and an absent argument): the card is removed at once.
     * `$kLiveActivityDismissalSystemDefault`: Android has no "linger for a while" for a promoted
     * notification, so the card is re-posted once with the final values as an ordinary,
     * swipeable notification that is no longer ongoing and removes itself after
     * [FINAL_TIMEOUT_MS] (the iOS system default keeps an ended activity for up to
     * four hours). Final values given on an immediate end are not shown.
     */
    private fun end(ctx: Context, manager: NotificationManager, call: MethodCall) {
        val tag = tagOf(call) ?: return
        val card = cards.remove(tag)
        val dismissal = call.argument<String>("$kLiveActivityArgDismissal") ?: "$kLiveActivityDismissalDefault"
        if (card == null || dismissal != "$kLiveActivityDismissalSystemDefault" || !isShowing(manager, tag)) {
            manager.cancel(tag, NOTIFICATION_ID)
            return
        }
        card.values.putAll(valuesOf(call))
        val channelId = ensureChannel(manager, call.argument<String>("$kLiveActivityArgDefinitionKey")!!, card.channelName)
        if (channelId == null) {
            manager.cancel(tag, NOTIFICATION_ID)
            return
        }
        manager.notify(tag, NOTIFICATION_ID, build(ctx, channelId, card, false))
    }

    /** Creates (or renames) the definition's channel; null when the user blocked it. */
    private fun ensureChannel(manager: NotificationManager, definitionKey: String, name: String?): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return CHANNEL_ID_PREFIX
        val id = CHANNEL_ID_PREFIX + "_" + definitionKey
        manager.createNotificationChannel(
            NotificationChannel(
                id,
                if (name.isNullOrBlank()) DEFAULT_CHANNEL_NAME else name,
                // A promoted notification needs at least DEFAULT importance.
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { setSound(null, null) }
        )
        val created = manager.getNotificationChannel(id)
        if (created != null && created.importance == NotificationManager.IMPORTANCE_NONE) return null
        return id
    }

    private fun parseColor(value: String?): Int? =
        try {
            if (value.isNullOrEmpty()) null else Color.parseColor(value)
        } catch (e: IllegalArgumentException) {
            null
        }

    private fun clamp01(value: Double): Double = Math.max(0.0, Math.min(1.0, value))

    private fun build(ctx: Context, channelId: String, card: Card, ongoing: Boolean): Notification {
        val v = card.values
        val accent = parseColor(card.accent)
        val status = v["$kLiveActivityValueStatusText"].orEmpty()

        var title = ""
        var text = ""
        var subText = ""
        // 0..100, or null when the template shows no bar.
        var percent: Int? = null
        var criticalText: String? = null
        var countdownTo: Long? = null$customDecl

        when (card.template) {
            "${progress.wireName}" -> {
                title = v["$kLiveActivityValueTitle"].orEmpty()
                text = status
                val p = clamp01(v["$kLiveActivityValueProgress"]?.toDoubleOrNull() ?: 0.0)
                percent = (p * 100).toInt()
                subText = percent.toString() + "%"
                criticalText = subText
            }
            "${eta.wireName}" -> {
                title = v["$kLiveActivityValueTitle"].orEmpty()
                text = status
                val end = v["$kLiveActivityValueEndTime"]?.toLongOrNull()
                val start = v["$kLiveActivityValueStartTime"]?.toLongOrNull()
                val now = System.currentTimeMillis()
                if (end != null && end > now) countdownTo = end
                if (start != null && end != null && end > start) {
                    // A snapshot as of this post; the bar moves on the next update.
                    percent = (clamp01((now - start).toDouble() / (end - start).toDouble()) * 100).toInt()
                }
            }
            "${score.wireName}" -> {
                val home = v["$kLiveActivityValueHomeName"]?.takeIf { it.isNotEmpty() } ?: "Home"
                val away = v["$kLiveActivityValueAwayName"]?.takeIf { it.isNotEmpty() } ?: "Away"
                val homeScore = v["$kLiveActivityValueHomeScore"] ?: "0"
                val awayScore = v["$kLiveActivityValueAwayScore"] ?: "0"
                title = home + " " + homeScore + " - " + awayScore + " " + away
                text = status
                criticalText = homeScore + "-" + awayScore
            }
            "${queue.wireName}" -> {
                title = v["$kLiveActivityValueTitle"].orEmpty()
                val position = v["$kLiveActivityValuePosition"]
                val wait = v["$kLiveActivityValueEstimatedWaitMinutes"]
                val parts = ArrayList<String>()
                if (position != null) parts.add("Position " + position)
                if (wait != null) parts.add("about " + wait + " min")
                text = parts.joinToString(" · ")
                subText = status
                if (position != null) criticalText = "#" + position
            }$customBranch
        }

        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(ctx, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(ctx)
            }

        // The status bar icon stays the app's own: Android draws it in one colour.
        val icon = if (ctx.applicationInfo.icon != 0) ctx.applicationInfo.icon else android.R.drawable.ic_dialog_info
        builder
            .setSmallIcon(icon)
            // A promoted notification must have a title.
            .setContentTitle(if (title.isEmpty()) " " else title)
            .setContentText(text)
            .setSubText(if (subText.isEmpty()) null else subText)
            .setOngoing(ongoing)
            .setAutoCancel(!ongoing)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(launchIntent(ctx))
        if (accent != null) builder.setColor(accent)
        // The card's own icon, in full colour; absent until decoded, and for good
        // when the card has none or the asset is unreadable.
        val cardIcon = $cardIconExpr
        if (cardIcon != null) builder.setLargeIcon(cardIcon)

        val countdown = countdownTo
        if (countdown != null) {
            builder.setWhen(countdown).setShowWhen(true).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) builder.setChronometerCountDown(true)
        }$countUpHook
        if (!ongoing && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setTimeoutAfter(FINAL_TIMEOUT_MS)
        }

        if (Build.VERSION.SDK_INT >= 36) {
            val bar = percent
            if (bar != null) {
                val segment = Notification.ProgressStyle.Segment(100)
                if (accent != null) segment.setColor(accent)
                builder.setStyle(
                    Notification.ProgressStyle()
                        .setStyledByProgress(true)
                        .setProgressSegments(listOf(segment))
                        .setProgress(bar)
                )
            }$stagesStyle
            // The chip in the status bar shows this text.
            if (criticalText != null && countdown == null) builder.setShortCriticalText(criticalText)
            if (ongoing$promoteCond) {
                // Notification.EXTRA_REQUEST_PROMOTED_ONGOING. The platform Builder
                // has no setter for it in API 36.0; only androidx.core does.
                builder.addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
            }
        } else if (percent != null) {
            builder.setProgress(100, percent, false)
        }
$drawHook        return builder.build()
    }

    private fun launchIntent(ctx: Context): PendingIntent? {
        val intent = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
        val flags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        return PendingIntent.getActivity(ctx, 0, intent, flags)
    }

$customMembers    private companion object {
        const val CHANNEL = "$kLiveActivityChannelName"
        const val NOTIFICATION_PERMISSION = "android.permission.POST_NOTIFICATIONS"
        const val PERMISSION_REQUEST_CODE = 0x4C41
        const val CHANNEL_ID_PREFIX = "ff_live_activity"
        const val DEFAULT_CHANNEL_NAME = "Live updates"
        const val NOTIFICATION_ID = 0x46464C41 // "FFLA"
        const val FINAL_TIMEOUT_MS = 4L * 60 * 60 * 1000
        const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"
        // Used only if the system's large-icon size cannot be read.
        const val FALLBACK_ICON_SIZE_PX = 192

        // Survives the Flutter engine being detached and re-attached.
        val cards = ConcurrentHashMap<String, Card>()

        // Decoded card icons by Flutter asset path, shared by every card that uses one.
        val icons = ConcurrentHashMap<String, Bitmap>()
    }
}
''';
}

/// Members of the plugin class that only an app with a Custom card gets.
String _customMembers({required bool drawing}) {
  // Which two pictures a drawn card keeps: the first two its design shows.
  final capOrder =
      drawing
          ? '''
            val order = (card.spec?.binder as? FFLayoutImageBinder)?.imageKeys ?: emptyList()
            pending.sortBy { (k, _, _) -> order.indexOf(k).let { if (it < 0) Int.MAX_VALUE else it } }
'''
          : '';
  return '''
    private val START_PICTURE_WAIT_MS = 2000L

    private fun imageRequests(call: MethodCall): Map<String, Map<*, *>> {
        val raw = call.argument<Map<String, Any?>>("$kLiveActivityArgImages") ?: return emptyMap()
        return raw.mapNotNull { (k, v) -> (v as? Map<*, *>)?.let { k to it } }.toMap()
    }

    /** Start routing: a Custom card waits up to 2 s for its pictures; any other template starts as before. */
    private fun startRouted(ctx: Context, manager: NotificationManager, call: MethodCall, result: MethodChannel.Result) {
        val template = call.argument<String>("$kLiveActivityArgTemplate")
        if (template != "$kLiveActivityCustomTemplateName") {
            result.success(start(ctx, manager, call))
            return
        }
        val key = call.argument<String>("$kLiveActivityArgDefinitionKey")
        val tag = tagOf(call)
        val spec = if (key == null) null else FFCustomCards.specs[key]
        if (key == null || tag == null || spec == null || !canPost(manager)) {
            result.success(false)
            return
        }
        val card = Card(
            template,
            call.argument<String>("$kLiveActivityArgAccentColor"),
            call.argument<String>("$kLiveActivityArgAndroidChannelName"),
            valuesOf(call).toMutableMap(),
            call.argument<String>("$kLiveActivityArgIcon")?.takeIf { it.isNotEmpty() },
        )
        card.spec = spec
        val channelId = ensureChannel(manager, key, card.channelName)
        if (channelId == null) {
            result.success(false)
            return
        }
        cards[tag] = card
        loadImages(ctx, manager, tag, channelId, card, call, true, result)
    }

    /**
     * Reads the call's pictures off the main thread and shrinks them. On start
     * the card is posted when every picture is in or after 2 s, whichever is
     * first (the fallback shows for a picture that is late); on update the
     * texts were posted already. A picture that arrives later is swapped in.
     * A failed picture changes nothing; a picture set again meanwhile wins.
     */
    private fun loadImages(
        ctx: Context, manager: NotificationManager, tag: String, channelId: String, card: Card,
        call: MethodCall, starting: Boolean, result: MethodChannel.Result?,
    ) {
        val pending = ArrayList<Triple<String, Map<*, *>, String>>()
        for ((k, src) in imageRequests(call)) {
            val sig = FFCardImages.signature(src) ?: continue
            if (card.imageSigs[k] == sig && card.images.containsKey(k)) continue
            card.imageSeq[k] = (card.imageSeq[k] ?: 0) + 1
            pending.add(Triple(k, src, sig))
        }
        // A notification crosses a 1 MB Binder limit. A drawn card holds at most 2 pictures; the standard
        // card shows only the one its Picture slot names.
        if (card.spec?.binder == null) {
            val shown = card.spec?.slots?.get("largeIcon")
            pending.removeAll { (k, _, _) -> k != shown }
        } else {
$capOrder            val held = HashSet<String>(card.images.keys)
            pending.removeAll { (k, _, _) -> if (held.contains(k)) false else if (held.size >= 2) true else { held.add(k); false } }
        }
        var done = !starting
        // False until the card's first post (a start posts it once its pictures are in or 2 s are up).
        var posted = !starting
        fun postNow() {
            if (cards[tag] !== card) return
            if (posted && !isShowing(manager, tag)) return
            manager.notify(tag, NOTIFICATION_ID, build(ctx, channelId, card, true))
            posted = true
        }
        if (pending.isEmpty()) {
            if (starting) {
                done = true
                postNow()
                result?.success(true)
            }
            return
        }
        val main = Handler(Looper.getMainLooper())
        var left = pending.size
        if (starting) {
            main.postDelayed({
                if (!done) {
                    done = true
                    postNow()
                    result?.success(true)
                }
            }, START_PICTURE_WAIT_MS)
        }
        val maxPx = if (card.spec?.binder != null) FFCardImages.CUSTOM_MAX_PX else FFCardImages.LARGE_ICON_PX
        for ((k, src, sig) in pending) {
            val seq = card.imageSeq[k]
            Thread {
                val bitmap = FFCardImages.load(ctx, src, maxPx)
                main.post {
                    left--
                    if (bitmap != null && card.imageSeq[k] == seq) {
                        card.images[k] = bitmap
                        card.imageSigs[k] = sig
                    }
                    if (!done) {
                        if (left == 0) {
                            done = true
                            postNow()
                            result?.success(true)
                        }
                    } else if (bitmap != null) {
                        postNow()
                    }
                }
            }.start()
        }
    }

''';
}
