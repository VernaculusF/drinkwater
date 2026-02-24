import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../constants/app_constants.dart';

/// Сервис для работы с локальным хранилищем
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;
  AppSettings? _cachedSettings;
  DateTime? _cacheTime;
  DateTime? _cachedLastDrinkAt;
  static const Duration _cacheTtl = Duration(seconds: 10);

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
    await _prefs?.remove(AppConstants.keyLastDrinkAt);

    if (_cachedSettings != null) {
      _cachedSettings = _cachedSettings!.copyWith(
        drankToday: 0,
        lastResetDate: today,
      );
      _cacheTime = DateTime.now();
    }

    _cachedLastDrinkAt = null;
  }

  /// Загрузка настроек
  Future<AppSettings> loadSettings() async {
    if (_prefs == null) await init();

    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    if (_cachedSettings != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl &&
        _cachedSettings!.lastResetDate == today) {
      return _cachedSettings!;
    }

    // Проверяем, нужно ли сбросить счётчик
    if (await shouldResetCounter()) {
      await resetDailyCounter();
    }
    
    // Обработка intervalHours - может быть int (старые данные) или double (новые)
    double intervalHours = AppConstants.defaultIntervalHours;
    
    // Безопасное получение intervalHours
    final intervalValue = _prefs?.get(AppConstants.keyIntervalHours);
    if (intervalValue is int) {
      // Старые данные сохранены как int
      intervalHours = intervalValue.toDouble();
      // Сохраняем как double для будущых обращений
      await _prefs?.setDouble(AppConstants.keyIntervalHours, intervalHours);
    } else if (intervalValue is double) {
      // Новые данные уже как double
      intervalHours = intervalValue;
    } else {
      // Нет данных или неправильный тип - используем значение по умолчанию
      intervalHours = AppConstants.defaultIntervalHours;
    }
    
    final settings = AppSettings(
      glassesCount: _prefs?.getInt(AppConstants.keyGlassesCount) ?? AppConstants.defaultGlassesCount,
      drankToday: _prefs?.getInt(AppConstants.keyDrankToday) ?? 0,
      lastResetDate: _prefs?.getString(AppConstants.keyLastResetDate) ?? today,
      userWeight: _prefs?.getDouble(AppConstants.keyUserWeight),
      intervalHours: intervalHours,
      quietStartHour: _prefs?.getInt(AppConstants.keyQuietStartHour) ?? AppConstants.defaultQuietStartHour,
      quietEndHour: _prefs?.getInt(AppConstants.keyQuietEndHour) ?? AppConstants.defaultQuietEndHour,
      toxicityLevel: _prefs?.getString(AppConstants.keyToxicityLevel) ?? AppConstants.defaultToxicityLevel,
      notificationsEnabled: _prefs?.getBool(AppConstants.keyNotificationsEnabled) ?? true,
      notificationSound: _prefs?.getBool(AppConstants.keyNotificationSound) ?? true,
      notificationVibration: _prefs?.getBool(AppConstants.keyNotificationVibration) ?? true,
    );

    _cachedSettings = settings;
    _cacheTime = now;
    return settings;
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
    await _prefs?.setBool(AppConstants.keyNotificationSound, settings.notificationSound);
    await _prefs?.setBool(AppConstants.keyNotificationVibration, settings.notificationVibration);

    _cachedSettings = settings;
    _cacheTime = DateTime.now();
  }

  /// Увеличить счётчик выпитых стаканов
  Future<int> incrementDrankCounter() async {
    if (_prefs == null) await init();
    
    final current = _prefs?.getInt(AppConstants.keyDrankToday) ?? 0;
    final newValue = current + 1;
    await _prefs?.setInt(AppConstants.keyDrankToday, newValue);
    final now = DateTime.now();
    await _prefs?.setInt(AppConstants.keyLastDrinkAt, now.millisecondsSinceEpoch);

    if (_cachedSettings != null) {
      _cachedSettings = _cachedSettings!.copyWith(drankToday: newValue);
      _cacheTime = DateTime.now();
    }

    _cachedLastDrinkAt = now;
    
    return newValue;
  }

  /// Получить время последнего нажатия "ВЫПИЛ"
  Future<DateTime?> getLastDrinkTime() async {
    if (_prefs == null) await init();
    if (_cachedLastDrinkAt != null) return _cachedLastDrinkAt;

    final millis = _prefs?.getInt(AppConstants.keyLastDrinkAt);
    if (millis == null) return null;

    _cachedLastDrinkAt = DateTime.fromMillisecondsSinceEpoch(millis);
    return _cachedLastDrinkAt;
  }

  /// Получить текущий счётчик выпитых стаканов
  Future<int> getDrankCounter() async {
    if (_prefs == null) await init();
    final now = DateTime.now();
    if (_cachedSettings != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cachedSettings!.drankToday;
    }
    return _prefs?.getInt(AppConstants.keyDrankToday) ?? 0;
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
