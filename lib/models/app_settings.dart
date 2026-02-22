/// Модель настроек приложения
class AppSettings {
  final int glassesCount; // Целевое количество стаканов в день
  final int drankToday; // Количество выпитых сегодня стаканов
  final String lastResetDate; // Дата последнего сброса счётчика
  final double? userWeight; // Вес пользователя (для расчёта нормы)
  final double intervalHours; // Интервал напоминаний в часах
  final int quietStartHour; // Начало тихих часов
  final int quietEndHour; // Конец тихих часов
  final String toxicityLevel; // Уровень токсичности фраз
  final bool notificationsEnabled; // Включены ли уведомления

  AppSettings({
    required this.glassesCount,
    required this.drankToday,
    required this.lastResetDate,
    this.userWeight,
    required this.intervalHours,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.toxicityLevel,
    required this.notificationsEnabled,
  });

  /// Копирование с изменением полей
  AppSettings copyWith({
    int? glassesCount,
    int? drankToday,
    String? lastResetDate,
    double? userWeight,
    double? intervalHours,
    int? quietStartHour,
    int? quietEndHour,
    String? toxicityLevel,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      glassesCount: glassesCount ?? this.glassesCount,
      drankToday: drankToday ?? this.drankToday,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      userWeight: userWeight ?? this.userWeight,
      intervalHours: intervalHours ?? this.intervalHours,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      toxicityLevel: toxicityLevel ?? this.toxicityLevel,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  /// Прогресс в процентах (0.0 - 1.0)
  double get progress {
    if (glassesCount == 0) return 0.0;
    return (drankToday / glassesCount).clamp(0.0, 1.0);
  }

  /// Осталось стаканов до цели
  int get remaining {
    return (glassesCount - drankToday).clamp(0, glassesCount);
  }
}
