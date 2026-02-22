package com.example.drinkwater

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/**
 * Виджет для отображения прогресса питья воды на home screen
 */
class DrinkWaterWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            // Используем значения по умолчанию
            val drank = 0
            val total = 8
            val phrase = "Пей воду!"

            // Расчёт прогресса
            val percent = if (total > 0) (drank * 100) / total else 0
            val progressText = "$drank / $total"

            // Создаём RemoteViews с разметкой виджета
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_layout
            )

            // Устанавливаем значения
            views.setTextViewText(R.id.widget_progress_text, progressText)
            views.setTextViewText(R.id.widget_phrase_text, phrase)
            views.setProgressBar(R.id.widget_progress_bar, total, drank, false)
            views.setTextViewText(R.id.widget_percent_text, "$percent%")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}


