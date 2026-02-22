import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'dart:async';
import 'dart:typed_data';
import '../constants/app_localizations.dart';
import 'phrase_service.dart';
import 'storage_service.dart';

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
    );

    _initialized = true;
  }

  /// Обработка нажатия на уведомление или его кнопки
  void _onNotificationTap(NotificationResponse response) {
    print('📲 Уведомление активировано: actionId=${response.actionId}, payload=${response.payload}');
    
    // Обработка нажатия на кнопку "ВЫПИЛ" или саму уведомление
    if (response.actionId == 'DRINK_ACTION' || response.payload == 'water_reminder') {
      // Вызываем callback если он установлен
      if (onNotificationTapped != null) {
        onNotificationTapped!('water_reminder');
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
  }) async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      'water_reminder', // ID канала
      AppLocalizations.notificationTitle, // Название канала
      channelDescription: AppLocalizations.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: null, // Используем стандартный звук системы
      vibrationPattern: withVibration ? Int64List.fromList([0, 250, 250, 250]) : null,
      playSound: withSound,
      enableVibration: withVibration,
      styleInformation: const BigTextStyleInformation(''),
      // Добавляем кнопку действия "ВЫПИЛ"
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
      0, // ID уведомления
      title,
      body,
      notificationDetails,
      payload: 'water_reminder',
    );
  }

  /// Запланировать периодические уведомления - МАКСИМАЛЬНО ПРОСТАЯ ВЕРСИЯ
  Future<void> scheduleNotifications({
    required double intervalHours,
  }) async {
    if (!_initialized) await init();

    // Отменяем все предыдущие уведомления
    await _notifications.cancelAll();

    final phraseService = PhraseService();
    final storageService = StorageService();
    final settings = await storageService.loadSettings();

    int minutesInterval = (intervalHours * 60).toInt();
    if (minutesInterval < 1) minutesInterval = 1;
    
    // Считаем количество уведомлений на 24 часа
    int totalNotifications = (1440 / minutesInterval).ceil();
    totalNotifications = totalNotifications.clamp(0, 100);
    
    print('📋 Планируем $totalNotifications уведомлений каждые $minutesInterval минут');
    
    // Планируем уведомления через Future.delayed
    for (int i = 0; i < totalNotifications; i++) {
      // БЕЗ первого уведомления через 5 сек - сразу по интервалу
      int delaySeconds = minutesInterval * 60 * (i + 1);
      
      final phrase = phraseService.getRandomPhrase(settings.toxicityLevel);

      // Планируем в фоне, не ждем завершения
      Future.delayed(
        Duration(seconds: delaySeconds),
        () async {
          try {
            await showNotification(
              title: AppLocalizations.notificationTitle,
              body: phrase,
              withSound: true,
              withVibration: true,
            );
          } catch (e) {
            print('⚠️ Ошибка отправки уведомления #$i: $e');
          }
        },
      );
    }

    print('✅ Запланировано $totalNotifications уведомлений каждые ${intervalHours.toStringAsFixed(2)} часов');
  }

  /// Отменить все уведомления
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    print('✅ Все уведомления отменены');
  }

  /// Отправить тестовое уведомление
  Future<void> sendTestNotification() async {
    if (!_initialized) await init();

    final phraseService = PhraseService();
    final storageService = StorageService();
    final settings = await storageService.loadSettings();
    
    final testPhrase = phraseService.getRandomPhrase(settings.toxicityLevel);
    
    await showNotification(
      title: '🧪 Тестовое уведомление',
      body: testPhrase,
      withSound: true,
      withVibration: true,
    );
    
    print('✅ Тестовое уведомление отправлено');
  }
}

