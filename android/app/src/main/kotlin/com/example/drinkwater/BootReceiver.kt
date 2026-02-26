package com.example.drinkwater

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receiver для восстановления запланированных уведомлений после перезагрузки устройства
 */
class ScheduledNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Обработка запуска после перезагрузки
        // flutter_local_notifications автоматически перезапустит уведомления
    }
}
