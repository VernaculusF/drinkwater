import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_localizations.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  final AppSettings currentSettings;

  const SettingsScreen({
    super.key,
    required this.currentSettings,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  final NotificationService _notificationService = NotificationService();
  
  late AppSettings _settings;
  bool _isWeightMode = false; // Режим расчёта по весу или вручную
  bool _isSaving = false; // Флаг сохранения настроек
  
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _glassesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settings = widget.currentSettings;
    _isWeightMode = _settings.userWeight != null;
    
    if (_isWeightMode && _settings.userWeight != null) {
      _weightController.text = _settings.userWeight!.toStringAsFixed(0);
    } else {
      _glassesController.text = _settings.glassesCount.toString();
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _glassesController.dispose();
    super.dispose();
  }

  /// Сохранение настроек
  Future<void> _saveSettings() async {
    if (_isSaving) return; // Предотвращаем повторное нажатие
    
    setState(() => _isSaving = true);
    
    try {
      await _storage.saveSettings(_settings);
      
      // Обновляем уведомления
      if (_settings.notificationsEnabled) {
        await _notificationService.scheduleNotifications(
          intervalHours: _settings.intervalHours,
        );
      } else {
        await _notificationService.cancelAllNotifications();
      }

      if (mounted) {
        Navigator.pop(context, true); // Возвращаем true = настройки изменены
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Переключение режима ввода нормы
  void _toggleWeightMode(bool? value) {
    setState(() {
      _isWeightMode = value ?? false;
    });
  }

  /// Применение нормы по весу
  void _applyWeightNorm() {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.invalidWeight)),
      );
      return;
    }

    final glasses = AppConstants.calculateGlassesByWeight(weight);
    setState(() {
      _settings = _settings.copyWith(
        glassesCount: glasses,
        userWeight: weight,
      );
    });
  }

  /// Применение нормы вручную
  void _applyManualNorm() {
    final glasses = int.tryParse(_glassesController.text);
    if (glasses == null || glasses <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.invalidGlasses)),
      );
      return;
    }

    setState(() {
      _settings = _settings.copyWith(glassesCount: glasses);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.settings),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSettings,
              tooltip: AppLocalizations.save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Норма воды
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.waterNorm,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Переключатель режима
                  SwitchListTile(
                    title: Text(AppLocalizations.calculateByWeight),
                    subtitle: Text(AppLocalizations.formula),
                    value: _isWeightMode,
                    onChanged: _toggleWeightMode,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Ввод по весу
                  if (_isWeightMode) ...[
                    TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.yourWeight,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _applyWeightNorm,
                      child: Text(AppLocalizations.applyButton),
                    ),
                  ],
                  
                  // Ввод вручную
                  if (!_isWeightMode) ...[
                    TextField(
                      controller: _glassesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.glassesCount,
                        border: const OutlineInputBorder(),
                        helperText: AppLocalizations.glassVolume,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _applyManualNorm,
                      child: Text(AppLocalizations.applyButton),
                    ),
                  ],
                  
                  const SizedBox(height: 8),
                  Text(
                    '${AppLocalizations.currentNorm} ${_settings.glassesCount} ${AppLocalizations.glasses} (${_settings.glassesCount * AppConstants.glassVolumeML} мл)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Уведомления
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.notifications,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  
                  SwitchListTile(
                    title: Text(AppLocalizations.enableNotifications),
                    value: _settings.notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(notificationsEnabled: value);
                      });
                    },
                  ),
                  
                  const Divider(),
                  
                  // Интервал напоминаний
                  ListTile(
                    title: Text(AppLocalizations.reminderInterval),
                    subtitle: Text('${AppConstants.formatInterval(_settings.intervalHours)}'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: AppConstants.availableIntervals.map((hours) {
                      return ChoiceChip(
                        label: Text(AppConstants.formatInterval(hours)),
                        selected: _settings.intervalHours == hours,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _settings = _settings.copyWith(intervalHours: hours);
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  const Divider(),
                  
                  // Тихие часы
                  ListTile(
                    title: Text(AppLocalizations.quietHours),
                    subtitle: Text(
                      '${AppLocalizations.from} ${_settings.quietStartHour}:00 ${AppLocalizations.to} ${_settings.quietEndHour}:00',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: Text(AppLocalizations.from),
                          subtitle: Text('${_settings.quietStartHour}:00'),
                          onTap: () async {
                            final hour = await _selectHour(context, _settings.quietStartHour);
                            if (hour != null) {
                              setState(() {
                                _settings = _settings.copyWith(quietStartHour: hour);
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          title: Text(AppLocalizations.to),
                          subtitle: Text('${_settings.quietEndHour}:00'),
                          onTap: () async {
                            final hour = await _selectHour(context, _settings.quietEndHour);
                            if (hour != null) {
                              setState(() {
                                _settings = _settings.copyWith(quietEndHour: hour);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(),
                  
                  // Звук уведомлений
                  SwitchListTile(
                    title: const Text('Звук'),
                    subtitle: const Text('Воспроизводить звук при уведомлении'),
                    value: _settings.notificationSound,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(notificationSound: value);
                      });
                    },
                  ),
                  
                  // Вибрация
                  SwitchListTile(
                    title: const Text('Вибрация'),
                    subtitle: const Text('Включать вибрацию при уведомлении'),
                    value: _settings.notificationVibration,
                    onChanged: (value) {
                      setState(() {
                        _settings = _settings.copyWith(notificationVibration: value);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Токсичность
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.toxicity,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.toxicityDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  RadioListTile<String>(
                    title: Text(AppLocalizations.toxicityLight),
                    value: 'light',
                    groupValue: _settings.toxicityLevel,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _settings = _settings.copyWith(toxicityLevel: value);
                        });
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(AppLocalizations.toxicityMedium),
                    value: 'medium',
                    groupValue: _settings.toxicityLevel,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _settings = _settings.copyWith(toxicityLevel: value);
                        });
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(AppLocalizations.toxicityToxic),
                    value: 'toxic',
                    groupValue: _settings.toxicityLevel,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _settings = _settings.copyWith(toxicityLevel: value);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Кнопка сброса счётчика
          OutlinedButton.icon(
            onPressed: () async {
              await _storage.resetDailyCounter();
              setState(() {
                _settings = _settings.copyWith(drankToday: 0);
              });
            },
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.resetCounter),
          ),

          const SizedBox(height: 8),

          // Кнопка тестового уведомления
          OutlinedButton.icon(
            onPressed: () async {
              await _notificationService.sendTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🧪 Тестовое уведомление отправлено')),
                );
              }
            },
            icon: const Icon(Icons.notifications),
            label: const Text('Тестовое уведомление'),
          ),
        ],
      ),
    );
  }

  /// Выбор часа
  Future<int?> _selectHour(BuildContext context, int currentHour) async {
    int? selectedHour;
    
    await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите час'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: ListView.builder(
            itemCount: 24,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('$index:00'),
                selected: index == currentHour,
                onTap: () {
                  selectedHour = index;
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
    
    return selectedHour;
  }
}
