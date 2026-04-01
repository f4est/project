import 'dart:math';

import 'package:flutter/material.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/presentation/controllers/plan_controller.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';
import 'package:project/src/presentation/pages/live_workout_page.dart';
import 'package:project/src/presentation/pages/settings_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({
    super.key,
    required this.user,
    required this.planController,
    required this.sessionController,
    required this.settingsController,
  });

  final AuthUser user;
  final PlanController planController;
  final SessionController sessionController;
  final AppSettingsController settingsController;

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
      animation: widget.planController,
      builder: (context, _) {
        final plan = widget.planController.plan;
        final profile = widget.planController.profile;
        final progress = widget.planController.progressStats;
        final isLoading = widget.planController.isLoading;
        final error = widget.planController.errorMessage;

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
            onOpenVideo: _openExerciseVideo,
            onStartLiveControl: _startLiveControlForDay,
          ),
          _AnalyticsTab(progress: progress, plan: plan),
          _ProfileTab(
            user: widget.user,
            profile: profile,
            onSave: (value) => widget.planController.saveProfile(value),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_titleForIndex(_tabIndex)),
            actions: [
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
      2 => 'Аналитика',
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveWorkoutPage(
          dayPlan: dayPlan,
          appSettings: widget.settingsController.settings,
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
    return ListView(
      key: const Key('planList'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'План на сегодня',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(today?.title ?? 'Тренировка загружается'),
                const SizedBox(height: 6),
                Text(
                  today == null
                      ? '...'
                      : '${today.estimatedMinutes} мин • Интенсивность ${today.intensityPercent}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AI-рекомендации',
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
        'Фокус недели: ${profile.goal.label.toLowerCase()}. Рекомендуем ${profile.sessionsPerWeek} тренировки по ${profile.sessionDurationMinutes} минут.',
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
          'Можно постепенно увеличить объем: +1 подход в базовых упражнениях.',
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
    required this.onOpenVideo,
    required this.onStartLiveControl,
  });

  final WeeklyWorkoutPlan? plan;
  final Future<void> Function(String url) onOpenVideo;
  final Future<void> Function(DailyWorkoutPlan dayPlan) onStartLiveControl;

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plan!.dailyPlans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final day = plan!.dailyPlans[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text('${day.estimatedMinutes} мин'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => onStartLiveControl(day),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Live-контроль тренировки'),
                ),
                const SizedBox(height: 8),
                for (final exercise in day.exercises.take(4))
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
                      trailing: IconButton(
                        onPressed: () => onOpenVideo(exercise.videoUrl),
                        icon: const Icon(Icons.play_circle_outline),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
          subtitle: 'Стабильность повышает точность AI-рекомендаций.',
        ),
        const SizedBox(height: 16),
        Text(
          'Пояснения алгоритма',
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
    required this.onSave,
  });

  final AuthUser user;
  final UserProfile? profile;
  final Future<void> Function(UserProfile profile) onSave;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 26,
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName.substring(0, 1).toUpperCase()
                  : 'A',
            ),
          ),
          title: Text(user.displayName),
          subtitle: Text(user.email),
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
