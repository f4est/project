import 'package:flutter/material.dart';
import 'package:project/src/app/app_dependencies.dart';
import 'package:project/src/core/app_theme.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/presentation/pages/root_page.dart';

class HomeWorkoutAiApp extends StatefulWidget {
  const HomeWorkoutAiApp({
    super.key,
    this.dependenciesBuilder = AppDependencies.create,
  });

  final AppDependencies Function() dependenciesBuilder;

  @override
  State<HomeWorkoutAiApp> createState() => _HomeWorkoutAiAppState();
}

class _HomeWorkoutAiAppState extends State<HomeWorkoutAiApp> {
  late final AppDependencies _dependencies;
  late final AppSettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependenciesBuilder();
    _settingsController = AppSettingsController();
    _settingsController.load();
  }

  @override
  void dispose() {
    _dependencies.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, _) {
        final settings = _settingsController.settings;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FitPilot Home AI',
          theme: buildAppTheme(fontScale: settings.fontScale),
          home: RootPage(
            sessionController: _dependencies.sessionController,
            planController: _dependencies.planController,
            settingsController: _settingsController,
          ),
        );
      },
    );
  }
}
