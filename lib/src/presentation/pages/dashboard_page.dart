import 'package:flutter/material.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/presentation/controllers/plan_controller.dart';
import 'package:project/src/presentation/controllers/session_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.planController,
    required this.sessionController,
  });

  final AuthUser user;
  final PlanController planController;
  final SessionController sessionController;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.planController.loadForUser(widget.user);
    });
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      widget.planController.loadForUser(widget.user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.sessionController,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: widget.planController,
          builder: (context, child) {
            final plan = widget.planController.plan;
            final progress = widget.planController.progressStats;
            final isLoading = widget.planController.isLoading;
            final error = widget.planController.errorMessage;

            return Scaffold(
              appBar: AppBar(
                title: Text('FitPilot • ${widget.user.displayName}'),
                actions: [
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
                  child: ListView(
                    key: const Key('planList'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    children: [
                      _TopBanner(userName: widget.user.displayName),
                      const SizedBox(height: 12),
                      if (progress != null) ...[
                        _ProgressCard(progress: progress),
                        const SizedBox(height: 12),
                      ],
                      if (isLoading) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 12),
                      ],
                      if (error != null) ...[
                        Text(
                          error,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (plan != null) ...[
                        _PlanSummaryCard(plan: plan),
                        const SizedBox(height: 12),
                        for (final day in plan.dailyPlans) ...[
                          _DayCard(
                            day: day,
                            onOpenVideo: _openExerciseVideo,
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          key: const Key('finishWorkoutButton'),
                          onPressed: _showFeedbackDialog,
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Завершить тренировку и дать фидбек'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    var completed = true;
    var difficulty = 6.0;
    var fatigue = 6.0;
    var enjoyment = 7.0;
    var minutes = 35.0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Отчёт после тренировки',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Тренировка выполнена'),
                      value: completed,
                      onChanged: (value) {
                        setModalState(() => completed = value);
                      },
                    ),
                    _SliderField(
                      label: 'Сложность',
                      value: difficulty,
                      onChanged: (value) => setModalState(() => difficulty = value),
                    ),
                    _SliderField(
                      label: 'Усталость',
                      value: fatigue,
                      onChanged: (value) => setModalState(() => fatigue = value),
                    ),
                    _SliderField(
                      label: 'Удовлетворённость',
                      value: enjoyment,
                      onChanged: (value) => setModalState(() => enjoyment = value),
                    ),
                    _SliderField(
                      label: 'Длительность (мин)',
                      value: minutes,
                      min: 10,
                      max: 120,
                      divisions: 22,
                      onChanged: (value) => setModalState(() => minutes = value),
                    ),
                    TextField(
                      key: const Key('feedbackField'),
                      controller: feedbackController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Мнение о тренировке',
                        hintText: 'Что понравилось и что стоит скорректировать?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('submitFeedbackButton'),
                      onPressed: () async {
                        final savedCompleted = completed;
                        final savedDifficulty = difficulty.round();
                        final savedFatigue = fatigue.round();
                        final savedEnjoyment = enjoyment.round();
                        final savedMinutes = minutes.round();
                        final savedFeedback = feedbackController.text;

                        Navigator.of(sheetContext).pop();
                        await widget.planController.submitWorkoutFeedback(
                          completed: savedCompleted,
                          perceivedDifficulty: savedDifficulty,
                          fatigueLevel: savedFatigue,
                          enjoymentScore: savedEnjoyment,
                          workoutMinutes: savedMinutes,
                          feedback: savedFeedback,
                        );
                      },
                      child: const Text('Сохранить отчёт'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    feedbackController.dispose();
  }

  Future<void> _openExerciseVideo(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть видео')),
      );
    }
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваш план на неделю',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '$userName, приложение адаптирует нагрузку по вашему фидбеку после каждой тренировки.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.95)),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final ProgressStats progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Геймификация и рейтинг',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _InfoChip(text: 'Уровень ${progress.level}'),
                _InfoChip(text: progress.leagueName),
                _InfoChip(text: 'Очки ${progress.totalPoints}'),
                _InfoChip(text: 'Место #${progress.localRankPosition}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Серия: ${progress.streakDays} дней • Выполнение: ${progress.completionRatePercent}%',
            ),
            const SizedBox(height: 4),
            Text(progress.coachControlMessage),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.plan});

  final WeeklyWorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Целевая дисциплина: ${plan.adherenceTargetPercent}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final line in plan.rationale) ...[
              Text('• $line'),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.onOpenVideo,
  });

  final DailyWorkoutPlan day;
  final Future<void> Function(String url) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${day.estimatedMinutes} мин • Интенсивность ${day.intensityPercent}%'),
            const SizedBox(height: 8),
            for (final exercise in day.exercises)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                title: Text('${exercise.name} (${exercise.sets}x${exercise.reps})'),
                subtitle: Text('Отдых ${exercise.restSeconds} сек'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(exercise.description),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Как выполнять: ${exercise.executionTips}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => onOpenVideo(exercise.videoUrl),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Видео техники'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.divisions = 9,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
