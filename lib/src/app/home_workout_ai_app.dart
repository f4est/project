import 'package:flutter/material.dart';
import 'package:project/src/app/app_dependencies.dart';
import 'package:project/src/background/wearable_sync_worker.dart';
import 'package:project/src/core/app_theme.dart';
import 'package:project/src/core/time_sync_controller.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/presentation/controllers/wearables_controller.dart';
import 'package:project/src/presentation/pages/root_page.dart';

class HomeWorkoutAiApp extends StatefulWidget {
  const HomeWorkoutAiApp({
    super.key,
    this.dependenciesBuilder = AppDependencies.create,
  });

  final AppDependencies Function({DateTime Function()? clock})
  dependenciesBuilder;

  @override
  State<HomeWorkoutAiApp> createState() => _HomeWorkoutAiAppState();
}

class _HomeWorkoutAiAppState extends State<HomeWorkoutAiApp> {
  late final AppDependencies _dependencies;
  late final TimeSyncController _timeSyncController;
  late final AppSettingsController _settingsController;
  late final WearablesController _wearablesController;
  bool? _lastAutoSyncEnabled;

  @override
  void initState() {
    super.initState();
    _timeSyncController = TimeSyncController();
    _timeSyncController.initialize();
    _dependencies = widget.dependenciesBuilder(clock: _timeSyncController.now);
    _settingsController = AppSettingsController();
    _settingsController.load();
    _wearablesController = WearablesController(clock: _timeSyncController.now);
    _wearablesController.initialize();
  }

  @override
  void dispose() {
    _dependencies.dispose();
    _timeSyncController.dispose();
    _settingsController.dispose();
    _wearablesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (context, _) {
        final settings = _settingsController.settings;
        if (_lastAutoSyncEnabled != settings.autoSyncWearables) {
          _lastAutoSyncEnabled = settings.autoSyncWearables;
          configureWearableAutoSync(enabled: settings.autoSyncWearables);
        }
        final themeMode = switch (settings.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FitPilot',
          theme: buildAppTheme(fontScale: settings.fontScale),
          darkTheme: buildDarkAppTheme(fontScale: settings.fontScale),
          themeMode: themeMode,
          home: RootPage(
            sessionController: _dependencies.sessionController,
            planController: _dependencies.planController,
            settingsController: _settingsController,
            wearablesController: _wearablesController,
            timeSyncController: _timeSyncController,
          ),
        );
      },
    );
  }
}
