package com.rozz.rozz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import java.util.concurrent.atomic.AtomicInteger

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        // goAsync: the system may kill our process mid-broadcast; finish() is called
        // only after every matched SMS is durably inserted.
        val pendingResult = goAsync()
        val enqueued = AtomicInteger(0)
        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val sender = sms.displayOriginatingAddress ?: continue
                val body = sms.displayMessageBody ?: continue
                if (!SmsStore.isHdfc(sender)) continue
                enqueued.incrementAndGet()
                SmsStore.insert(context, sender, body, System.currentTimeMillis()) {
                    if (enqueued.decrementAndGet() == 0) pendingResult.finish()
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("SmsReceiver", "broadcast handling failed", e)
        } finally {
            if (enqueued.get() == 0) pendingResult.finish()
        }
    }
}