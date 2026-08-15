package com.rozz.rozz

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.service.notification.StatusBarNotification
import java.util.concurrent.Executors

/**
 * Durable raw-SMS store. Writes go to the same sqflite DB file the Dart side uses
 * (raw_inbox table), so no SMS is lost when the app process is dead.
 */
object SmsStore {
    private val executor = Executors.newSingleThreadExecutor()
    private var db: SQLiteDatabase? = null

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
     * Queue a write. [onWritten] runs on the background thread AFTER the row is
     * durably inserted — the receiver uses it to finish its goAsync PendingResult,
     * so the process stays alive until the SMS actually lands in the DB.
     */
    fun insert(context: Context, sender: String?, body: String, receivedAt: Long, onWritten: (() -> Unit)? = null) {
        executor.execute {
            try {
                val database = getDb(context)
                database.execSQL(
                    "INSERT OR IGNORE INTO raw_inbox (sender, body, received_at) VALUES (?, ?, ?)",
                    arrayOf(sender, body, receivedAt)
                )
            } catch (e: Exception) {
                // Retry once — a transient busy/IO failure must not lose the SMS.
                android.util.Log.e("SmsStore", "insert failed", e)
                try {
                    Thread.sleep(50)
                    val database = getDb(context)
                    database.execSQL(
                        "INSERT OR IGNORE INTO raw_inbox (sender, body, received_at) VALUES (?, ?, ?)",
                        arrayOf(sender, body, receivedAt)
                    )
                } catch (e2: Exception) {
                    android.util.Log.e("SmsStore", "insert retry failed", e2)
                }
            } finally {
                try {
                    onWritten?.invoke()
                } catch (e: Exception) {
                    android.util.Log.e("SmsStore", "onWritten failed", e)
                }
                val args = mapOf("body" to body, "sender" to (sender ?: "unknown"))
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

    private fun getDb(context: Context): SQLiteDatabase {
        db?.let { return it }
        val path = context.getDatabasePath("rozz_database.db")
        val opened = SQLiteDatabase.openDatabase(
            path.absolutePath, null,
            SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.CREATE_IF_NECESSARY
        )
        opened.execSQL("PRAGMA busy_timeout=5000")
        opened.execSQL(
            "CREATE TABLE IF NOT EXISTS raw_inbox (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "sender TEXT, body TEXT NOT NULL, received_at INTEGER NOT NULL)"
        )
        opened.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_raw_inbox_dedupe ON raw_inbox(sender, body)"
        )
        db = opened
        return opened
    }
}