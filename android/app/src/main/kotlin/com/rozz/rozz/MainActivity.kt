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

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rozz/sms"

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
                else -> result.notImplemented()
            }
        }
    }

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
            Telephony.Sms.Inbox.DEFAULT_SORT_ORDER
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
    }

    companion object {
        var methodChannel: MethodChannel? = null
    }
}