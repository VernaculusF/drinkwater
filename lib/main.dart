import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'constants/app_constants.dart';
import 'constants/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация сервисов
  await _initializeServices();
  
  runApp(const DrinkWaterApp());
}

/// Инициализация всех сервисов при запуске
Future<void> _initializeServices() async {
  try {
    // SharedPreferences
    final storageService = StorageService();
    await storageService.init();
    
    // Уведомления - инициализируем ВСЕГДА
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermission();
    
    print(AppLocalizations.allServicesInitialized);
  } catch (e) {
    print('${AppLocalizations.initializationError} $e');
  }
}

/// Главный виджет приложения
class DrinkWaterApp extends StatelessWidget {
  const DrinkWaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppLocalizations.appTitle,
      debugShowCheckedModeBanner: false,
      
      // Светлая тема
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      
      // Тёмная тема
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        scaffoldBackgroundColor: AppConstants.darkBackground,
      ),
      
      // Автоматический выбор темы по системе
      themeMode: ThemeMode.system,
      
      home: const HomeScreen(),
    );
  }
}
