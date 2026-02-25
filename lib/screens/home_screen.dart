import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/phrase_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../services/ad_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_localizations.dart';
import '../constants/responsive_design.dart';
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
  final AdService _adService = AdService();
  
  AppSettings? _settings;
  String _currentPhrase = '';
  bool _isLoading = true;
  bool _showConfetti = false;
  bool _isPressed = false; // Запрет повторного нажатия
  DateTime? _lastPressTime; // Время последнего нажатия
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  String? _bannerError;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Обработка нажатия на уведомление
    _notificationService.onNotificationTapped = (payload) {
      if (payload == 'water_reminder') {
        AppConstants.debugLog('💧 Вызов выпил из уведомления');
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
    _adService.disposeBanner();
    super.dispose();
  }

  /// Загрузка данных при запуске
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final settings = await _storage.loadSettings();
    
    // Инициализируем WidgetService
    await _widgetService.init();
    await _widgetService.initializeWidget();
    
    // Инициализируем рекламу после первого кадра (нужен MediaQuery)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initAds();
      }
    });
    
    // Проверяем и переплануем уведомления если нужно (при смене дня)
    // Это гарантирует, что если день изменился, уведомления будут переплануированы
    try {
      final lastScheduleDate = await _storage.getLastScheduleDate();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      if (lastScheduleDate != today) {
        AppConstants.debugLog('📅 Смена дня, переплануем уведомления');
      }
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка при проверке дня: $e');
    }
    
    // Если уведомления включены, запланируем их
    if (settings.notificationsEnabled) {
      await _notificationService.scheduleNotifications(
        intervalHours: settings.intervalHours,
      );
    } else {
      await _notificationService.cancelAllNotifications();
    }
    
    setState(() {
      _settings = settings;
      // Не показываем фразу при первой загрузке
      _currentPhrase = '';
      _isLoading = false;
    });
    
    // Загружаем время последнего нажатия
    _lastPressTime = await _storage.getLastDrinkTime();
    
    // Если кнопка была нажата, проверяем нужно ли ее разблокировать
    if (_lastPressTime != null) {
      _isPressed = true; // Считаем что была нажата
      _startUnlockTimer(); // Запускаем проверку разблокировки
    }
  }

  /// Инициализация рекламы
  Future<void> _initAds() async {
    if (_bannerAd != null) return;

    try {
      await _adService.init();

      final screenWidth = MediaQuery.of(context).size.width.toInt();
      
      final bannerAd = _adService.createBanner(
        adUnitId: AppConstants.yandexAdBannerUnitId,
        adSize: BannerAdSize.inline(
          width: screenWidth,
          maxHeight: 60,
        ),
        onAdLoaded: () {
          setState(() {
            _isBannerLoaded = true;
            _bannerError = null;
          });
        },
        onAdFailedToLoad: (error) {
          print('⚠️ Не удалось загрузить баннер: $error');
          setState(() {
            _isBannerLoaded = false;
            _bannerError = error;
          });
        },
      );
      if (mounted) {
        setState(() {
          _bannerAd = bannerAd;
          _isBannerLoaded = false;
          _bannerError = null;
        });
      }
    } catch (e) {
      print('⚠️ Ошибка инициализации рекламы: $e');
    }

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
      
      // Переплануем уведомления для оставшихся стаканов
      _notificationService.scheduleNotifications(
        intervalHours: _settings!.intervalHours,
        enabled: _settings!.notificationsEnabled,
      );
      
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
      
      // Запускаем периодическую проверку для разблокировки кнопки
      _startUnlockTimer();
    } catch (e) {
      AppConstants.debugLog('⚠️ Ошибка при обработке нажатия: $e');
      _isPressed = false;
      if (mounted) setState(() {});
    }
  }

  /// Запустить таймер для разблокировки кнопки
  void _startUnlockTimer() {
    // Проверяем каждые 10 секунд, не пора ли разблокировать кнопку
    Future.delayed(Duration(seconds: 10), () {
      if (!mounted || _settings == null) return;
      
      final now = DateTime.now();
      if (_lastPressTime != null) {
        final elapsed = now.difference(_lastPressTime!);
        final lockDuration = Duration(hours: _settings!.intervalHours.toInt(), 
                                       minutes: ((_settings!.intervalHours % 1) * 60).toInt());
        
        if (elapsed >= lockDuration) {
          _isPressed = false;
          if (mounted) {
            setState(() {});
            AppConstants.debugLog('✅ Кнопка разблокирована через ${elapsed.inMinutes} минут');
          }
        } else {
          // Еще не время - проверяем снова
          _startUnlockTimer();
        }
      }
    });
  }

  /// Переход в настройки
  Future<void> _openSettings() async {
    if (_settings == null) return;

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            SettingsScreen(currentSettings: _settings!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Плавная анимация с fade + slight slide
          const begin = Offset(0.0, 0.03);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          
          var slideTween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: curve),
          );
          
          return SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
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
    
    // Инициализируем адаптивный дизайн
    final responsive = ResponsiveDesign(context);

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
                  padding: EdgeInsets.symmetric(vertical: responsive.spacing),
                  child: Text(
                    '${_settings!.drankToday} / ${_settings!.glassesCount}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: responsive.counterFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                ),

                // Прогресс-бар с улучшенным стилем
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: responsive.horizontalPadding),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: responsive.progressBarHeight,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                    ),
                  ),
                ),

                SizedBox(height: responsive.spacing),

                // Процент
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: responsive.bodyFontSize + 2,
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
                          width: responsive.buttonSize,
                          height: responsive.buttonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppConstants.primaryColor, AppConstants.accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primaryColor.withValues(alpha: _isPressed ? 51 : 128),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                              BoxShadow(
                                color: AppConstants.accentColor.withValues(alpha: _isPressed ? 38 : 77),
                                blurRadius: 15,
                                offset: const Offset(5, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'ВЫПИЛ',
                              style: TextStyle(
                                fontSize: responsive.buttonFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: const [
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
                    padding: EdgeInsets.symmetric(
                      horizontal: responsive.horizontalPadding,
                      vertical: responsive.spacing,
                    ),
                    child: Text(
                      _currentPhrase,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: responsive.bodyFontSize,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),

                // Баннер Яндекс РСЯ
                if (_bannerAd != null)
                  Container(
                    alignment: Alignment.center,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AdWidget(bannerAd: _bannerAd!),
                        if (!_isBannerLoaded)
                          Text(
                            _bannerError == null
                                ? 'Загрузка рекламы...'
                                : 'Ошибка рекламы: $_bannerError',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'Загрузка рекламы...',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
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
