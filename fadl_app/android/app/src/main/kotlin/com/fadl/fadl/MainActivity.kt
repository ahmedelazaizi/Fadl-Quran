package com.fadl.fadl

import android.app.Activity
import android.content.Intent
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    private companion object {
        const val PICK_AUDIO = 4092
        const val MAX_IMPORT_BYTES = 50L * 1024 * 1024
    }

    private var picking: MethodChannel.Result? = null
    private var pickingKind = "regular"
    private val sounds get() = File(filesDir, "adhan").apply { mkdirs() }
    private val metadata get() = getSharedPreferences("fadl.adhan.imports", MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fadl/prayer_widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val schedule = call.arguments as? String
                        if (schedule == null) result.error("widget", "Missing schedule", null)
                        else try {
                            JSONObject(schedule)
                            PrayerWidgetReceiver.save(this, schedule)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("widget", e.message, null)
                        }
                    }
                    "clear" -> {
                        PrayerWidgetReceiver.save(this, null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fadl/adhan").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        val events = call.argument<List<Map<String, Any?>>>("events").orEmpty()
                        AdhanScheduler.schedule(this, JSONArray(events.map { JSONObject(it) }))
                        result.success(null)
                    }
                    "cancelAll" -> {
                        AdhanScheduler.schedule(this, JSONArray())
                        result.success(null)
                    }
                    "testAlarm" -> {
                        AdhanScheduler.scheduleTest(this, JSONObject(call.argument<Map<String, Any?>>("event")!!))
                        result.success(null)
                    }
                    "preview" -> {
                        val event = JSONObject()
                            .put("sound", call.argument<String>("soundId") ?: "adhan_default")
                            .put("title", "معاينة الأذان")
                            .put("preview", true)
                        val intent = Intent(this, AdhanService::class.java)
                            .setAction(AdhanService.PLAY).putExtra("event", event.toString())
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(null)
                    }
                    "stopPreview" -> {
                        startService(Intent(this, AdhanService::class.java).setAction(AdhanService.STOP))
                        result.success(null)
                    }
                    "pickAndImport" -> pickAudio(call.argument<String>("kind"), result)
                    "listImported" -> result.success(listImported())
                    "deleteImported" -> {
                        val id = call.argument<String>("id").orEmpty()
                        // Only ids recorded by an import are deletable; ids never contain a path.
                        if (id.isNotEmpty() && metadata.contains(id) && !id.contains('/')) {
                            File(sounds, id).delete()
                            metadata.edit().remove(id).apply()
                        }
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        if (intent.resolveActivity(packageManager) != null) startActivity(intent)
                        else startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null)))
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("adhan", e.message, null)
            }
        }
    }

    private fun listImported(): List<Map<String, String>> =
        metadata.all.mapNotNull { (id, name) ->
            if (File(sounds, id).isFile) {
                mapOf("id" to id, "name" to "$name", "kind" to id.substringBefore('_'))
            } else null
        }.sortedBy { it["name"] }

    private fun pickAudio(kind: String?, result: MethodChannel.Result) {
        if (kind != "fajr" && kind != "regular") {
            result.error("kind", "kind must be fajr or regular", null)
            return
        }
        if (picking != null) {
            result.error("busy", "The picker is already open", null)
            return
        }
        pickingKind = kind
        picking = result
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "audio/*"
            }, PICK_AUDIO)
        } catch (e: Exception) {
            picking = null
            result.error("picker", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_AUDIO) return
        val result = picking ?: return
        picking = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // Cancelled by the user.
            return
        }
        val kind = pickingKind
        // Copying and probing a large file must not block the UI thread.
        Thread {
            try {
                val imported = importAudio(uri, kind)
                runOnUiThread { result.success(imported) }
            } catch (e: Exception) {
                runOnUiThread { result.error("import", e.message ?: "تعذّر استيراد الملف", null) }
            }
        }.start()
    }

    /** Copies the picked document into app-private storage and returns {id, name, kind}. */
    private fun importAudio(uri: Uri, kind: String): Map<String, String> {
        val name = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (cursor.moveToFirst() && column >= 0) cursor.getString(column) else null
        } ?: "ملف صوتي"
        val id = "${kind}_${UUID.randomUUID()}.audio"
        val file = File(sounds, id)
        try {
            val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("تعذّر قراءة الملف")
            input.use { source ->
                file.outputStream().use { target ->
                    val buffer = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val read = source.read(buffer)
                        if (read < 0) break
                        total += read
                        if (total > MAX_IMPORT_BYTES) throw IllegalStateException("الملف أكبر من ٥٠ ميغابايت")
                        target.write(buffer, 0, read)
                    }
                }
            }
            // Reject files MediaPlayer cannot decode; never keep a broken import.
            val probe = MediaPlayer()
            try {
                probe.setDataSource(file.absolutePath)
                probe.prepare()
            } catch (e: Exception) {
                throw IllegalStateException("صيغة الملف الصوتي غير مدعومة")
            } finally {
                probe.release()
            }
            metadata.edit().putString(id, name).apply()
            return mapOf("id" to id, "name" to name, "kind" to kind)
        } catch (e: Exception) {
            file.delete()
            throw e
        }
    }
}
