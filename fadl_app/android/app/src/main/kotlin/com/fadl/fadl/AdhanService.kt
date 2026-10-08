package com.fadl.fadl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import org.json.JSONObject
import java.io.File

/** Notification channels and the non-playing (vibrate / fallback) notifications. */
internal object AdhanNotifications {
    /** Silent channel for the ongoing playback notification; MediaPlayer is the sound. */
    const val PLAYBACK_CHANNEL = "adhan_playback"

    /** Alert channel with the system default sound, used when the adhan is not played. */
    const val ALERT_CHANNEL = "adhan_alert"
    private const val ALERT_ID = 48343

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(PLAYBACK_CHANNEL, "تشغيل الأذان", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "إشعار أثناء رفع الأذان مع زر الإيقاف"
                setSound(null, null)
                enableVibration(false)
            })
        manager.createNotificationChannel(
            NotificationChannel(ALERT_CHANNEL, "تنبيه وقت الصلاة", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "يُستخدم بدل الأذان في الوضع الصامت أو عند تعذّر التشغيل"
                enableVibration(true)
            })
    }

    fun builder(context: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel)
        else @Suppress("DEPRECATION") Notification.Builder(context)

    fun title(event: JSONObject): String =
        event.optString("title").ifEmpty { "حان الآن وقت صلاة " + event.optString("nameAr") }

    fun Notification.Builder.withBody(event: JSONObject): Notification.Builder {
        val body = event.optString("body")
        if (body.isNotEmpty()) setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
        return this
    }

    /**
     * Posts a dismissible notification. [audible] uses the alert channel (default
     * sound, honoured by the ringer mode); otherwise the silent channel.
     */
    fun post(context: Context, event: JSONObject, audible: Boolean, vibrate: Boolean) {
        ensureChannels(context)
        val builder = builder(context, if (audible) ALERT_CHANNEL else PLAYBACK_CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title(event))
            .withBody(event)
            .setContentIntent(AdhanScheduler.openAppIntent(context))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
        if (Build.VERSION.SDK_INT < 26 && audible) {
            @Suppress("DEPRECATION")
            builder.setDefaults(Notification.DEFAULT_ALL).setPriority(Notification.PRIORITY_HIGH)
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(ALERT_ID, builder.build())
        if (vibrate) vibrate(context)
    }

    fun postAlert(context: Context, event: JSONObject, vibrate: Boolean) =
        post(context, event, audible = true, vibrate = vibrate)

    private fun vibrate(context: Context) {
        val pattern = longArrayOf(0, 600, 300, 600, 300, 600)
        @Suppress("DEPRECATION")
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        else @Suppress("DEPRECATION") vibrator.vibrate(pattern, -1)
    }
}

/**
 * Foreground media-playback service that plays the full adhan with alarm
 * audio attributes. Started by [AdhanReceiver] (alarm) or MainActivity (preview).
 */
class AdhanService : Service() {
    companion object {
        const val PLAY = "com.fadl.fadl.PLAY"
        const val STOP = "com.fadl.fadl.STOP"
        private const val NOTIFICATION = 48342
        private const val TAG = "AdhanService"
    }

    private var player: MediaPlayer? = null
    private var focus: Any? = null
    private var current: JSONObject? = null
    private val audio by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> finish(completed = false)
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> player?.takeIf { it.isPlaying }?.pause()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> player?.setVolume(0.3f, 0.3f)
            AudioManager.AUDIOFOCUS_GAIN -> player?.run {
                setVolume(1f, 1f)
                if (!isPlaying) start()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) {
            // Sent with startService() only, so no startForeground() is owed.
            finish(completed = false)
            return START_NOT_STICKY
        }
        val event = try { JSONObject(intent?.getStringExtra("event") ?: "") } catch (_: Exception) { null }
        // startForegroundService() requires startForeground() even when stopping at once.
        try {
            startInForeground(event ?: JSONObject())
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            event?.let { AdhanNotifications.postAlert(this, it, vibrate = true) }
            current = null
            releasePlayer()
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != PLAY || event == null) {
            finish(completed = false)
            return START_NOT_STICKY
        }
        releasePlayer()
        current = event
        val source = resolveSource(event)
        val silent = event.optBoolean("respectSilent") && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL
        if (source == null || silent) {
            // Silent mode respected, or no usable sound (e.g. Fajr without an imported Fajr adhan).
            AdhanNotifications.postAlert(this, event, vibrate = silent)
            finish(completed = false)
            return START_NOT_STICKY
        }
        if (!requestFocus()) {
            AdhanNotifications.postAlert(this, event, vibrate = true)
            finish(completed = false)
            return START_NOT_STICKY
        }
        try {
            play(source)
        } catch (e: Exception) {
            Log.e(TAG, "Playback failed", e)
            AdhanNotifications.postAlert(this, event, vibrate = false)
            finish(completed = false)
        }
        return START_NOT_STICKY
    }

    private fun startInForeground(event: JSONObject) {
        AdhanNotifications.ensureChannels(this)
        val stop = PendingIntent.getService(this, 1, Intent(this, AdhanService::class.java).setAction(STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = with(AdhanNotifications) {
            builder(this@AdhanService, PLAYBACK_CHANNEL)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title(event))
                .withBody(event)
                .setContentIntent(AdhanScheduler.openAppIntent(this@AdhanService))
                .setDeleteIntent(stop)
                .addAction(Notification.Action.Builder(null as Icon?, "إيقاف الأذان", stop).build())
                .setOngoing(true)
                .setCategory(Notification.CATEGORY_ALARM)
                .build()
        }
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION, notification)
        }
    }

    /** Raw resource id or imported file; null when nothing may be played. */
    private fun resolveSource(event: JSONObject): Any? {
        val sound = event.optString("sound")
        val fajr = event.optString("prayer") == "fajr"
        // Bundled adhans (lib/core/adhan_catalog.dart) are res/raw/adhan_*.
        // Only those named adhan_fajr_* carry the Fajr words, and they are
        // for Fajr only.
        val bundled = if (sound.startsWith("adhan_")) {
            resources.getIdentifier(sound, "raw", packageName).takeIf { it != 0 }
        } else {
            null
        }
        if (bundled != null) {
            val preview = event.optBoolean("preview")
            return if (preview || fajr == sound.startsWith("adhan_fajr_")) bundled else null
        }
        val dir = File(filesDir, "adhan").canonicalFile
        val file = File(dir, sound).canonicalFile
        val usable = sound.isNotEmpty() && file.isFile && file.parentFile == dir &&
            (!fajr || sound.startsWith("fajr_"))
        return when {
            usable -> file
            fajr -> null
            // A deleted regular import falls back to the default adhan
            // (defaultAdhanSound in lib/core/adhan_service.dart).
            else -> R.raw.adhan_imadi
        }
    }

    private fun requestFocus(): Boolean {
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focus = request
            audio.requestAudioFocus(request)
        } else {
            focus = focusListener
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
        return granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        val held = focus ?: return
        focus = null
        if (Build.VERSION.SDK_INT >= 26 && held is AudioFocusRequest) audio.abandonAudioFocusRequest(held)
        else @Suppress("DEPRECATION") audio.abandonAudioFocus(focusListener)
    }

    private fun play(source: Any) {
        val mp = MediaPlayer()
        player = mp
        mp.setAudioAttributes(attributes)
        when (source) {
            is Int -> resources.openRawResourceFd(source).use {
                mp.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            is File -> mp.setDataSource(source.absolutePath)
        }
        mp.setOnPreparedListener { if (player === it) it.start() }
        mp.setOnCompletionListener { if (player === it) finish(completed = true) }
        mp.setOnErrorListener { p, what, extra ->
            Log.e(TAG, "MediaPlayer error $what/$extra")
            if (player === p) {
                current?.let { AdhanNotifications.postAlert(this, it, vibrate = false) }
                finish(completed = false)
            }
            true
        }
        mp.prepareAsync()
    }

    private fun releasePlayer() {
        player?.run {
            try { if (isPlaying) stop() } catch (_: Exception) {}
            release()
        }
        player = null
        abandonFocus()
    }

    /** Stops playback; after a completed real adhan, leaves a silent notification (with the dua). */
    private fun finish(completed: Boolean) {
        val event = current
        current = null
        releasePlayer()
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (completed && event != null && !event.optBoolean("preview")) {
            AdhanNotifications.post(this, event, audible = false, vibrate = false)
        }
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}
