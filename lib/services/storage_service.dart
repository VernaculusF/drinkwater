import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../constants/app_constants.dart';

/// Сервис для работы с локальным хранилищем
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  /// Инициализация SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Проверка нужности сброса счётчика (новый день)
  Future<bool> shouldResetCounter() async {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final lastReset = _prefs?.getString(AppConstants.keyLastResetDate) ?? '';
    return today != lastReset;
  }

  /// Сброс дневного счётчика
  Future<void> resetDailyCounter() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _prefs?.setInt(AppConstants.keyDrankToday, 0);
    await _prefs?.setString(AppConstants.keyLastResetDate, today);
  }

  /// Загрузка настроек
  Future<AppSettings> loadSettings() async {
    if (_prefs == null) await init();

    // Проверяем, нужно ли сбросить счётчик
    if (await shouldResetCounter()) {
      await resetDailyCounter();
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    
    // Обработка intervalHours - может быть int (старые данные) или double (новые)
    double intervalHours = AppConstants.defaultIntervalHours;
    try {
      intervalHours = _prefs?.getDouble(AppConstants.keyIntervalHours) ?? AppConstants.defaultIntervalHours;
    } catch (e) {
      // Если сохранено как int, конвертируем в double
      final intValue = _prefs?.getInt(AppConstants.keyIntervalHours);
      if (intValue != null) {
        intervalHours = intValue.toDouble();
        // Сохраняем как double для будущих обращений
        await _prefs?.setDouble(AppConstants.keyIntervalHours, intervalHours);
      }
    }
    
    return AppSettings(
      glassesCount: _prefs?.getInt(AppConstants.keyGlassesCount) ?? AppConstants.defaultGlassesCount,
      drankToday: _prefs?.getInt(AppConstants.keyDrankToday) ?? 0,
      lastResetDate: _prefs?.getString(AppConstants.keyLastResetDate) ?? today,
      userWeight: _prefs?.getDouble(AppConstants.keyUserWeight),
      intervalHours: intervalHours,
      quietStartHour: _prefs?.getInt(AppConstants.keyQuietStartHour) ?? AppConstants.defaultQuietStartHour,
      quietEndHour: _prefs?.getInt(AppConstants.keyQuietEndHour) ?? AppConstants.defaultQuietEndHour,
      toxicityLevel: _prefs?.getString(AppConstants.keyToxicityLevel) ?? AppConstants.defaultToxicityLevel,
      notificationsEnabled: _prefs?.getBool(AppConstants.keyNotificationsEnabled) ?? true,
    );
  }

  /// Сохранение настроек
  Future<void> saveSettings(AppSettings settings) async {
    if (_prefs == null) await init();

    await _prefs?.setInt(AppConstants.keyGlassesCount, settings.glassesCount);
    await _prefs?.setInt(AppConstants.keyDrankToday, settings.drankToday);
    await _prefs?.setString(AppConstants.keyLastResetDate, settings.lastResetDate);
    
    if (settings.userWeight != null) {
      await _prefs?.setDouble(AppConstants.keyUserWeight, settings.userWeight!);
    }
    
    await _prefs?.setDouble(AppConstants.keyIntervalHours, settings.intervalHours);
    await _prefs?.setInt(AppConstants.keyQuietStartHour, settings.quietStartHour);
    await _prefs?.setInt(AppConstants.keyQuietEndHour, settings.quietEndHour);
    await _prefs?.setString(AppConstants.keyToxicityLevel, settings.toxicityLevel);
    await _prefs?.setBool(AppConstants.keyNotificationsEnabled, settings.notificationsEnabled);
  }

  /// Увеличить счётчик выпитых стаканов
  Future<int> incrementDrankCounter() async {
    if (_prefs == null) await init();
    
    final current = _prefs?.getInt(AppConstants.keyDrankToday) ?? 0;
    final newValue = current + 1;
    await _prefs?.setInt(AppConstants.keyDrankToday, newValue);
    
    return newValue;
  }

  /// Установить норму стаканов по весу
  Future<void> setGlassesByWeight(double weight) async {
    if (_prefs == null) await init();
    
    final glasses = AppConstants.calculateGlassesByWeight(weight);
    await _prefs?.setInt(AppConstants.keyGlassesCount, glasses);
    await _prefs?.setDouble(AppConstants.keyUserWeight, weight);
  }

  /// Установить норму стаканов вручную
  Future<void> setGlassesManually(int count) async {
    if (_prefs == null) await init();
    
    await _prefs?.setInt(AppConstants.keyGlassesCount, count);
    await _prefs?.remove(AppConstants.keyUserWeight); // Убираем вес, т.к. ручная настройка
  }
}
