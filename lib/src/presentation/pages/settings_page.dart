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
            ],
          ),
        );
      },
    );
  }
}
