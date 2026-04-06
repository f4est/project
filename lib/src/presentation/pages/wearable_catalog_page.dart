import 'package:flutter/material.dart';
import 'package:project/src/presentation/controllers/wearables_controller.dart';
import 'package:project/src/presentation/pages/wearable_instructions_page.dart';

class WearableCatalogPage extends StatelessWidget {
  const WearableCatalogPage({super.key, required this.controller});

  final WearablesController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Подключение устройств')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Сначала подключите системное приложение здоровья на телефоне '
                    '(Health Connect на Android или Apple Health на iPhone), затем часы или браслет.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              for (final source in controller.sources) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.health_and_safety_outlined),
                            const SizedBox(width: 8),
                            Expanded(child: Text(source.title)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(source.subtitle),
                        const SizedBox(height: 4),
                        Text('Статус: ${source.status}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => WearableInstructionsPage(
                                      sourceId: source.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.menu_book_outlined),
                              label: const Text('Инструкция'),
                            ),
                            const SizedBox(width: 8),
                            if (source.connected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            else
                              FilledButton(
                                onPressed: () =>
                                    controller.connectSource(source.id),
                                child: const Text('Подключить'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
