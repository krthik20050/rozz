package com.rozz.rozz

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Notification-access capture path. Catches HDFC SMS notifications even when the
 * process is dead (system rebinds us) — the fallback on Android 13+ where
 * Telephony.Sms.Inbox reads are restricted for non-default SMS handlers.
 */
class SmsNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        SmsStore.handleNotification(this, sbn)
    }

    override fun onListenerConnected() {
        android.util.Log.i("SmsNotificationListener", "Notification access connected")
    }
}