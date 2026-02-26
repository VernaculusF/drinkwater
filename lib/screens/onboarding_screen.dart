import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

/// Экран первоначальной настройки (онбординга)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late StorageService _storage;
  late NotificationService _notificationService;
  
  int _selectedGlasses = AppConstants.defaultGlassesCount;
  String _selectedToxicity = AppConstants.defaultToxicityLevel;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _storage = StorageService();
    _notificationService = NotificationService();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _complete() async {
    // Сохраняем настройки
    final settings = AppSettings(
      glassesCount: _selectedGlasses,
      drankToday: 0,
      lastResetDate: DateTime.now().toString().split(' ')[0],
      intervalHours: AppConstants.defaultIntervalHours,
      quietStartHour: AppConstants.defaultQuietStartHour,
      quietEndHour: AppConstants.defaultQuietEndHour,
      toxicityLevel: _selectedToxicity,
      notificationsEnabled: true,
      notificationSound: true,
      notificationVibration: true,
      userWeight: null,
    );

    await _storage.saveSettings(settings);
    await _notificationService.init();
    await _notificationService.scheduleNotifications(intervalHours: settings.intervalHours);

    if (mounted) {
      // Переходим на главный экран без возможности вернуться
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Страница 1: Выбор нормы воды
          _buildGlassesPage(),
          // Страница 2: Выбор тональности напоминаний
          _buildToxicityPage(),
        ],
      ),
    );
  }

  Widget _buildGlassesPage() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '💧 Сколько стаканов воды в день?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Это поможет нам настроить частоту напоминаний',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Фото количества стаканов
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppConstants.primaryColor.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        '$_selectedGlasses',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Слайдер для выбора
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Slider(
                          value: _selectedGlasses.toDouble(),
                          min: 4,
                          max: 16,
                          divisions: 12,
                          label: _selectedGlasses.toString(),
                          activeColor: AppConstants.primaryColor,
                          onChanged: (value) {
                            setState(() => _selectedGlasses = value.toInt());
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('4 стакана'),
                            const Text('16 стаканов'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Text(
                    '${_selectedGlasses * AppConstants.glassVolumeML} мл в день',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Кнопки навигации
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ElevatedButton(
                    onPressed: _complete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Пропустить',
                      style: TextStyle(color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Индикаторы страниц
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 0
                            ? AppConstants.primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 1
                            ? AppConstants.primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Далее',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToxicityPage() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '📢 Как часто напоминать?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Выбери тональность напоминаний',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Вариант 1: Лайт
                  _buildToxicityOption(
                    emoji: '😊',
                    title: 'Лайт',
                    description: 'Мягко и вежливо напоминает',
                    value: 'light',
                  ),
                  const SizedBox(height: 16),
                  
                  // Вариант 2: Средний
                  _buildToxicityOption(
                    emoji: '😐',
                    title: 'Средний',
                    description: 'Обычные напоминания (рекомендуется)',
                    value: 'medium',
                  ),
                  const SizedBox(height: 16),
                  
                  // Вариант 3: Токсичный
                  _buildToxicityOption(
                    emoji: '😠',
                    title: 'Суровый',
                    description: 'Не даст тебе скучать',
                    value: 'toxic',
                  ),
                ],
              ),
            ),
          ),
          // Кнопки навигации
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ElevatedButton(
                    onPressed: _previousPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Назад',
                      style: TextStyle(color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Индикаторы страниц
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 0
                            ? AppConstants.primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == 1
                            ? AppConstants.primaryColor
                            : Colors.grey[300],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ElevatedButton(
                    onPressed: _complete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Готово',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToxicityOption({
    required String emoji,
    required String title,
    required String description,
    required String value,
  }) {
    final isSelected = _selectedToxicity == value;
    
    return GestureDetector(
      onTap: () {
        setState(() => _selectedToxicity = value);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppConstants.primaryColor.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.primaryColor,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
