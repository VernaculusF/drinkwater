import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Сервис для работы с фразами из JSON
class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  Map<String, List<String>>? _phrases;
  final Random _random = Random();

  /// Загрузка фраз из JSON файла
  Future<void> loadPhrases() async {
    if (_phrases != null) return; // Уже загружены

    try {
      final String jsonString = await rootBundle.loadString('assets/phrases.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      
      _phrases = {
        'light': List<String>.from(jsonData['light'] ?? []),
        'medium': List<String>.from(jsonData['medium'] ?? []),
        'toxic': List<String>.from(jsonData['toxic'] ?? []),
      };
    } catch (e) {
      print('Ошибка загрузки фраз: $e');
      // Фразы-заглушки на случай ошибки
      _phrases = {
        'light': ['Попей водички'],
        'medium': ['Не забывай про воду'],
        'toxic': ['Серьёзно, попей уже воды'],
      };
    }
  }

  /// Получить случайную фразу по уровню токсичности
  String getRandomPhrase(String toxicityLevel) {
    if (_phrases == null) {
      return 'Загрузка...';
    }

    final phrases = _phrases![toxicityLevel] ?? _phrases!['medium']!;
    if (phrases.isEmpty) {
      return 'Пора пить воду!';
    }

    return phrases[_random.nextInt(phrases.length)];
  }

  /// Получить все фразы для уровня токсичности
  List<String> getPhrasesForLevel(String toxicityLevel) {
    if (_phrases == null) return [];
    return _phrases![toxicityLevel] ?? [];
  }
}
