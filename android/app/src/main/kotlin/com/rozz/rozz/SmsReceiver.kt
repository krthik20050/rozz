package com.rozz.rozz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.os.Handler
import android.os.Looper

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (sms in messages) {
                val sender = sms.displayOriginatingAddress ?: continue
                val body = sms.displayMessageBody ?: continue

                if (sender.contains("HDFCBK", ignoreCase = true) || 
                    sender.contains("HDFC", ignoreCase = true) || 
                    sender.contains("VM-HDFCBK", ignoreCase = true)) {
                    
                    val args = mapOf("body" to body, "sender" to sender)
                    Handler(Looper.getMainLooper()).post {
                        MainActivity.methodChannel?.invokeMethod("onSmsReceived", args)
                    }
                }
            }
        }
    }
}
