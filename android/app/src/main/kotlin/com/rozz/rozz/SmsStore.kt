package com.rozz.rozz

import android.content.Context
import android.content.Intent
import android.service.notification.StatusBarNotification
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Durable raw-SMS store.
 *
 * Captured SMS are appended to an app-private JSONL file (`raw_inbox.jsonl` in the
 * databases dir), then forwarded to Dart via the `onSmsReceived` method channel.
 * Dart drains the file with its own sqflite connection.
 *
 * Why JSONL and not SQLite: Dart keeps `rozz_database.db` open in WAL mode, and a
 * second connection (Kotlin) cannot write to it — the framework's journal-mode
 * switch fails with "database is locked" and the inserts are lost. Keeping Kotlin
 * and Dart on separate files removes the conflict entirely.
 */
object SmsStore {
    private val executor = Executors.newSingleThreadExecutor()

    fun isHdfc(sender: String?): Boolean {
        if (sender.isNullOrBlank()) return false
        val s = sender.lowercase()
        return s.contains("hdfcbk") || s.contains("vm-hdfcbk") || s.contains("hdfc")
    }

    // Strict: the bank's own shortcode, not generic "hdfc bank" (other banks'
    // SMS / chat apps say "to HDFC Bank" and must NOT be captured).
    fun isHdfcBody(body: String?): Boolean {
        if (body.isNullOrBlank()) return false
        val b = body.lowercase()
        return b.contains("hdfcbk") || b.contains("vm-hdfcbk")
    }

    /**
     * Queue an append. [onWritten] runs on the background thread AFTER the line is
     * durably written — the receiver uses it to finish its goAsync PendingResult.
     */
    fun insert(context: Context, sender: String?, body: String, receivedAt: Long, onWritten: (() -> Unit)? = null) {
        executor.execute {
            try {
                val file = context.getDatabasePath("raw_inbox.jsonl")
                file.parentFile?.mkdirs()
                val line = JSONObject()
                    .put("sender", sender ?: "unknown")
                    .put("body", body)
                    .put("received_at", receivedAt)
                    .toString()
                file.appendText(line + "\n")
            } catch (e: Exception) {
                android.util.Log.e("SmsStore", "append failed", e)
            } finally {
                try {
                    onWritten?.invoke()
                } catch (e: Exception) {
                    android.util.Log.e("SmsStore", "onWritten failed", e)
                }
                val args = mapOf(
                    "body" to body,
                    "sender" to (sender ?: "unknown"),
                    "received_at" to receivedAt
                )
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    MainActivity.methodChannel?.invokeMethod("onSmsReceived", args)
                }
            }
        }
    }

    fun handleNotification(context: Context, sbn: StatusBarNotification) {
        val extras = sbn.notification.extras ?: return
        val textLines = extras.getCharSequenceArray(android.app.Notification.EXTRA_TEXT_LINES)
        val body = if (textLines != null) textLines.joinToString("\n") else {
            extras.getCharSequence(android.app.Notification.EXTRA_TEXT)?.toString()
        } ?: return

        // For SMS notifications, EXTRA_TITLE is the sender shortcode (e.g. HDFCBK).
        val sender = extras.getCharSequence(android.app.Notification.EXTRA_TITLE)?.toString()
        if (!isHdfc(sender) && !isHdfcBody(body)) return

        val receivedAt = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()
        insert(context, sender, body, receivedAt)
    }
}