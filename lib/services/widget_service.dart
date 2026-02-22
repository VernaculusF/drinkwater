import 'package:home_widget/home_widget.dart';
import 'storage_service.dart';
import 'phrase_service.dart';

/// Сервис для работы с home screen виджетом
class WidgetService {
  static final WidgetService _instance = WidgetService._internal();
  factory WidgetService() => _instance;
  WidgetService._internal();

  final StorageService _storage = StorageService();
  final PhraseService _phraseService = PhraseService();

  /// Инициализация сервиса виджета
  Future<void> init() async {
    try {
      // Инициализируем home_widget
      print('✅ WidgetService инициализирован');
    } catch (e) {
      print('❌ Ошибка инициализации WidgetService: $e');
    }
  }

  /// Обновить данные виджета (вызывать после каждого нажатия на кнопку)
  Future<void> updateWidget() async {
    try {
      final settings = await _storage.loadSettings();
      final phrase = _phraseService.getRandomPhrase(settings.toxicityLevel);
      
      // Батчим все операции в один запрос для оптимизации
      await Future.wait([
        HomeWidget.saveWidgetData<int>('progress_drank', settings.drankToday),
        HomeWidget.saveWidgetData<int>('progress_total', settings.glassesCount),
        HomeWidget.saveWidgetData<String>('phrase', phrase),
      ]);
      
      // Уведомляем систему об обновлении виджета
      await HomeWidget.updateWidget(name: 'DrinkWaterWidget');
      
      print('✅ Виджет обновлён: ${settings.drankToday} / ${settings.glassesCount}');
    } catch (e) {
      print('❌ Ошибка обновления виджета: $e');
    }
  }

  /// Инициализировать виджет при запуске приложения
  Future<void> initializeWidget() async {
    try {
      final settings = await _storage.loadSettings();
      final phrase = _phraseService.getRandomPhrase(settings.toxicityLevel);
      
      // Сохраняем данные
      await HomeWidget.saveWidgetData<int>(
        'progress_drank',
        settings.drankToday,
      );
      
      await HomeWidget.saveWidgetData<int>(
        'progress_total',
        settings.glassesCount,
      );
      
      await HomeWidget.saveWidgetData<String>(
        'phrase',
        phrase,
      );
      
      print('✅ Виджет инициализирован');
    } catch (e) {
      print('⚠️ Ошибка инициализации данных виджета: $e');
    }
  }

  /// Получить строку прогресса для вывода в виджете
  String getProgressString(int drank, int total) {
    return '$drank / $total';
  }

  /// Получить процент прогресса
  int getProgressPercent(int drank, int total) {
    if (total == 0) return 0;
    return ((drank / total) * 100).toInt();
  }
}
