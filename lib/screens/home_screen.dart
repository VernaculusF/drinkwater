import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/phrase_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_localizations.dart';
import '../widgets/confetti_widget.dart';
import 'settings_screen.dart';

/// Главный экран приложения
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final PhraseService _phraseService = PhraseService();
  final WidgetService _widgetService = WidgetService();
  final NotificationService _notificationService = NotificationService();
  
  AppSettings? _settings;
  String _currentPhrase = '';
  bool _isLoading = true;
  bool _showConfetti = false;
  bool _isPressed = false; // Запрет повторного нажатия
  DateTime? _lastPressTime; // Время последнего нажатия
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Обработка нажатия на уведомление
    _notificationService.onNotificationTapped = (payload) {
      if (payload == 'water_reminder') {
        print('💧 Вызов выпил из уведомления');
        _onDrinkPressed();
      }
    };
    
    // Анимация для кнопки
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Загрузка данных при запуске
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    await _phraseService.loadPhrases();
    final settings = await _storage.loadSettings();
    
    // Инициализируем WidgetService
    await _widgetService.init();
    await _widgetService.initializeWidget();
    
    // Если уведомления включены, запланируем их
    if (settings.notificationsEnabled) {
      await _notificationService.scheduleNotifications(
        intervalHours: settings.intervalHours,
      );
    }
    
    setState(() {
      _settings = settings;
      // Не показываем фразу при первой загрузке
      _currentPhrase = '';
      _isLoading = false;
      _lastPressTime = DateTime.now();
    });
  }

  /// Проверка, истекло ли время (показывать ли текст)
  bool _shouldShowTimeoutMessage() {
    if (_lastPressTime == null || _settings == null) return false;
    
    final elapsedMinutes = DateTime.now().difference(_lastPressTime!).inMinutes;
    final intervalMinutes = (_settings!.intervalHours * 60).toInt();
    
    // Показываем текст только если прошло больше установленного интервала
    return elapsedMinutes >= intervalMinutes;
  }

  /// Обработка нажатия кнопки "ВЫПИЛ"
  Future<void> _onDrinkPressed() async {
    if (_settings == null || _isPressed) return;

    _isPressed = true; // Устанавливаем флаг СРАЗУ, не через setState

    try {
      // Параллельно: haptic + animation (не ждём друг друга)
      await Future.wait([
        HapticFeedback.mediumImpact().catchError((_) {}),
        _animationController.forward().then((_) => _animationController.reverse()),
      ], eagerError: false);

      // Увеличиваем счётчик
      final newCount = await _storage.incrementDrankCounter();
      _lastPressTime = DateTime.now(); // ВАЖНО: запомнить время нажатия
      final isGoalReached = newCount >= _settings!.glassesCount;
      
      // Один setState вместо двух
      if (mounted) {
        setState(() {
          _settings = _settings!.copyWith(drankToday: newCount);
          _currentPhrase = _phraseService.getRandomPhrase(_settings!.toxicityLevel);
          if (isGoalReached) _showConfetti = true;
        });
      }
      
      // Обновляем виджет БЕЗ завтра результата (async в фоне)
      _widgetService.updateWidget();
    } finally {
      // БЛОКИРУЕМ КНОПКУ НА ВРЕМЯ ИНТЕРВАЛА (из настроек)
      final lockDurationSeconds = (_settings!.intervalHours * 3600).toInt();
      await Future.delayed(Duration(seconds: lockDurationSeconds));
      
      _isPressed = false;
      if (mounted) setState(() {});
      
      print('✅ Кнопка разблокирована (была заблокирована на ${_settings!.intervalHours.toStringAsFixed(1)} часов)');
    }
  }

  /// Переход в настройки
  Future<void> _openSettings() async {
    if (_settings == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentSettings: _settings!),
      ),
    );

    // Если настройки изменились, обновляем экран
    if (result == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = _settings!.progress;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppConstants.darkBackground : AppConstants.lightBackground,
      appBar: AppBar(
        title: Text(AppLocalizations.appTitle),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: AppLocalizations.settings,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Счётчик
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    '${_settings!.drankToday} / ${_settings!.glassesCount}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),

                // Прогресс-бар с улучшенным стилем
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 24,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Процент
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(),

                // Большая кнопка ВЫПИЛ
                Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: GestureDetector(
                      onTap: _isPressed ? null : _onDrinkPressed,
                      child: Opacity(
                        opacity: _isPressed ? 0.6 : 1.0,
                        child: Container(
                          width: AppConstants.buttonSize,
                          height: AppConstants.buttonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppConstants.primaryColor, AppConstants.accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primaryColor.withOpacity(_isPressed ? 0.2 : 0.5),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: AppConstants.accentColor.withOpacity(_isPressed ? 0.15 : 0.3),
                                blurRadius: 15,
                                offset: const Offset(5, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'ВЫПИЛ',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Стёбная подпись (только при просрочке времени)
                if (_shouldShowTimeoutMessage())
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    child: Text(
                      _currentPhrase,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                // Место для баннера (заглушка)
                Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '[ AdMob баннер v1.2 ]',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          
          // Конфетти при достижении цели
          if (_showConfetti)
            ConfettiWidget(
              show: _showConfetti,
              duration: const Duration(seconds: 3),
              onComplete: () {
                if (mounted) {
                  setState(() => _showConfetti = false);
                }
              },
            ),
        ],
      ),
    );
  }
}
