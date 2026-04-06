import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WearableInstructionsPage extends StatelessWidget {
  const WearableInstructionsPage({super.key, required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(sourceId);
    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(content.description),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < content.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(content.steps[i]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final action in content.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                onPressed: () => _open(action.url, context),
                icon: Icon(action.icon),
                label: Text(action.label),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  _InstructionContent _buildContent(String sourceId) {
    if (sourceId == 'xiaomi_zepp') {
      return _InstructionContent(
        title: 'Подключение Xiaomi / Zepp',
        description:
            'Для Xiaomi-часов и браслетов данные попадают в FitPilot через системное приложение здоровья на телефоне.',
        steps: const [
          'Установите и настройте Zepp Life или Mi Fitness.',
          'В приложении Xiaomi включите синхронизацию с Health Connect (Android) или Apple Health (iOS).',
          'Откройте FitPilot и подключите Health Connect или Apple Health.',
          'Выдайте разрешения на шаги, пульс, сон, SpO2 и тренировки.',
          'Вернитесь в FitPilot и нажмите «Обновить» на экране устройств.',
        ],
        actions: const [
          _ActionLink(
            label: 'Открыть Health Connect в Play Store',
            url:
                'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
            icon: Icons.open_in_new,
          ),
          _ActionLink(
            label: 'Открыть Mi Fitness в Play Store',
            url:
                'https://play.google.com/store/apps/details?id=com.xiaomi.wearable',
            icon: Icons.watch,
          ),
          _ActionLink(
            label: 'Открыть Zepp Life в Play Store',
            url:
                'https://play.google.com/store/apps/details?id=com.xiaomi.hm.health',
            icon: Icons.watch,
          ),
        ],
      );
    }

    if (sourceId == 'health_connect') {
      return _InstructionContent(
        title: 'Подключение Health Connect',
        description:
            'Health Connect передает в FitPilot данные из приложений часов и браслетов.',
        steps: const [
          'Установите Health Connect.',
          'Один раз нажмите «Подключить» в FitPilot, чтобы приложение появилось в списке Health Connect.',
          'Подключите ваши фитнес-приложения к Health Connect.',
          'В FitPilot снова нажмите «Подключить» у Health Connect.',
          'Выдайте разрешения на чтение показателей.',
        ],
        actions: const [
          _ActionLink(
            label: 'Открыть Health Connect в Play Store',
            url:
                'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
            icon: Icons.open_in_new,
          ),
        ],
      );
    }

    return _InstructionContent(
      title: 'Инструкция по подключению',
      description:
          'Большинство устройств подключаются через Health Connect (Android) или Apple Health (iPhone).',
      steps: const [
        'Подключите системный источник здоровья.',
        'Дайте разрешения на нужные метрики.',
        'Проверьте синхронизацию в экране устройств FitPilot.',
      ],
      actions: const [],
    );
  }
}

class _InstructionContent {
  const _InstructionContent({
    required this.title,
    required this.description,
    required this.steps,
    required this.actions,
  });

  final String title;
  final String description;
  final List<String> steps;
  final List<_ActionLink> actions;
}

class _ActionLink {
  const _ActionLink({
    required this.label,
    required this.url,
    required this.icon,
  });

  final String label;
  final String url;
  final IconData icon;
}
