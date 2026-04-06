import 'dart:math';

import 'package:flutter/material.dart';
import 'package:project/src/core/time_sync_controller.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/presentation/controllers/plan_controller.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';
import 'package:project/src/presentation/controllers/wearables_controller.dart';
import 'package:project/src/presentation/pages/live_workout_page.dart';
import 'package:project/src/presentation/pages/settings_page.dart';
import 'package:project/src/presentation/pages/wearable_catalog_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.user,
    required this.planController,
    required this.sessionController,
    required this.settingsController,
    required this.wearablesController,
    required this.timeSyncController,
  });

  final AuthUser user;
  final PlanController planController;
  final SessionController sessionController;
  final AppSettingsController settingsController;
  final WearablesController wearablesController;
  final TimeSyncController timeSyncController;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.planController.loadForUser(widget.user);
    });
  }

  @override
  void didUpdateWidget(covariant AppShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      widget.planController.loadForUser(widget.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.planController,
        widget.wearablesController,
      ]),
      builder: (context, _) {
        final plan = widget.planController.plan;
        final profile = widget.planController.profile;
        final progress = widget.planController.progressStats;
        final isLoading = widget.planController.isLoading;
        final error = widget.planController.errorMessage;
        final health = widget.wearablesController.snapshot;
        final nowDate = widget.timeSyncController.now();

        final pages = <Widget>[
          _HomeTab(
            plan: plan,
            profile: profile,
            progress: progress,
            isLoading: isLoading,
            error: error,
          ),
          _WorkoutsTab(
            plan: plan,
            nowDate: nowDate,
            onOpenVideo: _openExerciseVideo,
            onStartLiveControl: _startLiveControlForDay,
            isExerciseCompleted: widget.planController.isExerciseCompleted,
            onToggleExerciseCompleted:
                ({
                  required int dayIndex,
                  required String exerciseName,
                  required bool completed,
                }) {
                  return widget.planController.markExerciseCompleted(
                    dayIndex: dayIndex,
                    exerciseName: exerciseName,
                    completed: completed,
                  );
                },
          ),
          _DevicesTab(
            controller: widget.wearablesController,
            onOpenCatalog: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WearableCatalogPage(
                    controller: widget.wearablesController,
                  ),
                ),
              );
            },
            calories: health.calories,
            steps: health.steps,
            activeMinutes: health.activeMinutes,
            walkingDistanceMeters: health.walkingDistanceMeters,
            weightKg: health.weightKg,
            sleepHours: health.sleepHours,
            sleepMinutes: health.sleepMinutes,
            heartRate: health.heartRate,
            spo2: health.spo2,
          ),
          _AnalyticsTab(progress: progress, plan: plan),
          _ProfileTab(
            user: widget.user,
            profile: profile,
            progress: progress,
            wearablesController: widget.wearablesController,
            onSave: (value) => widget.planController.saveProfile(value),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_titleForIndex(_tabIndex)),
            actions: [
              if (_tabIndex == 2)
                IconButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WearableCatalogPage(
                          controller: widget.wearablesController,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SettingsPage(controller: widget.settingsController),
                    ),
                  );
                },
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                onPressed: widget.sessionController.isBusy
                    ? null
                    : () async {
                        await widget.sessionController.signOut();
                        widget.planController.clear();
                      },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => widget.planController.loadForUser(widget.user),
              child: pages[_tabIndex],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (value) => setState(() => _tabIndex = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Тренировки',
              ),
              NavigationDestination(
                icon: Icon(Icons.watch_outlined),
                selectedIcon: Icon(Icons.watch),
                label: 'Устройства',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Аналитика',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        );
      },
    );
  }

  String _titleForIndex(int index) {
    return switch (index) {
      0 => 'FitPilot',
      1 => 'Тренировки',
      2 => 'Устройства',
      3 => 'Аналитика',
      _ => 'Профиль',
    };
  }

  Future<void> _openExerciseVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку на видео')),
      );
    }
  }

  Future<void> _startLiveControlForDay(DailyWorkoutPlan dayPlan) async {
    final liveExercises = dayPlan.exercises
        .where((e) => _supportsLiveTracking(e.name))
        .toList(growable: false);
    if (liveExercises.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Для этого упражнения пока нет проверки через камеру.',
            ),
          ),
        );
      }
      return;
    }
    final livePlan = DailyWorkoutPlan(
      dayIndex: dayPlan.dayIndex,
      title: dayPlan.title,
      focus: dayPlan.focus,
      intensityPercent: dayPlan.intensityPercent,
      estimatedMinutes: dayPlan.estimatedMinutes,
      exercises: liveExercises,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveWorkoutPage(
          dayPlan: livePlan,
          appSettings: widget.settingsController.settings,
          nowProvider: widget.timeSyncController.now,
          onSessionFinished:
              ({
                required bool completed,
                required int perceivedDifficulty,
                required int fatigueLevel,
                required int enjoymentScore,
                required int workoutMinutes,
                required String feedback,
              }) {
                return widget.planController.submitWorkoutFeedback(
                  completed: completed,
                  perceivedDifficulty: perceivedDifficulty,
                  fatigueLevel: fatigueLevel,
                  enjoymentScore: enjoymentScore,
                  workoutMinutes: workoutMinutes,
                  feedback: feedback,
                );
              },
        ),
      ),
    );
  }

  bool _supportsLiveTracking(String exerciseName) {
    final name = exerciseName.toLowerCase();
    return name.contains('присед') ||
        name.contains('поворот') ||
        name.contains('планк') ||
        name.contains('выпад') ||
        name.contains('скалолаз') ||
        name.contains('мост') ||
        name.contains('отжим') ||
        name.contains('джампинг') ||
        name.contains('высокие колени') ||
        name.contains('конькобежец') ||
        name.contains('берпи');
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.plan,
    required this.profile,
    required this.progress,
    required this.isLoading,
    required this.error,
  });

  final WeeklyWorkoutPlan? plan;
  final UserProfile? profile;
  final ProgressStats? progress;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final today = plan?.dailyPlans.firstOrNull;
    final completionRate = p == null
        ? null
        : p.totalSessions == 0
        ? 0
        : ((p.completedSessions / p.totalSessions) * 100).round();
    return ListView(
      key: const Key('planList'),
      padding: const EdgeInsets.all(16),
      children: [
        _AIPriorityCard(today: today, completionRate: completionRate),
        const SizedBox(height: 16),
        Text(
          'Рекомендации на сегодня',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        ..._buildRecommendations(profile, p, plan).map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(tip),
              ),
            ),
          ),
        ),
        if (isLoading) const Center(child: CircularProgressIndicator()),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  List<String> _buildRecommendations(
    UserProfile? profile,
    ProgressStats? progress,
    WeeklyWorkoutPlan? plan,
  ) {
    final tips = <String>[];
    if (profile != null) {
      tips.add(
        'Цель недели: ${profile.goal.label.toLowerCase()}. Рекомендуемый режим: ${profile.sessionsPerWeek} тренировки по ${profile.sessionDurationMinutes} минут.',
      );
    }
    if (progress != null) {
      final adherence = progress.totalSessions == 0
          ? 0
          : ((progress.completedSessions / progress.totalSessions) * 100)
                .round();
      tips.add(
        'Выполнение плана: $adherence%. Держите серию ${progress.streakDays} дней.',
      );
      if (adherence < 60) {
        tips.add(
          'Снизьте нагрузку на 10% и закрепите регулярность в ближайшие 3 дня.',
        );
      } else {
        tips.add(
          'Можно постепенно увеличить нагрузку: +1 подход в базовых упражнениях.',
        );
      }
    }
    if (plan != null && plan.rationale.isNotEmpty) {
      tips.add(plan.rationale.first);
    }
    return tips.isEmpty
        ? const ['Собираем ваши данные для персональных рекомендаций.']
        : tips.take(4).toList();
  }
}

class _WorkoutsTab extends StatelessWidget {
  const _WorkoutsTab({
    required this.plan,
    required this.nowDate,
    required this.onOpenVideo,
    required this.onStartLiveControl,
    required this.isExerciseCompleted,
    required this.onToggleExerciseCompleted,
  });

  final WeeklyWorkoutPlan? plan;
  final DateTime nowDate;
  final Future<void> Function(String url) onOpenVideo;
  final Future<void> Function(DailyWorkoutPlan dayPlan) onStartLiveControl;
  final bool Function(int dayIndex, String exerciseName) isExerciseCompleted;
  final Future<void> Function({
    required int dayIndex,
    required String exerciseName,
    required bool completed,
  })
  onToggleExerciseCompleted;

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final plans = plan!.dailyPlans;
    final weekStart = _startOfWeek(nowDate);
    final availableDayCount = min(plans.length, nowDate.weekday);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < plans.length; i++) ...[
          _buildDayCard(
            context: context,
            day: plans[i],
            dayDate: weekStart.add(Duration(days: i)),
            unlocked: i < availableDayCount,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildDayCard({
    required BuildContext context,
    required DailyWorkoutPlan day,
    required DateTime dayDate,
    required bool unlocked,
  }) {
    final dayLabel = _formatDate(dayDate);
    if (!unlocked) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(day.title),
          subtitle: Text('Откроется $dayLabel'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('$dayLabel • ${day.estimatedMinutes} мин'),
            const SizedBox(height: 10),
            for (final exercise in day.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    '${exercise.name} (${exercise.sets}x${exercise.reps})',
                  ),
                  subtitle: Text('Отдых ${exercise.restSeconds} сек'),
                  trailing: SizedBox(
                    width: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Checkbox(
                          value: isExerciseCompleted(
                            day.dayIndex,
                            exercise.name,
                          ),
                          onChanged: (value) {
                            onToggleExerciseCompleted(
                              dayIndex: day.dayIndex,
                              exerciseName: exercise.name,
                              completed: value ?? false,
                            );
                          },
                        ),
                        if (_isLiveSupportedExercise(exercise.name))
                          IconButton(
                            tooltip: 'Контроль техники',
                            onPressed: () {
                              final singleExercisePlan = DailyWorkoutPlan(
                                dayIndex: day.dayIndex,
                                title: '${day.title} • ${exercise.name}',
                                focus: day.focus,
                                intensityPercent: day.intensityPercent,
                                estimatedMinutes: day.estimatedMinutes,
                                exercises: [exercise],
                              );
                              onStartLiveControl(singleExercisePlan);
                            },
                            icon: const Icon(Icons.videocam_outlined),
                          ),
                        IconButton(
                          onPressed: () => onOpenVideo(exercise.videoUrl),
                          icon: const Icon(Icons.play_circle_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    return '$dd.$mm.${value.year}';
  }

  DateTime _startOfWeek(DateTime now) {
    final date = DateTime(now.year, now.month, now.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isLiveSupportedExercise(String exerciseName) {
    final name = exerciseName.toLowerCase();
    return name.contains('присед') ||
        name.contains('поворот') ||
        name.contains('планк') ||
        name.contains('выпад') ||
        name.contains('скалолаз') ||
        name.contains('мост') ||
        name.contains('отжим') ||
        name.contains('джампинг') ||
        name.contains('высокие колени') ||
        name.contains('конькобежец') ||
        name.contains('берпи');
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.progress, required this.plan});

  final ProgressStats? progress;
  final WeeklyWorkoutPlan? plan;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final adherence = p.totalSessions == 0
        ? 0
        : ((p.completedSessions / p.totalSessions) * 100).round();
    final readiness =
        (55 + min(35, adherence / 2) + min(10, p.streakDays.toDouble()))
            .clamp(0, 100)
            .round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(
          title: 'Готовность к нагрузке',
          value: '$readiness%',
          subtitle: 'Расчет на основе завершенных тренировок и регулярности.',
        ),
        const SizedBox(height: 12),
        _MetricCard(
          title: 'Выполнение плана',
          value: '$adherence%',
          subtitle:
              '${p.completedSessions} из ${p.totalSessions} тренировок выполнено.',
        ),
        const SizedBox(height: 12),
        _MetricCard(
          title: 'Серия',
          value: '${p.streakDays} дн',
          subtitle: 'Стабильность повышает точность персональных рекомендаций.',
        ),
        const SizedBox(height: 16),
        Text(
          'Почему выбран именно такой план',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        for (final item in (plan?.rationale ?? const <String>[]).take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _DevicesTab extends StatelessWidget {
  const _DevicesTab({
    required this.controller,
    required this.onOpenCatalog,
    required this.calories,
    required this.steps,
    required this.activeMinutes,
    required this.walkingDistanceMeters,
    required this.weightKg,
    required this.sleepHours,
    required this.sleepMinutes,
    required this.heartRate,
    required this.spo2,
  });

  final WearablesController controller;
  final Future<void> Function() onOpenCatalog;
  final int calories;
  final int steps;
  final int activeMinutes;
  final int walkingDistanceMeters;
  final double weightKg;
  final int sleepHours;
  final int sleepMinutes;
  final int heartRate;
  final int spo2;

  @override
  Widget build(BuildContext context) {
    final connected = controller.sources.where((s) => s.connected).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Панель здоровья',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: controller.isSyncing
                          ? null
                          : controller.refresh,
                      icon: controller.isSyncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HealthChip(
                      label: 'Калории',
                      value: calories > 0 ? '$calories ккал' : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Шаги',
                      value: steps > 0 ? '$steps' : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Активность',
                      value: activeMinutes > 0
                          ? '$activeMinutes мин'
                          : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Дистанция',
                      value: walkingDistanceMeters > 0
                          ? '$walkingDistanceMeters м'
                          : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Вес',
                      value: weightKg > 0
                          ? '${weightKg.toStringAsFixed(1)} кг'
                          : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Сон',
                      value: sleepHours > 0 || sleepMinutes > 0
                          ? '$sleepHours ч $sleepMinutes мин'
                          : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Пульс',
                      value: heartRate > 0 ? '$heartRate уд/мин' : 'Нет данных',
                    ),
                    _HealthChip(
                      label: 'Кислород (SpO2)',
                      value: spo2 > 0 ? '$spo2%' : 'Нет данных',
                    ),
                  ],
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (controller.actionHint != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Что сделать: ${controller.actionHint!}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (controller.errorMessage != null &&
                    controller.actionHint == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Проверьте: 1) разрешения в Health Connect, 2) синхронизацию в приложении браслета, 3) обновление данных на этом экране.',
                    ),
                  ),
                ],
                if (controller.lastSyncAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Последняя синхронизация: ${_formatTime(controller.lastSyncAt!)}',
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_link),
            title: const Text('Подключить устройство'),
            subtitle: const Text(
              'Откроется каталог подключения часов и браслетов.',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onOpenCatalog,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Подключенные устройства',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (connected.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Пока нет подключенных устройств. Нажмите кнопку "+" вверху, чтобы добавить источник данных.',
              ),
            ),
          ),
        for (final source in connected) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.watch),
              title: Text(source.title),
              subtitle: Text(source.status),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text(
          'История показателей по дням',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (controller.history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'История появится после первой успешной синхронизации.',
              ),
            ),
          ),
        for (final day in controller.history.take(14)) ...[
          Card(
            child: ListTile(
              title: Text(_formatDate(day.date)),
              subtitle: Text(
                'Шаги ${day.steps} • Калории ${day.calories} • Сон ${day.sleepHours}ч ${day.sleepMinutes}м',
              ),
              trailing: Text(
                day.heartRate > 0 ? '${day.heartRate} уд/мин' : '—',
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime dateTime) {
    final dd = dateTime.day.toString().padLeft(2, '0');
    final mm = dateTime.month.toString().padLeft(2, '0');
    return '$dd.$mm.${dateTime.year}';
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.profile,
    required this.progress,
    required this.wearablesController,
    required this.onSave,
  });

  final AuthUser user;
  final UserProfile? profile;
  final ProgressStats? progress;
  final WearablesController wearablesController;
  final Future<void> Function(UserProfile profile) onSave;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final stats = progress;
    final points = stats?.totalPoints ?? 0;
    final level = stats?.level ?? 1;
    final pointsInLevel = points % 1000;
    final levelProgress = (pointsInLevel / 1000).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName.substring(0, 1).toUpperCase()
                          : 'A',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Динамика активности (последние 7 дней)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (wearablesController.history.isEmpty)
                  const Text(
                    'Пока нет сохраненной истории. Подключите устройство и выполните синхронизацию.',
                  )
                else
                  for (final day in wearablesController.history.take(7))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${day.date.day.toString().padLeft(2, '0')}.${day.date.month.toString().padLeft(2, '0')}',
                              ),
                            ),
                            Expanded(child: Text('Шаги ${day.steps}')),
                            Expanded(child: Text('Ккал ${day.calories}')),
                            Expanded(
                              child: Text(
                                'Пульс ${day.heartRate > 0 ? day.heartRate : '—'}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Прогресс профиля',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Уровень $level • ${stats?.leagueName ?? 'Новичок'}',
                      ),
                    ),
                    Text('$points XP'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: levelProgress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 8),
                Text(
                  'До следующего уровня: ${1000 - pointsInLevel} XP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniMetricChip(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Серия',
                      value: '${stats?.streakDays ?? 0} дн',
                    ),
                    _MiniMetricChip(
                      icon: Icons.check_circle_outline,
                      label: 'Выполнено',
                      value:
                          '${stats?.completedSessions ?? 0}/${stats?.totalSessions ?? 0}',
                    ),
                    _MiniMetricChip(
                      icon: Icons.timeline_outlined,
                      label: 'Дисциплина',
                      value: '${stats?.completionRatePercent ?? 0}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(label: 'Возраст', value: '${p.age}'),
                    ),
                    Expanded(
                      child: _ProfileStat(
                        label: 'Рост',
                        value: '${p.heightCm.toStringAsFixed(0)} см',
                      ),
                    ),
                    Expanded(
                      child: _ProfileStat(
                        label: 'Вес',
                        value: '${p.weightKg.toStringAsFixed(0)} кг',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Цель: ${p.goal.label}'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Режим: ${p.sessionsPerWeek} р/нед по ${p.sessionDurationMinutes} мин',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Занятие: ${p.occupation}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _openEditSheet(context, p, onSave),
          child: const Text('Редактировать профиль'),
        ),
      ],
    );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    UserProfile p,
    Future<void> Function(UserProfile profile) onSave,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: p.name);
    final ageCtrl = TextEditingController(text: '${p.age}');
    final heightCtrl = TextEditingController(
      text: p.heightCm.toStringAsFixed(0),
    );
    final weightCtrl = TextEditingController(
      text: p.weightKg.toStringAsFixed(0),
    );
    final occupationCtrl = TextEditingController(text: p.occupation);
    final injuryCtrl = TextEditingController(text: p.injuryNotes);

    var goal = p.goal;
    var level = p.fitnessLevel;
    var lifestyle = p.lifestyleType;
    var sessions = p.sessionsPerWeek;
    var duration = p.sessionDurationMinutes;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Редактирование профиля',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Имя'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(labelText: 'Возраст'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: heightCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Рост (см)',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: weightCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Вес (кг)',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TrainingGoal>(
                        initialValue: goal,
                        decoration: const InputDecoration(labelText: 'Цель'),
                        items: TrainingGoal.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => goal = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<FitnessLevel>(
                        initialValue: level,
                        decoration: const InputDecoration(labelText: 'Уровень'),
                        items: FitnessLevel.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => level = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<LifestyleType>(
                        initialValue: lifestyle,
                        decoration: const InputDecoration(
                          labelText: 'Образ жизни',
                        ),
                        items: LifestyleType.values
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => lifestyle = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: occupationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Чем занимаетесь',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: sessions.toDouble(),
                              min: 2,
                              max: 7,
                              divisions: 5,
                              label: '$sessions раз/нед',
                              onChanged: (v) =>
                                  setState(() => sessions = v.round()),
                            ),
                          ),
                          SizedBox(width: 86, child: Text('$sessions р/нед')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: duration.toDouble(),
                              min: 20,
                              max: 90,
                              divisions: 14,
                              label: '$duration мин',
                              onChanged: (v) =>
                                  setState(() => duration = v.round()),
                            ),
                          ),
                          SizedBox(width: 86, child: Text('$duration мин')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: injuryCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Ограничения / травмы',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final age =
                                int.tryParse(ageCtrl.text.trim()) ?? p.age;
                            final height =
                                double.tryParse(heightCtrl.text.trim()) ??
                                p.heightCm;
                            final weight =
                                double.tryParse(weightCtrl.text.trim()) ??
                                p.weightKg;
                            final updated = p.copyWith(
                              name: nameCtrl.text.trim().isEmpty
                                  ? p.name
                                  : nameCtrl.text.trim(),
                              age: age.clamp(10, 99),
                              heightCm: height.clamp(120, 230),
                              weightKg: weight.clamp(35, 200),
                              goal: goal,
                              fitnessLevel: level,
                              lifestyleType: lifestyle,
                              occupation: occupationCtrl.text.trim(),
                              sessionsPerWeek: sessions,
                              sessionDurationMinutes: duration,
                              injuryNotes: injuryCtrl.text.trim(),
                            );
                            await onSave(updated);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    ageCtrl.dispose();
    heightCtrl.dispose();
    weightCtrl.dispose();
    occupationCtrl.dispose();
    injuryCtrl.dispose();
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label),
      ],
    );
  }
}

class _AIPriorityCard extends StatelessWidget {
  const _AIPriorityCard({required this.today, required this.completionRate});

  final DailyWorkoutPlan? today;
  final int? completionRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Интеллектуальный план на сегодня',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(today?.title ?? 'Подбираем тренировку'),
            const SizedBox(height: 6),
            Text(
              today == null
                  ? 'Собираем историю активности.'
                  : '${today!.estimatedMinutes} мин • Интенсивность ${today!.intensityPercent}%',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniMetricChip(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Подбор плана',
                  value: 'Включён',
                ),
                _MiniMetricChip(
                  icon: Icons.track_changes_outlined,
                  label: 'Цель',
                  value: today?.focus.label ?? '...',
                ),
                _MiniMetricChip(
                  icon: Icons.check_circle_outline,
                  label: 'Выполнение',
                  value: completionRate == null ? '...' : '$completionRate%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetricChip extends StatelessWidget {
  const _MiniMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text('$label: $value'),
        ],
      ),
    );
  }
}
