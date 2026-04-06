import 'package:flutter/material.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Настройки')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Голос тренера',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('Оформление', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'system', label: Text('Система')),
                  ButtonSegment(value: 'light', label: Text('Светлая')),
                  ButtonSegment(value: 'dark', label: Text('Тёмная')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (value) {
                  controller.update(settings.copyWith(themeMode: value.first));
                },
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'female', label: Text('Женский')),
                  ButtonSegment(value: 'male', label: Text('Мужской')),
                ],
                selected: {settings.voiceGender},
                onSelectionChanged: (value) {
                  controller.update(
                    settings.copyWith(voiceGender: value.first),
                  );
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'warm', label: Text('Мягкий')),
                  ButtonSegment(value: 'energetic', label: Text('Энергичный')),
                  ButtonSegment(value: 'neutral', label: Text('Нейтральный')),
                ],
                selected: {settings.voiceStyle},
                onSelectionChanged: (value) {
                  controller.update(settings.copyWith(voiceStyle: value.first));
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Тренировки и устройства',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile.adaptive(
                title: const Text('Голосовые подсказки'),
                subtitle: const Text(
                  'Подсказки по технике и прогрессу в реальном времени',
                ),
                value: settings.audioCoachEnabled,
                onChanged: (v) =>
                    controller.update(settings.copyWith(audioCoachEnabled: v)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Вибрация на этапах тренировки'),
                value: settings.vibrationEnabled,
                onChanged: (v) =>
                    controller.update(settings.copyWith(vibrationEnabled: v)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Автосинхронизация часов и браслетов'),
                value: settings.autoSyncWearables,
                onChanged: (v) =>
                    controller.update(settings.copyWith(autoSyncWearables: v)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Использовать данные сна'),
                value: settings.includeSleepData,
                onChanged: (v) =>
                    controller.update(settings.copyWith(includeSleepData: v)),
              ),
              SwitchListTile.adaptive(
                title: const Text('Использовать данные SpO2'),
                value: settings.includeOxygenData,
                onChanged: (v) =>
                    controller.update(settings.copyWith(includeOxygenData: v)),
              ),
              const SizedBox(height: 8),
              Text(
                'Размер шрифта',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Slider(
                value: settings.fontScale,
                min: 0.85,
                max: 1.2,
                divisions: 7,
                label: '${(settings.fontScale * 100).round()}%',
                onChanged: (v) => controller.update(
                  settings.copyWith(
                    fontScale: double.parse(v.toStringAsFixed(2)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                title: const Text('Режим приватности'),
                subtitle: const Text(
                  'Скрывать личные данные и ограничивать подробную статистику',
                ),
                value: settings.privacyMode,
                onChanged: (v) =>
                    controller.update(settings.copyWith(privacyMode: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}
