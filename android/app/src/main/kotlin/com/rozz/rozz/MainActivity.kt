package com.rozz.rozz

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.os.Bundle
import android.os.Build
import android.database.Cursor
import android.provider.Settings
import android.provider.Telephony
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rozz/sms"
    private val SECURITY_CHANNEL = "com.rozz/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInbox" -> Thread {
                    result.success(getInboxMessages())
                }.start()
                "isNotificationAccessGranted" -> result.success(isNotificationAccessGranted())
                "openNotificationAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "isDefaultSmsHandler" -> result.success(isDefaultSmsHandler())
                "requestDefaultSmsRole" -> {
                    val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                        putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                    }
                    startActivity(intent)
                    result.success(isDefaultSmsHandler())
                }
                else -> result.notImplemented()
            }
        }

        // Security channel: root detection
        val securityChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
        securityChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // checkRooted() spawns a process — keep it off the platform
                // (main) thread to avoid an ANR.
                "isDeviceRooted" -> Thread {
                    runOnUiThread { result.success(checkRooted()) }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun checkRooted(): Boolean {
        try {
            // Check for common root binaries
            val rootPaths = arrayOf(
                "/system/app/Superuser.apk",
                "/system/bin/su",
                "/system/xbin/su",
                "/sbin/su",
                "/data/local/xbin/su",
                "/data/local/bin/su",
                "/system/sd/xbin/su",
                "/system/bin/failsafe/su",
                "/data/local/su",
                "/su/bin/su",
                "/system/app/SuperSU.apk",
                "/system/app/Manager.apk"
            )
            for (path in rootPaths) {
                if (File(path).exists()) return true
            }
            // Check for test-keys build
            val buildTags = Build.TAGS
            if (buildTags != null && buildTags.contains("test-keys")) return true
            // Try to execute "su" — throws if not available
            val process = Runtime.getRuntime().exec(arrayOf("which", "su"))
            val reader = process.inputStream.bufferedReader()
            val result = reader.readLine()
            reader.close()
            if (result != null && result.contains("/su")) return true
        } catch (_: Exception) {
            // Exception = su not found = not rooted (safe)
        }
        return false
    }

    private fun isDefaultSmsHandler(): Boolean =
        Telephony.Sms.getDefaultSmsPackage(this) == packageName

    private fun isNotificationAccessGranted(): Boolean {
        val expected = ComponentName(this, SmsNotificationListener::class.java)
        return if (Build.VERSION.SDK_INT >= 33) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.isNotificationListenerAccessGranted(expected)
        } else {
            val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
            flat.split(":").contains(expected.flattenToString())
        }
    }

    /**
     * History backfill. NOTE: on Android 13+ this returns empty unless ROZZ is the
     * default SMS handler — notification access + SMS_RECEIVED are the live paths.
     * Only HDFC senders are returned; date is epoch millis (Long).
     */
    private fun getInboxMessages(): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val cursor: Cursor? = contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms.Inbox.BODY, Telephony.Sms.Inbox.ADDRESS, Telephony.Sms.Inbox.DATE),
            "${Telephony.Sms.Inbox.ADDRESS} LIKE ?",
            arrayOf("%HDFC%"),
            // Newest-first, bounded: shipping the whole inbox across the platform
            // channel blocked the UI thread (ANR). Live capture is the primary path;
            // backfill only needs the recent window.
            "${Telephony.Sms.Inbox.DEFAULT_SORT_ORDER} LIMIT 1000"
        )

        cursor?.use {
            val bodyIndex = it.getColumnIndex(Telephony.Sms.Inbox.BODY)
            val addressIndex = it.getColumnIndex(Telephony.Sms.Inbox.ADDRESS)
            val dateIndex = it.getColumnIndex(Telephony.Sms.Inbox.DATE)

            while (it.moveToNext()) {
                val body = it.getString(bodyIndex) ?: continue
                val address = it.getString(addressIndex) ?: continue
                if (!SmsStore.isHdfc(address)) continue
                messages.add(mapOf(
                    "body" to body,
                    "sender" to address,
                    "date" to it.getLong(dateIndex)
                ))
            }
        }
        return messages
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        // Keep the process alive so SMS capture works in the background (MIUI
        // blocks the notification-listener bind without the Autostart whitelist).
        val captureIntent = Intent(this, SmsCaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(captureIntent)
        } else {
            startService(captureIntent)
        }
    }

    companion object {
        var methodChannel: MethodChannel? = null
    }
}