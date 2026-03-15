package com.rozz.rozz

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Re-registering WorkManager tasks on boot")
            // WorkManager in Flutter auto-reschedules tasks if they were registered before,
            // but we can add explicit logic here if needed for foreground services later.
        }
    }
}
