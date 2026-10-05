package com.fadl.fadl

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Arms one alarm per adhan event. Events are JSON objects built by
 * lib/core/adhan_service.dart: key, at (epoch ms), prayer, nameAr, title,
 * body, sound, respectSilent.
 */
internal object AdhanScheduler {
    private const val PREFS = "fadl.adhan.alarms"
    private const val EVENTS = "events"
    const val ACTION_FIRE = "com.fadl.fadl.ADHAN"

    fun schedule(context: Context, events: JSONArray) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val previous = JSONArray(prefs.getString(EVENTS, "[]"))
        for (i in 0 until previous.length()) cancel(context, previous.getJSONObject(i))
        // Persist before arming so a reboot can recover the complete schedule.
        prefs.edit().putString(EVENTS, events.toString()).apply()
        for (i in 0 until events.length()) arm(context, events.getJSONObject(i))
    }

    /** One-off alarm (settings "test in one minute"); not persisted. */
    fun scheduleTest(context: Context, event: JSONObject) = arm(context, event)

    /** Re-arms the persisted schedule after reboot, app update or clock change. */
    fun rearm(context: Context) {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(EVENTS, "[]")
        val events = try { JSONArray(stored) } catch (_: Exception) { JSONArray() }
        for (i in 0 until events.length()) {
            try { arm(context, events.getJSONObject(i)) } catch (e: Exception) { Log.e("AdhanScheduler", "rearm", e) }
        }
    }

    private fun fireIntent(context: Context, event: JSONObject): PendingIntent {
        val key = event.getString("key")
        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = ACTION_FIRE
            // A distinct data URI keeps one PendingIntent per event key.
            data = Uri.parse("fadl://adhan/" + Uri.encode(key))
            putExtra("event", event.toString())
        }
        return PendingIntent.getBroadcast(context, key.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun cancel(context: Context, event: JSONObject) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = fireIntent(context, event)
        alarm.cancel(pending)
        pending.cancel()
    }

    private fun arm(context: Context, event: JSONObject) {
        val whenMs = event.getLong("at")
        if (whenMs <= System.currentTimeMillis()) return
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = fireIntent(context, event)
        if (Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()) {
            // Alarm clocks fire on time in Doze and allow starting the
            // foreground service from the background (Android 12+ exemption).
            alarm.setAlarmClock(AlarmManager.AlarmClockInfo(whenMs, openAppIntent(context)), pending)
        } else {
            // Exact-alarm access revoked (Android 12 user setting): the receiver
            // falls back to a plain notification if the service cannot start.
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pending)
        }
    }

    fun openAppIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

/** Re-arms persisted adhan alarms; every listened action is a protected system broadcast. */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) {
            AdhanScheduler.rearm(context)
        }
    }
}

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AdhanScheduler.ACTION_FIRE) return
        val event = intent.getStringExtra("event") ?: return
        val service = Intent(context, AdhanService::class.java).apply {
            action = AdhanService.PLAY
            putExtra("event", event)
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service)
            else context.startService(service)
        } catch (e: Exception) {
            // e.g. ForegroundServiceStartNotAllowedException after an inexact alarm.
            Log.e("AdhanReceiver", "Could not start adhan playback", e)
            try { AdhanNotifications.postAlert(context, JSONObject(event), vibrate = true) }
            catch (inner: Exception) { Log.e("AdhanReceiver", "Fallback notification failed", inner) }
        }
    }
}
