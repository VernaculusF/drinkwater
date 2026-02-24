import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'dart:async';
import 'dart:typed_data';
import '../constants/app_localizations.dart';
import '../constants/app_constants.dart';
import 'phrase_service.dart';
import 'storage_service.dart';
import 'widget_service.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'DRINK_ACTION' || response.payload == 'water_reminder') {
    await _handleDrinkActionInBackground();
  }
}

Future<void> _handleDrinkActionInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();
  final newCount = await storageService.incrementDrankCounter();

  final widgetService = WidgetService();
  await widgetService.init();
  await widgetService.updateWidget();

  AppConstants.debugLog('✅ Выпил из уведомления (фон). Новый счетчик: $newCount');
}

/// Сервис для работы с уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // Callback для обработки нажатия на уведомление
  Function(String payload)? onNotificationTapped;

  /// Инициализация уведомлений
  Future<void> init() async {
    if (_initialized) return;

    // Инициализируем временные зоны
    tz_data.initializeTimeZones();

    // Настройки для Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _initialized = true;
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
        unawaited(_handleDrinkActionInBackground());
      }
    }
  }

  /// Запрос разрешения на уведомления (Android 13+)
  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    final androidImplementation = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
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
      icon: '@mipmap/ic_launcher',
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

    await _notifications.show(
      0,
      title,
      body,
      notificationDetails,
      payload: 'water_reminder',
    );
  }

  /// Запланировать периодические уведомления
  Future<void> scheduleNotifications({
    required double intervalHours,
  }) async {
    if (!_initialized) await init();

    // Отменяем ВСЕ предыдущие уведомления
    await _notifications.cancelAll();
    AppConstants.debugLog('🗑️ Все старые уведомления отменены');

    final phraseService = PhraseService();
    final storageService = StorageService();
    final settings = await storageService.loadSettings();

    int minutesInterval = (intervalHours * 60).toInt();
    if (minutesInterval < 1) minutesInterval = 1;
    
    AppConstants.debugLog('🔔 Планируем уведомления каждые $minutesInterval минут');
    
    DateTime now = DateTime.now();
    
    // Расчитываем количество уведомлений на день
    int maxNotificationsPerDay = (1440 / minutesInterval).ceil();
    maxNotificationsPerDay = maxNotificationsPerDay.clamp(1, 50);
    
    AppConstants.debugLog('📊 Будет планировано $maxNotificationsPerDay уведомлений');
    
    // Первое уведомление через указанный интервал
    DateTime firstScheduled = now.add(Duration(minutes: minutesInterval));
    
    for (int i = 0; i < maxNotificationsPerDay; i++) {
      // Расчитываем время этого уведомления
      DateTime scheduledDateTime = firstScheduled.add(Duration(minutes: minutesInterval * i));
      
      // Если более 24 часов, прекращаем
      if (scheduledDateTime.difference(now).inMinutes > 1440) {
        break;
      }
      
      final id = i;
      final minutesFromNow = scheduledDateTime.difference(now).inMinutes;
      final hour = scheduledDateTime.hour;
      final minute = scheduledDateTime.minute;
      
      // Планируем через Future.delayed (без требований к разрешениям)
      unawaited(
        Future.delayed(
          Duration(minutes: minutesFromNow),
          () async {
            try {
              final storageService = StorageService();
              await storageService.init();
              
              // Проверяем, прошло ли достаточно времени с последнего drink
              final lastDrinkAt = await storageService.getLastDrinkTime();
              
              if (lastDrinkAt != null) {
                final elapsedMinutes = DateTime.now().difference(lastDrinkAt).inMinutes;
                if (elapsedMinutes < minutesInterval) {
                  AppConstants.debugLog('⏭️ Уведомление #$id пропущено: $elapsedMinutes < $minutesInterval мин');
                  return;
                }
              }
              
              // Уведомление прошло проверку - отправляем
              final phrase = phraseService.getRandomPhrase(settings.toxicityLevel);
              final currentCount = await storageService.getDrankCounter();
              final progressText = '$currentCount/${settings.glassesCount} 💧';
              
              AppConstants.debugLog('📤 Отправляем уведомление #$id: $phrase');
              
              await showNotification(
                title: AppLocalizations.notificationTitle,
                body: phrase,
                withSound: settings.notificationSound,
                withVibration: settings.notificationVibration,
                progressText: progressText,
              );
            } catch (e) {
              AppConstants.debugLog('⚠️ Ошибка уведомления #$id: $e');
            }
          },
        ),
      );
      
      AppConstants.debugLog('✅ Запланировано уведомление #$i на $hour:${minute.toString().padLeft(2, '0')} (+$minutesFromNow мин)');
    }

    AppConstants.debugLog('✅ Всего запланировано $maxNotificationsPerDay уведомлений каждые $minutesInterval минут');
  }

  /// Отменить все уведомления
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    AppConstants.debugLog('✅ Все уведомления отменены');
  }

  /// Отправить тестовое уведомление
  Future<void> sendTestNotification() async {
    if (!_initialized) await init();

    final phraseService = PhraseService();
    final storageService = StorageService();
    final settings = await storageService.loadSettings();
    
    final testPhrase = phraseService.getRandomPhrase(settings.toxicityLevel);
    final currentCount = await storageService.getDrankCounter();
    final progressText = '$currentCount/${settings.glassesCount} 💧';
    
    await showNotification(
      title: '🧪 Тестовое уведомление',
      body: testPhrase,
      withSound: settings.notificationSound,
      withVibration: settings.notificationVibration,
      progressText: progressText,
    );
    
    AppConstants.debugLog('✅ Тестовое уведомление отправлено');
  }
}
