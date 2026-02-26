import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:typed_data';
import '../constants/app_localizations.dart';
import '../constants/app_constants.dart';
import 'phrase_service.dart';
import 'storage_service.dart';
import 'widget_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  if (response.actionId == 'DRINK_ACTION' || response.payload == 'water_reminder') {
    _handleDrinkActionInBackground();
  }
}

/// Background handler для уведомлений (не может быть async)
void _handleDrinkActionInBackground() {
  // Запускаем в фоне, не блокируя основной поток
  Future.delayed(Duration.zero, () async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final storageService = StorageService();
      await storageService.init();
      final newCount = await storageService.incrementDrankCounter();

      final widgetService = WidgetService();
      await widgetService.init();
      await widgetService.updateWidget();

      AppConstants.debugLog('✅ Выпил из уведомления (фон). Новый счетчик: $newCount');
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка обработки уведомления в фоне: $e');
    }
  });
}

/// Сервис для работы с уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final PhraseService _phraseService = PhraseService();
  bool _initialized = false;
  bool _permissionRequesting = false;
  
  // Для тестирования: позволяем вставлять mock плагин
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = _notifications;
  late PhraseService phraseService = _phraseService;
  
  // Callback для обработки нажатия на уведомление
  Function(String payload)? onNotificationTapped;

  /// Инициализация уведомлений
  Future<void> init() async {
    AppConstants.debugLog('🔔 NotificationService инициализация...');
    if (_initialized) return;

    // Инициализируем временные зоны
    tz_data.initializeTimeZones();

    // Настройки для Android (иконка должна быть в drawable папке, без префикса и расширения)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification_water');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;

    // Создаем канал уведомлений для Android 8+ (ОБЯЗАТЕЛЬНО!)
    await _createNotificationChannel();

    // Проверяем, нужно ли переплануровать уведомления на новый день
    await _checkAndRescheduleIfNeeded();
  }

  /// Обработка нажатия на уведомление или его кнопки
  void _onNotificationTap(NotificationResponse response) {
    AppConstants.debugLog('📲 Уведомление активировано: actionId=${response.actionId}, payload=${response.payload}');
    
    // Обработка нажатия на кнопку "ВЫПИЛ" или саму уведомление
    if (response.actionId == 'DRINK_ACTION' || response.payload == 'water_reminder') {
      // Вызываем callback если он установлен
      if (onNotificationTapped != null) {
        onNotificationTapped!('water_reminder');
      } else {
        _handleDrinkActionInBackground();
      }
    }
  }

  /// Создание канала уведомлений для Android 8+ (API 26+)
  /// Это ОБЯЗАТЕЛЬНО для доставки уведомлений на Android 8 и выше
  Future<void> _createNotificationChannel() async {
    try {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        AppConstants.debugLog('🔧 Инициализация канала уведомлений...');
        
        // Создаем канал с параметрами (id, name)
        final waterChannel = AndroidNotificationChannel(
          'water_reminder',
          AppLocalizations.notificationTitle,
          description: AppLocalizations.notificationChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        
        await androidImplementation.createNotificationChannel(waterChannel);
        AppConstants.debugLog('✅ Канал water_reminder инициализирован');
      } else {
        AppConstants.debugLog('⚠️ AndroidFlutterLocalNotificationsPlugin не доступен');
      }
    } catch (e) {
      AppConstants.debugLog('❌ Ошибка создания канала: $e');
    }
  }

  /// Запрос разрешения на уведомления (Android 13+)
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    // Если уже идет запрос разрешений - возвращаем true
    if (_permissionRequesting) {
      AppConstants.debugLog('⚠️ Запрос разрешений уже выполняется, пропускаем');
      return true;
    }

    final androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      _permissionRequesting = true;
      bool notifGranted = true;
      bool exactAlarmGranted = true;
      
      try {
        // Запрашиваем разрешение на уведомления (Android 13+)
        try {
          final result = await androidImplementation.requestNotificationsPermission();
          notifGranted = result ?? true;
          AppConstants.debugLog('✅ Разрешение на уведомления: $notifGranted');
        } catch (e) {
          AppConstants.debugLog('⚠️ Ошибка запроса разрешения на уведомления: $e');
          // Продолжаем выполнение, считаем что разрешение получено
        }
        
        // Задержка между запросами, чтобы избежать конфликта
        await Future.delayed(const Duration(seconds: 1));
        
        // Запрашиваем разрешение на точное планирование (Android 12+)
        try {
          final result = await androidImplementation.requestExactAlarmsPermission();
          exactAlarmGranted = result ?? true;
          AppConstants.debugLog('✅ Разрешение на точное планирование: $exactAlarmGranted');
        } catch (e) {
          AppConstants.debugLog('⚠️ Ошибка запроса разрешения на точные alarm: $e');
          // Продолжаем выполнение, считаем что разрешение получено
        }
      } finally {
        _permissionRequesting = false;
      }
      
      return notifGranted && exactAlarmGranted;
    }
    
    return true; // Для версий ниже Android 13 разрешение не требуется
  }



  /// Показать уведомление
  Future<void> showNotification({
    required String title,
    required String body,
    bool withSound = true,
    bool withVibration = true,
    String? progressText,
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      'water_reminder',
      AppLocalizations.notificationTitle,
      channelDescription: AppLocalizations.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification_water',
      sound: null,
      vibrationPattern: withVibration ? Int64List.fromList([0, 250, 250, 250]) : null,
      playSound: withSound,
      enableVibration: withVibration,
      styleInformation: const BigTextStyleInformation(''),
      subText: progressText,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'DRINK_ACTION',
          'ВЫПИЛ',
          showsUserInterface: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
      payload: 'water_reminder',
    );
  }



  /// Запланировать периодические уведомления (используя встроенный механизм ОС)
  Future<void> scheduleNotifications({
    required double intervalHours,
    bool enabled = true,
  }) async {
    if (!_initialized) await init();

    final storageService = StorageService();
    final settings = await storageService.loadSettings();

    // Если отключены - отменяем все
    if (!enabled) {
      await flutterLocalNotificationsPlugin.cancelAll();
      AppConstants.debugLog('🔴 Уведомления отключены, отменяем все');
      return;
    }

    // Отменяем ВСЕ предыдущие уведомления
    await flutterLocalNotificationsPlugin.cancelAll();
    AppConstants.debugLog('🗑️ Все старые уведомления отменены');

    // Вычисляем сколько стаканов ОСТАЛОСЬ выпить
    final drankToday = await storageService.getDrankCounter();
    final remainingGlasses = (settings.glassesCount - drankToday).clamp(0, settings.glassesCount);

    if (remainingGlasses == 0) {
      AppConstants.debugLog('✅ Цель уже достигнута! Уведомления не нужны');
      return;
    }

    AppConstants.debugLog('💧 Осталось выпить: $remainingGlasses из ${settings.glassesCount} стаканов');
    
    // Сохраняем информацию о запланированных уведомлениях
    await storageService.saveNotificationSchedule(
      intervalHours: intervalHours,
      lastScheduleDate: DateTime.now().toIso8601String().substring(0, 10),
    );

    try {
      final now = DateTime.now();
      
      // Вычисляем доступное время (исключая тихий час)
      final quietStartHour = settings.quietStartHour;
      final quietEndHour = settings.quietEndHour;
      
      // Часы сна (например 22:00 - 8:00)
      int quietDuration = 0;
      if (quietEndHour > quietStartHour) {
        // Простой случай: тихий час в пределах одних суток (8:00 - 22:00 например)
        quietDuration = quietEndHour - quietStartHour;
      } else {
        // Тихий час через полночь (22:00 - 8:00)
        quietDuration = (24 - quietStartHour) + quietEndHour;
      }
      
      final availableHours = 24 - quietDuration;
      final availableMinutes = availableHours * 60;
      
      AppConstants.debugLog('🕐 Доступно часов в день: $availableHours (тихий час: $quietStartHour:00-$quietEndHour:00)');
      
      // Интервал между уведомлениями = заданный пользователем
      int minutesInterval = (intervalHours * 60).round();
      if (minutesInterval < 1) {
        minutesInterval = 1;
      }
      
      final maxNotificationsByTime = (availableMinutes / minutesInterval).floor();
      final notificationsToSchedule = remainingGlasses < maxNotificationsByTime
          ? remainingGlasses
          : maxNotificationsByTime;
      
      AppConstants.debugLog('⏱️ Интервал между уведомлениями: $minutesInterval мин');
      AppConstants.debugLog('📌 Можно запланировать: $notificationsToSchedule из $remainingGlasses');
      
      // Начинаем планирование с текущего момента (или после окончания тихого часа)
      DateTime nextNotificationTime = now.add(Duration(minutes: minutesInterval));
      
      int scheduledCount = 0;
      for (int i = 0; i < notificationsToSchedule && scheduledCount < 50; i++) {
        // Проверяем попадает ли время в тихий час
        while (_isInQuietHours(nextNotificationTime, quietStartHour, quietEndHour)) {
          // Пропускаем тихий час - переносим на окончание тихого часа
          nextNotificationTime = _skipQuietHours(nextNotificationTime, quietStartHour, quietEndHour);
        }
        
        // Если уведомление выходит за пределы текущих суток - пропускаем
        if (nextNotificationTime.difference(now).inHours >= 24) {
          break;
        }
        
        final int notificationId = i;
        
        try {
          // Используем zonedSchedule для системного планирования
          final duration = nextNotificationTime.difference(DateTime.now());
          
          if (duration.isNegative) {
            AppConstants.debugLog('⚠️ Уведомление #$i: время в прошлом, пропускаем');
            continue;
          }
          
          final phrase = phraseService.getRandomPhrase(settings.toxicityLevel);
          
          await flutterLocalNotificationsPlugin.zonedSchedule(
            notificationId,
            '💧 ПЕЙ ВОДУ',
            phrase,
            tz.TZDateTime.now(tz.local).add(duration),
            NotificationDetails(
              android: AndroidNotificationDetails(
                'water_reminder',
                'Напоминание о воде',
                icon: 'ic_notification_water',
                importance: Importance.max,
                priority: Priority.max,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: 
              UILocalNotificationDateInterpretation.absoluteTime,
          );
          
          AppConstants.debugLog('✅ Уведомление #$i запланировано на ${duration.inSeconds}сек (${duration.inMinutes}мин)');
          scheduledCount++;
        } catch (e) {
          AppConstants.debugLog('❌ Ошибка уведомления #$notificationId: $e');
        }
        
        // Следующее уведомление
        nextNotificationTime = nextNotificationTime.add(Duration(minutes: minutesInterval));
      }

      AppConstants.debugLog('✅ Запланировано $scheduledCount уведомлений для $remainingGlasses оставшихся стаканов');
      
      // Выводим список запланированных уведомлений
      await _printPendingNotifications();
    } catch (e) {
      AppConstants.debugLog('⚠️ Критическая ошибка при планировании уведомлений: $e');
    }
  }

  /// Вывести список всех запланированных уведомлений (для отладки)
  Future<void> _printPendingNotifications() async {
    try {
      final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();
      if (pending.isEmpty) {
        AppConstants.debugLog('⚠️ В системе нет запланированных уведомлений!');
      } else {
        AppConstants.debugLog('📋 В системе запланировано уведомлений: ${pending.length}');
        for (var req in pending.take(3)) {
          final bodyPreview = req.body != null && req.body!.length > 20
              ? req.body!.substring(0, 20)
              : (req.body ?? "");
          AppConstants.debugLog('   - ID: ${req.id}, Title: ${req.title}, Body: $bodyPreview...');
        }
      }
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка при получении списка уведомлений: $e');
    }
  }

  /// Проверить попадает ли время в тихий час
  bool _isInQuietHours(DateTime time, int quietStartHour, int quietEndHour) {
    final hour = time.hour;
    
    if (quietEndHour > quietStartHour) {
      // Простой случай: тихий час в пределах суток (например 8:00 - 22:00)
      return hour >= quietStartHour && hour < quietEndHour;
    } else {
      // Тихий час через полночь (например 22:00 - 8:00)
      return hour >= quietStartHour || hour < quietEndHour;
    }
  }

  /// Пропустить тихий час и вернуть время после его окончания
  DateTime _skipQuietHours(DateTime time, int quietStartHour, int quietEndHour) {
    final currentHour = time.hour;
    
    if (quietEndHour > quietStartHour) {
      // Простой случай
      if (currentHour >= quietStartHour && currentHour < quietEndHour) {
        // Переносим на окончание тихого часа
        return DateTime(time.year, time.month, time.day, quietEndHour, 0);
      }
    } else {
      // Тихий час через полночь
      if (currentHour >= quietStartHour) {
        // После начала тихого часа - переносим на следующий день в quietEndHour
        return DateTime(time.year, time.month, time.day + 1, quietEndHour, 0);
      } else if (currentHour < quietEndHour) {
        // До окончания тихого часа - переносим на сегодня в quietEndHour
        return DateTime(time.year, time.month, time.day, quietEndHour, 0);
      }
    }
    
    return time; // Время вне тихого часа
  }

  /// Проверить и переплануровать уведомления если изменился день
  Future<void> _checkAndRescheduleIfNeeded() async {
    try {
      final storageService = StorageService();
      
      // Получаем дату последнего планирования
      final lastScheduleDate = await storageService.getLastScheduleDate();
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Если дата изменилась - переплануем
      if (lastScheduleDate != today) {
        AppConstants.debugLog('📅 Обнаружена смена дня, переплануем уведомления');
        final settings = await storageService.loadSettings();
        
        if (settings.notificationsEnabled) {
          await scheduleNotifications(intervalHours: settings.intervalHours);
        } else {
          await cancelAllNotifications();
        }
      }
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка при проверке переплана: $e');
    }
  }

  /// Запланировать тестовые уведомления каждую минуту (для отладки)
  /// Создаёт 5 уведомлений с интервалом в 1 минуту
  Future<void> scheduleTestNotificationsEveryMinute() async {
    if (!_initialized) await init();
    
    AppConstants.debugLog('🧪 Запуск тестовых уведомлений каждую минуту...');
    
    // Отменяем все предыдущие уведомления
    await flutterLocalNotificationsPlugin.cancelAll();
    AppConstants.debugLog('🗑️ Все старые уведомления отменены');
    
    final storageService = StorageService();
    final settings = await storageService.loadSettings();
    
    try {
      final now = DateTime.now();
      const testNotificationsCount = 5; // Количество тестовых уведомлений
      const intervalMinutes = 1; // Интервал в 1 минуту
      
      for (int i = 0; i < testNotificationsCount; i++) {
        final notificationTime = now.add(Duration(minutes: (i + 1) * intervalMinutes));
        final duration = notificationTime.difference(DateTime.now());
        
        final phrase = phraseService.getRandomPhrase(settings.toxicityLevel);
        
        await flutterLocalNotificationsPlugin.zonedSchedule(
          i,
          '💧 ПЕЙ ВОДУ (ТЕСТ)',
          phrase,
          tz.TZDateTime.now(tz.local).add(duration),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'water_reminder',
              'Напоминание о воде',
              icon: 'ic_notification_water',
              importance: Importance.max,
              priority: Priority.max,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        );
        
        AppConstants.debugLog('✅ Тестовое уведомление #$i запланировано на ${duration.inMinutes} мин');
      }
      
      AppConstants.debugLog('✅ Запланировано $testNotificationsCount тестовых уведомлений');
      await _printPendingNotifications();
    } catch (e) {
      AppConstants.debugLog('❌ Ошибка при планировании тестовых уведомлений: $e');
    }
  }

  /// Отменить все уведомления
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    AppConstants.debugLog('✅ Все уведомления отменены');
  }

  /// Получить информацию о запланированных уведомлениях (для отладки)
  /// Возвращает строку с информацией о времени и количестве уведомлений
  Future<String> getSchedulingDebugInfo() async {
    try {
      final storageService = StorageService();
      final lastScheduleDate = await storageService.getLastScheduleDate();
      final intervalHours = await storageService.getScheduledIntervalHours() ?? 0;
      final settings = await storageService.loadSettings();
      final drankToday = await storageService.getDrankCounter();
      final remainingGlasses = (settings.glassesCount - drankToday).clamp(0, settings.glassesCount);

      if (intervalHours == 0) {
        return '⚠️ Уведомления не запланированы';
      }

      if (remainingGlasses == 0) {
        return '✅ Цель достигнута! Все $drankToday стаканов выпиты. Уведомления не нужны.';
      }

      final now = DateTime.now();
      final today = now.toIso8601String().substring(0, 10);

      final status = settings.notificationsEnabled ? '✅ Включены' : '❌ Отключены';
      final dayStatus = lastScheduleDate == today ? '✅ Сегодня' : '⚠️ $lastScheduleDate';

      // Вычисляем доступное время (исключая тихий час)
      final quietStartHour = settings.quietStartHour;
      final quietEndHour = settings.quietEndHour;
      
      int quietDuration = 0;
      if (quietEndHour > quietStartHour) {
        quietDuration = quietEndHour - quietStartHour;
      } else {
        quietDuration = (24 - quietStartHour) + quietEndHour;
      }
      
      final availableHours = 24 - quietDuration;
      final availableMinutes = availableHours * 60;
      
      // Интервал между уведомлениями = заданный пользователем
      int minutesInterval = (intervalHours * 60).round();
      if (minutesInterval < 1) {
        minutesInterval = 1;
      }
      
      final maxNotificationsByTime = (availableMinutes / minutesInterval).floor();
      final notificationsToSchedule = remainingGlasses < maxNotificationsByTime
          ? remainingGlasses
          : maxNotificationsByTime;

      // Рассчитываем время первого и второго уведомления
      DateTime nextNotificationTime = now.add(Duration(minutes: minutesInterval));
      
      // Пропускаем тихий час для первого уведомления
      if (_isInQuietHours(nextNotificationTime, quietStartHour, quietEndHour)) {
        nextNotificationTime = _skipQuietHours(nextNotificationTime, quietStartHour, quietEndHour);
      }
      
      final firstTime = '${nextNotificationTime.hour.toString().padLeft(2, '0')}:${nextNotificationTime.minute.toString().padLeft(2, '0')}';
      
      nextNotificationTime = nextNotificationTime.add(Duration(minutes: minutesInterval));
      if (_isInQuietHours(nextNotificationTime, quietStartHour, quietEndHour)) {
        nextNotificationTime = _skipQuietHours(nextNotificationTime, quietStartHour, quietEndHour);
      }
      
      final secondTime = '${nextNotificationTime.hour.toString().padLeft(2, '0')}:${nextNotificationTime.minute.toString().padLeft(2, '0')}';

      final infoText = '''
📋 ИНФОРМАЦИЯ О ЗАПЛАНИРОВАННЫХ УВЕДОМЛЕНИЯХ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Статус: $status
Прогресс: $drankToday/${settings.glassesCount} 💧
Осталось стаканов: $remainingGlasses
Последнее планирование: $dayStatus

⏰ ПАРАМЕТРЫ:
Тихий час: $quietStartHour:00 - $quietEndHour:00 (исключён)
Доступно часов: $availableHours ч
Интервал между уведомлениями: ${(minutesInterval / 60).toStringAsFixed(1)} ч
Запланировано уведомлений: $notificationsToSchedule
Режим: inexact (совместим со всеми устройствами)

⏰ ПРИМЕРЫ ВРЕМЕНИ:
   1️⃣  $firstTime
   2️⃣  $secondTime
   ...и ещё ${(remainingGlasses - 2).clamp(0, 999)} уведомлений

💡 СОВЕТ:
   После каждого "ВЫПИЛ" уведомления переплануются
   автоматически для оставшихся стаканов
   и жди первого уведомления через $minutesInterval минут''';

      return infoText;
    } catch (e) {
      return '⚠️ Ошибка при получении информации: $e';
    }
  }

  /// Вывести информацию о запланированных уведомлениях в лог
  Future<void> printSchedulingInfo() async {
    final info = await getSchedulingDebugInfo();
    AppConstants.debugLog(info);
  }
}
