import 'package:flutter/material.dart';

/// Константы приложения
class AppConstants {
  static void debugLog(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }

  // Цвета - улучшенная палитра
  static const Color primaryColor = Color(0xFF00BCD4); // Голубой (вода) - более яркий
  static const Color accentColor = Color(0xFF0097A7); // Тёмный голубой
  static const Color successColor = Color(0xFF4CAF50); // Зелёный для успеха
  static const Color warningColor = Color(0xFFFFA726); // Оранжевый
  static const Color darkBackground = Color(0xFF121212);
  static const Color lightBackground = Color(0xFFFAFAFA);
  
  // Размеры
  static const double buttonSize = 200.0;
  static const double buttonBorderRadius = 100.0;
  
  // Настройки по умолчанию
  static const int defaultGlassesCount = 8;
  static const int glassVolumeML = 200; // Объем стакана в мл
  static const double defaultIntervalHours = 2.0;
  static const String defaultToxicityLevel = 'medium';
  
  // Быстрый режим для тестов уведомлений
  static const bool defaultFastTestNotifications = false;
  static const int fastTestFirstDelayMinutes = 1;
  
  // Тихие часы по умолчанию (22:00 - 8:00)
  static const int defaultQuietStartHour = 22;
  static const int defaultQuietEndHour = 8;
  
  // Ключи для SharedPreferences
  static const String keyGlassesCount = 'glasses_count';
  static const String keyDrankToday = 'drank_today';
  static const String keyLastResetDate = 'last_reset_date';
  static const String keyUserWeight = 'user_weight';
  static const String keyIntervalHours = 'interval_hours';
  static const String keyQuietStartHour = 'quiet_start_hour';
  static const String keyQuietEndHour = 'quiet_end_hour';
  static const String keyToxicityLevel = 'toxicity_level';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyNotificationSound = 'notification_sound';
  static const String keyNotificationVibration = 'notification_vibration';
  static const String keyLastDrinkAt = 'last_drink_at';
  static const String keyFastTestNotifications = 'fast_test_notifications';
  static const String keyDailyHistory = 'daily_history';
  
  // Яндекс РСЯ
  // Тестовый блок для проверки интеграции
  static const String yandexAdBannerUnitId = 'R-M-18792287-1';
  
  // Уровни токсичности
  static const String toxicityLight = 'light';
  static const String toxicityMedium = 'medium';
  static const String toxicityToxic = 'toxic';
  
  static const Map<String, String> toxicityLabels = {
    toxicityLight: '😊 Лайт - Мягко напоминает',
    toxicityMedium: '😐 Средний - Обычные напоминания',
    toxicityToxic: '😠 Грубо - Не даст скучать',
  };
  
  // Интервалы напоминаний (в часах)
  static const List<double> availableIntervals = [5 / 60.0, 1, 2, 3];
  
  /// Форматирование интервала для отображения
  static String formatInterval(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes мин';
    }
    return '${hours.toInt()} ч';
  }
  
  /// Расчёт нормы воды по весу (вес * 0.03 литра = количество стаканов по 200 мл)
  static int calculateGlassesByWeight(double weight) {
    // weight * 0.03 литра = weight * 30 мл
    // делим на 200 мл (объем стакана)
    return ((weight * 30) / glassVolumeML).round();
  }
}
