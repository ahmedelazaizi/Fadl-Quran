package com.fadl.fadl

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** Renders a precomputed offline calendar saved by the Flutter prayer engine. */
class PrayerWidgetReceiver : AppWidgetProvider() {
    companion object {
        private const val PREFS = "fadl.prayer.widget"
        private const val SCHEDULE = "schedule"
        private const val REFRESH = "com.fadl.fadl.WIDGET_REFRESH"

        fun save(context: Context, schedule: String?) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            prefs.edit().apply {
                if (schedule == null) remove(SCHEDULE) else putString(SCHEDULE, schedule)
            }.commit()
            refresh(context)
        }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, PrayerWidgetReceiver::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) {
                cancelAlarm(context)
                return
            }
            val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(SCHEDULE, null)
            val schedule = try { stored?.let(::JSONObject) } catch (e: org.json.JSONException) {
                Log.e("PrayerWidget", "Invalid saved schedule", e)
                null
            }
            val now = System.currentTimeMillis()
            val upcoming = nextEvent(schedule, now)
            val zone = TimeZone.getTimeZone(schedule?.optString("timezone", "UTC"))
            val dateKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
                timeZone = zone
            }.format(Date(now))
            val hijri = schedule?.optJSONObject("dates")?.optString(dateKey).orEmpty()
            for (id in ids) {
                val options = manager.getAppWidgetOptions(id)
                val expanded = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= 200 &&
                    options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 75
                val views = RemoteViews(context.packageName,
                    if (expanded) R.layout.prayer_widget_large else R.layout.prayer_widget_small)
                views.setTextViewText(R.id.widget_prayer,
                    upcoming?.optString("name") ?: "حدد موقعك في فضل")
                views.setTextViewText(R.id.widget_time, upcoming?.optString("local") ?: "--:--")
                views.setTextViewText(R.id.widget_hijri, hijri)
                val whenMs = upcoming?.optLong("at") ?: 0L
                if (whenMs > now && Build.VERSION.SDK_INT >= 24) {
                    views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                    views.setChronometer(R.id.widget_countdown,
                        SystemClock.elapsedRealtime() + (whenMs - now), "%s", true)
                    views.setChronometerCountDown(R.id.widget_countdown, true)
                } else {
                    views.setViewVisibility(R.id.widget_countdown, View.GONE)
                }
                views.setOnClickPendingIntent(R.id.widget_root, AdhanScheduler.openAppIntent(context))
                manager.updateAppWidget(id, views)
            }
            val midnight = Calendar.getInstance(zone).apply {
                timeInMillis = now
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val nextBoundary = listOfNotNull(upcoming?.optLong("at")?.takeIf { it > now }, midnight).minOrNull()!!
            arm(context, nextBoundary)
        }

        private fun nextEvent(schedule: JSONObject?, now: Long): JSONObject? {
            val prayers = schedule?.optJSONArray("prayers") ?: return null
            for (index in 0 until prayers.length()) {
                val prayer = prayers.optJSONObject(index) ?: continue
                if (prayer.optLong("at") > now) return prayer
            }
            return null
        }

        private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, 61012, Intent(context, PrayerWidgetReceiver::class.java).setAction(REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun cancelAlarm(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(alarmIntent(context))
        }

        private fun arm(context: Context, at: Long) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = alarmIntent(context)
            alarm.cancel(pending)
            if (Build.VERSION.SDK_INT < 31 || alarm.canScheduleExactAlarms()) {
                alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            } else {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) = refresh(context)

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle
    ) = refresh(context)

    override fun onDisabled(context: Context) = cancelAlarm(context)

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in setOf(REFRESH, Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_LOCALE_CHANGED,
                Intent.ACTION_CONFIGURATION_CHANGED)) {
            refresh(context)
        }
    }
}
