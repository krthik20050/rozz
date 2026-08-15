package com.rozz.rozz

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.database.Cursor
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Keeps the ROZZ process alive with a persistent notification and polls the SMS
 * inbox so new HDFC alerts are captured even in the background.
 *
 * Why this exists: MIUI refuses to bind the SmsNotificationListener unless the app
 * is in the Autostart whitelist, and background broadcasts are gated the same way.
 * A foreground service is exempt from that gate, so as long as the user has opened
 * ROZZ once (which starts this service), capture keeps working.
 *
 * Polling writes only genuinely new messages into raw_inbox (INSERT OR IGNORE +
 * date watermark), which the Dart side drains via the existing onSmsReceived hook.
 */
class SmsCaptureService : Service() {
    companion object {
        private const val TAG = "SmsCaptureService"
        private const val CHANNEL_ID = "rozz_sms_capture"
        private const val NOTIF_ID = 1
        private const val POLL_INTERVAL_MS = 45_000L
        private const val MAX_BATCH = 50
    }

    private val scheduler = Executors.newSingleThreadScheduledExecutor()
    @Volatile
    private var lastSeenAt: Long = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        // Skip history on start: the app's backfill covers it. Capture only what
        // arrives after the service is up.
        lastSeenAt = System.currentTimeMillis()
        startForeground(NOTIF_ID, buildNotification())
        scheduler.scheduleWithFixedDelay(
            { captureNewMessages() },
            0,
            POLL_INTERVAL_MS,
            TimeUnit.MILLISECONDS
        )
        Log.i(TAG, "Foreground SMS capture started")
    }

    override fun onDestroy() {
        scheduler.shutdownNow()
        Log.i(TAG, "Foreground SMS capture stopped")
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        createChannel()
        val openIntent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_rozz)
            .setContentTitle("ROZZ is monitoring")
            .setContentText("Watching for HDFC bank alerts")
            .setContentIntent(pending)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "SMS capture",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
    }

    /** Reads HDFC SMS newer than [lastSeenAt] and durably queues them in raw_inbox. */
    private fun captureNewMessages() {
        try {
            var newest = lastSeenAt
            val cursor: Cursor? = contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(Telephony.Sms.Inbox.BODY, Telephony.Sms.Inbox.ADDRESS, Telephony.Sms.Inbox.DATE),
                "${Telephony.Sms.Inbox.ADDRESS} LIKE ? AND ${Telephony.Sms.Inbox.DATE} > ?",
                arrayOf("%HDFC%", lastSeenAt.toString()),
                "${Telephony.Sms.Inbox.DEFAULT_SORT_ORDER} LIMIT $MAX_BATCH"
            )
            cursor?.use {
                val bodyIndex = it.getColumnIndex(Telephony.Sms.Inbox.BODY)
                val addressIndex = it.getColumnIndex(Telephony.Sms.Inbox.ADDRESS)
                val dateIndex = it.getColumnIndex(Telephony.Sms.Inbox.DATE)
                while (it.moveToNext()) {
                    val body = it.getString(bodyIndex) ?: continue
                    val address = it.getString(addressIndex) ?: continue
                    if (!SmsStore.isHdfc(address)) continue
                    val receivedAt = it.getLong(dateIndex)
                    if (receivedAt > newest) newest = receivedAt
                    // Appends to the JSONL handoff (SmsStore owns the file) and
                    // fires onSmsReceived so the Dart side drains + parses.
                    SmsStore.insert(this, address, body, receivedAt)
                }
            }
            if (newest > lastSeenAt) {
                lastSeenAt = newest
                Log.i(TAG, "New HDFC messages captured (watermark advanced)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Poll failed", e)
        }
    }
}
