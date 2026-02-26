/// Локализация приложения DrinkWater
/// Поддержка русского и английского языков
abstract class AppLocalizations {
  static const String _locale = 'ru'; // Текущий язык
  
  // ===== Главный экран =====
  static const String appTitle = _locale == 'ru' ? 'ПЕЙ ВОДУ' : 'DRINK WATER';
  static const String drank = _locale == 'ru' ? 'Выпил(а)' : 'Drank';
  static const String settings = _locale == 'ru' ? 'Настройки' : 'Settings';
  static const String buttonDrank = _locale == 'ru' ? 'ВЫПИЛ' : 'DRANK';
  
  // Сообщения мотивации
  static const String goalAchieved = _locale == 'ru' 
    ? '🎉 Красава! Норма выполнена!'
    : '🎉 Great! Daily goal achieved!';
  
  static const String almostThere = _locale == 'ru'
    ? '💪 Почти готово! Осталось'
    : '💪 Almost there! {remaining} left';
  
  static const String done = _locale == 'ru'
    ? '✅ Зачёт! Осталось'
    : '✅ Good! {remaining} left';

  static const String streakTitle = _locale == 'ru'
    ? 'Серия'
    : 'Streak';

  static const String weekProgressTitle = _locale == 'ru'
    ? 'Неделя'
    : 'Week';

  static const String calendarTitle = _locale == 'ru'
    ? 'Календарь'
    : 'Calendar';
  
  // ===== Экран настроек =====
  static const String settingsTitle = _locale == 'ru' ? 'Настройки' : 'Settings';
  static const String save = _locale == 'ru' ? 'Сохранить' : 'Save';
  static const String saveButton = _locale == 'ru' ? 'Сохранить' : 'Save';
  
  static const String waterNorm = _locale == 'ru' ? 'Норма воды' : 'Water norm';
  static const String calculateByWeight = _locale == 'ru' 
    ? 'Рассчитать по весу'
    : 'Calculate by weight';
  static const String formula = _locale == 'ru'
    ? 'Формула: вес × 0.03 литра'
    : 'Formula: weight × 0.03 liters';
  
  static const String yourWeight = _locale == 'ru' ? 'Ваш вес (кг)' : 'Your weight (kg)';
  static const String glassesCount = _locale == 'ru' ? 'Количество стаканов' : 'Number of glasses';
  static const String glassVolume = _locale == 'ru' 
    ? '1 стакан = 200 мл'
    : '1 glass = 200 ml';
  static const String applyButton = _locale == 'ru' ? 'Применить' : 'Apply';
  static const String currentNorm = _locale == 'ru'
    ? 'Текущая норма:'
    : 'Current norm:';
  static const String glasses = _locale == 'ru' ? 'стаканов' : 'glasses';
  
  static const String notifications = _locale == 'ru' ? 'Уведомления' : 'Notifications';
  static const String enableNotifications = _locale == 'ru'
    ? 'Включить напоминания'
    : 'Enable reminders';
  
  static const String reminderInterval = _locale == 'ru'
    ? 'Интервал напоминаний'
    : 'Reminder interval';
  static const String hours = _locale == 'ru' ? 'ч' : 'h';
  
  static const String quietHours = _locale == 'ru'
    ? 'Тихие часы'
    : 'Quiet hours';
  static const String from = _locale == 'ru' ? 'С' : 'From';
  static const String to = _locale == 'ru' ? 'До' : 'To';
  
  static const String toxicity = _locale == 'ru'
    ? 'Уровень токсичности'
    : 'Toxicity level';
  static const String toxicityDescription = _locale == 'ru'
    ? 'Насколько жёстко приложение будет напоминать о воде'
    : 'How tough will the app be with reminders';
  
  static const String toxicityLight = _locale == 'ru'
    ? '😊 Лайт - Мягко напоминает'
    : '😊 Light - Gentle reminders';
  static const String toxicityMedium = _locale == 'ru'
    ? '😐 Средний - Обычные напоминания'
    : '😐 Medium - Regular reminders';
  static const String toxicityToxic = _locale == 'ru'
    ? '😠 Грубо - Не даст скучать'
    : '😠 Harsh - Won\'t let you relax';
  
  static const String resetCounter = _locale == 'ru'
    ? 'Сбросить дневной счётчик'
    : 'Reset daily counter';
  static const String counterReset = _locale == 'ru'
    ? 'Счётчик сброшен'
    : 'Counter reset';
  
  // ===== Валидация =====
  static const String invalidWeight = _locale == 'ru'
    ? 'Введите корректный вес'
    : 'Enter correct weight';
  static const String invalidGlasses = _locale == 'ru'
    ? 'Введите корректное количество стаканов'
    : 'Enter correct number of glasses';
  
  // ===== Выбор часа =====
  static const String selectHour = _locale == 'ru' ? 'Выберите час' : 'Select hour';
  
  // ===== AdMob =====
  static const String adPlaceholder = _locale == 'ru'
    ? '[ AdMob баннер v1.2 ]'
    : '[ AdMob banner v1.2 ]';
  
  // ===== Уведомления =====
  static const String notificationChannelDescription = _locale == 'ru'
    ? 'Напоминания пить воду'
    : 'Water drinking reminders';
  static const String notificationTitle = _locale == 'ru'
    ? '💧 ПЕЙ ВОДУ'
    : '💧 DRINK WATER';
  
  // ===== Инициализация =====
  static const String allServicesInitialized = _locale == 'ru'
    ? '✅ Все сервисы инициализированы'
    : '✅ All services initialized';
  static const String initializationError = _locale == 'ru'
    ? '❌ Ошибка инициализации:'
    : '❌ Initialization error:';
  
  /// Метод для переключения языка (для будущей реализации)
  /// import '../constants/app_localizations.dart' as l10n;
  /// String text = l10n.AppLocalizations.appTitle;
  static String getMessage(String key, {Map<String, String>? placeholders}) {
    // Для замены плейсхолдеров типа {remaining}
    if (placeholders != null) {
      var message = key;
      placeholders.forEach((k, v) {
        message = message.replaceAll('{$k}', v);
      });
      return message;
    }
    return key;
  }
}
