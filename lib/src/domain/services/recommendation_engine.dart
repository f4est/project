import 'dart:math';

import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';

class RecommendationEngine {
  RecommendationEngine();

  int get catalogSize => _catalog.length;

  WeeklyWorkoutPlan buildWeeklyPlan({
    required UserProfile profile,
    required List<WorkoutSessionResult> recentSessions,
    required DateTime generatedAt,
  }) {
    final sessions = recentSessions.take(30).toList(growable: false);
    final completionRate = _completionRate(sessions);
    final avgDifficulty = _average(
      sessions.map((e) => e.perceivedDifficulty),
      fallback: 6,
    );
    final avgFatigue = _average(
      sessions.map((e) => e.fatigueLevel),
      fallback: 5,
    );
    final avgEnjoyment = _average(
      sessions.map((e) => e.enjoymentScore),
      fallback: 7,
    );

    final readiness = _readiness(
      completionRate: completionRate,
      avgDifficulty: avgDifficulty,
      avgFatigue: avgFatigue,
      avgEnjoyment: avgEnjoyment,
    );
    final plannedSessions = _targetSessions(
      requested: profile.sessionsPerWeek,
      level: profile.fitnessLevel,
      completionRate: completionRate,
      avgFatigue: avgFatigue,
      avgEnjoyment: avgEnjoyment,
    );
    final focusSequence = _focusSequence(
      profile.goal,
      plannedSessions,
      readiness,
    );

    final baselineIntensity = _baselineIntensity(
      profile: profile,
      completionRate: completionRate,
      avgDifficulty: avgDifficulty,
      avgFatigue: avgFatigue,
      avgEnjoyment: avgEnjoyment,
    );

    final seed = generatedAt.millisecondsSinceEpoch ^ profile.userId.hashCode;
    final random = Random(seed);
    final usedRecently = <String>{};

    final dailyPlans = <DailyWorkoutPlan>[];
    for (var i = 0; i < plannedSessions; i++) {
      final focus = focusSequence[i];
      final intensity = _dailyIntensity(
        baseline: baselineIntensity,
        focus: focus,
        dayIndex: i,
        completionRate: completionRate,
      );
      final minutes = _duration(
        target: profile.sessionDurationMinutes,
        focus: focus,
        intensity: intensity,
      );
      final exercises = _selectExercises(
        profile: profile,
        focus: focus,
        intensity: intensity,
        minutes: minutes,
        random: random,
        usedRecently: usedRecently,
      );
      dailyPlans.add(
        DailyWorkoutPlan(
          dayIndex: i + 1,
          title: 'День ${i + 1}: ${focus.label}',
          focus: focus,
          intensityPercent: intensity,
          estimatedMinutes: minutes,
          exercises: exercises,
        ),
      );
    }

    final adherenceTarget =
        (72 +
                ((completionRate - 0.7) * 35) -
                ((avgFatigue - 5) * 4) +
                ((readiness - 60) / 10))
            .round()
            .clamp(60, 92);

    return WeeklyWorkoutPlan(
      generatedAt: generatedAt,
      dailyPlans: dailyPlans,
      adherenceTargetPercent: adherenceTarget,
      rationale: _rationale(
        profile: profile,
        completionRate: completionRate,
        avgDifficulty: avgDifficulty,
        avgFatigue: avgFatigue,
        avgEnjoyment: avgEnjoyment,
        readiness: readiness,
        plannedSessions: plannedSessions,
        baselineIntensity: baselineIntensity,
      ),
    );
  }

  double _completionRate(List<WorkoutSessionResult> sessions) {
    if (sessions.isEmpty) {
      return 0.78;
    }
    final completed = sessions.where((s) => s.completed).length;
    return completed / sessions.length;
  }

  double _average(Iterable<int> values, {required int fallback}) {
    final list = values.toList(growable: false);
    if (list.isEmpty) {
      return fallback.toDouble();
    }
    return list.reduce((a, b) => a + b) / list.length;
  }

  int _readiness({
    required double completionRate,
    required double avgDifficulty,
    required double avgFatigue,
    required double avgEnjoyment,
  }) {
    final raw =
        100 -
        ((avgFatigue - 5).clamp(0, 5) * 8) -
        ((avgDifficulty - 6).clamp(0, 4) * 5) +
        ((avgEnjoyment - 6).clamp(0, 4) * 4) -
        ((0.72 - completionRate).clamp(0, 0.72) * 40);
    return raw.round().clamp(42, 94);
  }

  int _targetSessions({
    required int requested,
    required FitnessLevel level,
    required double completionRate,
    required double avgFatigue,
    required double avgEnjoyment,
  }) {
    var sessions = requested;
    if (completionRate < 0.58 || avgFatigue >= 8) {
      sessions -= 1;
    } else if (completionRate > 0.9 && avgFatigue <= 5 && avgEnjoyment >= 7) {
      sessions += 1;
    }
    final maxByLevel = switch (level) {
      FitnessLevel.beginner => 5,
      FitnessLevel.intermediate => 6,
      FitnessLevel.advanced => 7,
    };
    return sessions.clamp(3, maxByLevel);
  }

  List<WorkoutFocus> _focusSequence(
    TrainingGoal goal,
    int sessions,
    int readiness,
  ) {
    final template = switch (goal) {
      TrainingGoal.muscleGain => const [
        WorkoutFocus.strength,
        WorkoutFocus.strength,
        WorkoutFocus.mobility,
        WorkoutFocus.strength,
        WorkoutFocus.recovery,
        WorkoutFocus.cardio,
        WorkoutFocus.mixed,
      ],
      TrainingGoal.weightLoss => const [
        WorkoutFocus.cardio,
        WorkoutFocus.strength,
        WorkoutFocus.mixed,
        WorkoutFocus.cardio,
        WorkoutFocus.mobility,
        WorkoutFocus.strength,
        WorkoutFocus.recovery,
      ],
      TrainingGoal.endurance => const [
        WorkoutFocus.cardio,
        WorkoutFocus.cardio,
        WorkoutFocus.strength,
        WorkoutFocus.mixed,
        WorkoutFocus.mobility,
        WorkoutFocus.cardio,
        WorkoutFocus.recovery,
      ],
      TrainingGoal.mobility => const [
        WorkoutFocus.mobility,
        WorkoutFocus.recovery,
        WorkoutFocus.mobility,
        WorkoutFocus.mixed,
        WorkoutFocus.strength,
        WorkoutFocus.mobility,
        WorkoutFocus.cardio,
      ],
    };
    final result = <WorkoutFocus>[];
    for (var i = 0; i < sessions; i++) {
      var focus = template[i % template.length];
      if (readiness < 55 && focus == WorkoutFocus.cardio) {
        focus = WorkoutFocus.mixed;
      }
      if (readiness < 50 && focus == WorkoutFocus.strength) {
        focus = WorkoutFocus.mobility;
      }
      result.add(focus);
    }
    return result;
  }

  int _baselineIntensity({
    required UserProfile profile,
    required double completionRate,
    required double avgDifficulty,
    required double avgFatigue,
    required double avgEnjoyment,
  }) {
    final level = switch (profile.fitnessLevel) {
      FitnessLevel.beginner => 50,
      FitnessLevel.intermediate => 62,
      FitnessLevel.advanced => 72,
    };
    final goal = switch (profile.goal) {
      TrainingGoal.weightLoss => 2,
      TrainingGoal.muscleGain => 6,
      TrainingGoal.endurance => 4,
      TrainingGoal.mobility => -5,
    };
    final adherenceAdj = ((completionRate - 0.75) * 22).round();
    final fatigueAdj = ((6 - avgFatigue) * 3).round();
    final enjoyAdj = ((avgEnjoyment - 6) * 2).round();
    final diffAdj = ((7 - avgDifficulty) * 2).round();
    return (level + goal + adherenceAdj + fatigueAdj + enjoyAdj + diffAdj)
        .clamp(42, 88);
  }

  int _dailyIntensity({
    required int baseline,
    required WorkoutFocus focus,
    required int dayIndex,
    required double completionRate,
  }) {
    final shift = switch (focus) {
      WorkoutFocus.strength => 8,
      WorkoutFocus.cardio => 6,
      WorkoutFocus.mixed => 4,
      WorkoutFocus.mobility => -6,
      WorkoutFocus.recovery => -10,
    };
    final wave = (dayIndex % 3) * 2 - 2;
    var value = baseline + shift + wave;
    if (completionRate < 0.6) {
      value = min(value, 55);
    }
    return value.clamp(40, 92);
  }

  int _duration({
    required int target,
    required WorkoutFocus focus,
    required int intensity,
  }) {
    final focusAdj = switch (focus) {
      WorkoutFocus.strength => 4,
      WorkoutFocus.cardio => 2,
      WorkoutFocus.mixed => 3,
      WorkoutFocus.mobility => -3,
      WorkoutFocus.recovery => -5,
    };
    final intensityAdj = ((intensity - 60) / 8).round();
    return (target + focusAdj + intensityAdj).clamp(20, 95);
  }

  List<WorkoutExercise> _selectExercises({
    required UserProfile profile,
    required WorkoutFocus focus,
    required int intensity,
    required int minutes,
    required Random random,
    required Set<String> usedRecently,
  }) {
    final targetCount = (minutes / 7).round().clamp(5, 9);
    final candidates =
        _catalog
            .where(
              (e) => e.focuses.contains(focus) || focus == WorkoutFocus.mixed,
            )
            .where((e) => _levelAllowed(profile.fitnessLevel, e.level))
            .where(
              (e) => _equipmentAllowed(profile.availableEquipment, e.equipment),
            )
            .where((e) => _injurySafe(e, profile.injuryNotes))
            .toList()
          ..shuffle(random);

    final selected = <_ExerciseTemplate>[];
    for (final candidate in candidates) {
      if (selected.length >= targetCount) break;
      final repeated = usedRecently.contains(candidate.name);
      final samePattern = selected
          .where((e) => e.pattern == candidate.pattern)
          .length;
      if (repeated && random.nextDouble() < 0.8) continue;
      if (samePattern >= 3) continue;
      selected.add(candidate);
    }
    if (selected.length < 4) {
      for (final fallback in _catalog) {
        if (selected.any((x) => x.name == fallback.name)) continue;
        selected.add(fallback);
        if (selected.length >= 4) break;
      }
    }

    final output = selected
        .map(
          (e) => WorkoutExercise(
            name: e.name,
            description: e.description,
            executionTips: e.tips,
            videoUrl: e.videoUrl,
            sets: _sets(profile.fitnessLevel, intensity, e),
            reps: _reps(profile.fitnessLevel, intensity, e),
            restSeconds: _rest(intensity, e),
            equipment: e.equipment,
          ),
        )
        .toList(growable: false);

    usedRecently
      ..clear()
      ..addAll(output.map((e) => e.name).take(8));
    return output;
  }

  bool _levelAllowed(FitnessLevel userLevel, FitnessLevel exerciseLevel) {
    if (userLevel == FitnessLevel.advanced) return true;
    if (userLevel == FitnessLevel.intermediate) {
      return exerciseLevel != FitnessLevel.advanced;
    }
    return exerciseLevel == FitnessLevel.beginner;
  }

  bool _equipmentAllowed(Set<EquipmentType> available, EquipmentType needed) {
    if (needed == EquipmentType.bodyweight || needed == EquipmentType.yogaMat) {
      return true;
    }
    return available.contains(needed);
  }

  bool _injurySafe(_ExerciseTemplate e, String notesRaw) {
    final notes = notesRaw.toLowerCase();
    if (notes.isEmpty) return true;
    if ((notes.contains('колен') || notes.contains('knee')) &&
        e.tags.contains('knee_load')) {
      return false;
    }
    if ((notes.contains('спин') ||
            notes.contains('поясниц') ||
            notes.contains('back')) &&
        e.tags.contains('back_load')) {
      return false;
    }
    if ((notes.contains('плеч') || notes.contains('shoulder')) &&
        e.tags.contains('shoulder_load')) {
      return false;
    }
    return true;
  }

  int _sets(FitnessLevel level, int intensity, _ExerciseTemplate e) {
    final base = switch (level) {
      FitnessLevel.beginner => e.minSets,
      FitnessLevel.intermediate => ((e.minSets + e.maxSets) / 2).round(),
      FitnessLevel.advanced => e.maxSets,
    };
    final bonus = intensity >= 78 ? 1 : 0;
    return (base + bonus).clamp(2, 6);
  }

  int _reps(FitnessLevel level, int intensity, _ExerciseTemplate e) {
    final base = switch (level) {
      FitnessLevel.beginner => e.minReps,
      FitnessLevel.intermediate => ((e.minReps + e.maxReps) / 2).round(),
      FitnessLevel.advanced => e.maxReps,
    };
    final modulation = intensity >= 80
        ? 2
        : intensity <= 52
        ? -2
        : 0;
    return max(6, base + modulation);
  }

  int _rest(int intensity, _ExerciseTemplate e) {
    final shift = intensity >= 80
        ? -8
        : intensity <= 55
        ? 12
        : 0;
    return (e.baseRest + shift).clamp(20, 120);
  }

  List<String> _rationale({
    required UserProfile profile,
    required double completionRate,
    required double avgDifficulty,
    required double avgFatigue,
    required double avgEnjoyment,
    required int readiness,
    required int plannedSessions,
    required int baselineIntensity,
  }) {
    final completionPercent = (completionRate * 100).round();
    final load = avgFatigue >= 8 || avgDifficulty >= 8
        ? 'Система снизила нагрузку и добавила восстановительные блоки из-за высокой утомляемости.'
        : avgEnjoyment >= 8 && completionRate > 0.85
        ? 'Система увеличила прогрессию, так как вы стабильно переносите нагрузку.'
        : 'Система держит умеренную прогрессию для стабильного прогресса без перегруза.';

    return [
      'План учитывает цель: ${profile.goal.label}, уровень: ${profile.fitnessLevel.label} и ваш режим.',
      'Оценка готовности: $readiness/100, недельная цель: $plannedSessions тренировок.',
      'История: выполнение $completionPercent%, сложность ${avgDifficulty.toStringAsFixed(1)}/10, усталость ${avgFatigue.toStringAsFixed(1)}/10, удовольствие ${avgEnjoyment.toStringAsFixed(1)}/10.',
      'Базовая интенсивность недели: $baselineIntensity%.',
      load,
      'Упражнения подбираются под доступный инвентарь и ограничения по травмам.',
    ];
  }
}

class _ExerciseTemplate {
  const _ExerciseTemplate({
    required this.name,
    required this.description,
    required this.tips,
    required this.videoUrl,
    required this.focuses,
    required this.level,
    required this.equipment,
    required this.minSets,
    required this.maxSets,
    required this.minReps,
    required this.maxReps,
    required this.baseRest,
    required this.pattern,
    this.tags = const <String>{},
  });

  final String name;
  final String description;
  final String tips;
  final String videoUrl;
  final Set<WorkoutFocus> focuses;
  final FitnessLevel level;
  final EquipmentType equipment;
  final int minSets;
  final int maxSets;
  final int minReps;
  final int maxReps;
  final int baseRest;
  final String pattern;
  final Set<String> tags;
}

const _catalog = <_ExerciseTemplate>[
  _ExerciseTemplate(
    name: 'Приседания',
    description: 'Базовое упражнение для ног и корпуса.',
    tips: 'Колени по линии стоп, спина ровная.',
    videoUrl:
        'https://www.youtube.com/results?search_query=bodyweight+squat+technique',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 10,
    maxReps: 18,
    baseRest: 55,
    pattern: 'squat',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Гоблет-присед',
    description: 'Присед с весом перед грудью.',
    tips: 'Локти под весом, движение вниз контролируемое.',
    videoUrl:
        'https://www.youtube.com/results?search_query=goblet+squat+technique',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 14,
    baseRest: 70,
    pattern: 'squat',
    tags: {'knee_load', 'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Выпады назад',
    description: 'Нагрузка на квадрицепс, ягодицы и баланс.',
    tips: 'Корпус вертикально, шаг назад умеренный.',
    videoUrl:
        'https://www.youtube.com/results?search_query=reverse+lunge+technique',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 14,
    baseRest: 60,
    pattern: 'lunge',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Болгарские выпады',
    description: 'Односторонняя силовая работа для ног.',
    tips: 'Таз держите ровно, движение медленное.',
    videoUrl:
        'https://www.youtube.com/results?search_query=bulgarian+split+squat',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.advanced,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 12,
    baseRest: 75,
    pattern: 'lunge',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Ягодичный мост',
    description: 'Укрепляет ягодицы и заднюю цепь.',
    tips: 'Толкайте пол пятками, фиксируйте верх.',
    videoUrl:
        'https://www.youtube.com/results?search_query=glute+bridge+exercise',
    focuses: {WorkoutFocus.strength, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 5,
    minReps: 12,
    maxReps: 20,
    baseRest: 45,
    pattern: 'bridge',
  ),
  _ExerciseTemplate(
    name: 'Отжимания от пола',
    description: 'Базовое движение для груди и трицепса.',
    tips: 'Тело в линию, локти под 45 градусов.',
    videoUrl:
        'https://www.youtube.com/results?search_query=push+up+proper+form',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 16,
    baseRest: 60,
    pattern: 'push',
    tags: {'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Отжимания с колен',
    description: 'Облегченный вариант отжиманий.',
    tips: 'Не проваливайтесь в пояснице.',
    videoUrl:
        'https://www.youtube.com/results?search_query=knee+push+up+technique',
    focuses: {WorkoutFocus.strength, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 4,
    minReps: 10,
    maxReps: 18,
    baseRest: 50,
    pattern: 'push',
  ),
  _ExerciseTemplate(
    name: 'Алмазные отжимания',
    description: 'Акцент на трицепс.',
    tips: 'Локти близко к корпусу, темп медленный.',
    videoUrl:
        'https://www.youtube.com/results?search_query=diamond+push+up+technique',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.advanced,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 6,
    maxReps: 14,
    baseRest: 70,
    pattern: 'push',
    tags: {'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Пайк-отжимания',
    description: 'Вертикальный жим на плечи.',
    tips: 'Таз выше, локти ведите назад.',
    videoUrl: 'https://www.youtube.com/results?search_query=pike+push+up',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 6,
    maxReps: 12,
    baseRest: 65,
    pattern: 'push',
    tags: {'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Тяга резинки к поясу',
    description: 'Укрепление мышц спины и лопаток.',
    tips: 'Тяните локти назад, грудь открыта.',
    videoUrl:
        'https://www.youtube.com/results?search_query=resistance+band+row+exercise',
    focuses: {WorkoutFocus.strength, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.resistanceBands,
    minSets: 3,
    maxSets: 5,
    minReps: 12,
    maxReps: 20,
    baseRest: 50,
    pattern: 'pull',
  ),
  _ExerciseTemplate(
    name: 'Тяга гантели в наклоне',
    description: 'Базовая горизонтальная тяга.',
    tips: 'Спина ровная, без рывка.',
    videoUrl: 'https://www.youtube.com/results?search_query=dumbbell+row+form',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 14,
    baseRest: 65,
    pattern: 'pull',
    tags: {'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Планка',
    description: 'Статическая стабилизация корпуса.',
    tips: 'Линия от плеч до пяток без провисания.',
    videoUrl: 'https://www.youtube.com/results?search_query=plank+proper+form',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 5,
    minReps: 30,
    maxReps: 70,
    baseRest: 40,
    pattern: 'plank',
  ),
  _ExerciseTemplate(
    name: 'Боковая планка',
    description: 'Укрепляет косые мышцы и стабилизаторы.',
    tips: 'Таз держите высоко.',
    videoUrl:
        'https://www.youtube.com/results?search_query=side+plank+technique',
    focuses: {WorkoutFocus.mixed, WorkoutFocus.mobility, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 4,
    minReps: 20,
    maxReps: 45,
    baseRest: 40,
    pattern: 'plank',
  ),
  _ExerciseTemplate(
    name: 'Скалолаз',
    description: 'Кардио + корпус в упоре.',
    tips: 'Плечи стабильны, колени тяните к груди.',
    videoUrl:
        'https://www.youtube.com/results?search_query=mountain+climbers+exercise',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 20,
    maxReps: 50,
    baseRest: 45,
    pattern: 'mountain',
    tags: {'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Русские повороты',
    description: 'Динамика корпуса и косых мышц.',
    tips: 'Поворот от корпуса, не только руками.',
    videoUrl:
        'https://www.youtube.com/results?search_query=russian+twist+proper+form',
    focuses: {WorkoutFocus.mixed, WorkoutFocus.strength},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 5,
    minReps: 16,
    maxReps: 30,
    baseRest: 45,
    pattern: 'twist',
    tags: {'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Скручивания',
    description: 'Базовая работа на пресс.',
    tips: 'Не тяните шею руками, поднимайтесь плавно.',
    videoUrl:
        'https://www.youtube.com/results?search_query=crunch+exercise+form',
    focuses: {WorkoutFocus.strength, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 5,
    minReps: 12,
    maxReps: 22,
    baseRest: 35,
    pattern: 'abs',
    tags: {'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Обратные скручивания',
    description: 'Акцент на нижний пресс.',
    tips: 'Подкручивайте таз, не бросайте ноги.',
    videoUrl:
        'https://www.youtube.com/results?search_query=reverse+crunch+form',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 4,
    minReps: 10,
    maxReps: 18,
    baseRest: 40,
    pattern: 'abs',
  ),
  _ExerciseTemplate(
    name: 'Dead Bug',
    description: 'Стабилизация корпуса и поясницы.',
    tips: 'Поясница прижата к полу.',
    videoUrl:
        'https://www.youtube.com/results?search_query=dead+bug+exercise+form',
    focuses: {WorkoutFocus.recovery, WorkoutFocus.mobility, WorkoutFocus.mixed},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 4,
    minReps: 10,
    maxReps: 16,
    baseRest: 35,
    pattern: 'core',
  ),
  _ExerciseTemplate(
    name: 'Bird Dog',
    description: 'Стабилизация центра тела.',
    tips: 'Таз и плечи без ротации.',
    videoUrl: 'https://www.youtube.com/results?search_query=bird+dog+exercise',
    focuses: {WorkoutFocus.recovery, WorkoutFocus.mobility},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 3,
    maxSets: 4,
    minReps: 10,
    maxReps: 16,
    baseRest: 30,
    pattern: 'core',
  ),
  _ExerciseTemplate(
    name: 'Берпи',
    description: 'Интенсивное кардио-силовое упражнение.',
    tips: 'Сначала техника, потом скорость.',
    videoUrl: 'https://www.youtube.com/results?search_query=burpee+proper+form',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.mixed},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 16,
    baseRest: 75,
    pattern: 'burpee',
    tags: {'knee_load', 'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Джампинг-джек',
    description: 'Кардио для разогрева и выносливости.',
    tips: 'Равномерный ритм, мягкая посадка.',
    videoUrl:
        'https://www.youtube.com/results?search_query=jumping+jack+exercise',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 25,
    maxReps: 60,
    baseRest: 35,
    pattern: 'jump',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Высокие колени',
    description: 'Интервальное кардио с высокой частотой шага.',
    tips: 'Корпус ровный, локти активно работают.',
    videoUrl:
        'https://www.youtube.com/results?search_query=high+knees+exercise',
    focuses: {WorkoutFocus.cardio},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 20,
    maxReps: 50,
    baseRest: 35,
    pattern: 'jump',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Конькобежец',
    description: 'Боковые прыжки на координацию и кардио.',
    tips: 'Колено опорной ноги стабильно.',
    videoUrl:
        'https://www.youtube.com/results?search_query=skater+jumps+exercise',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.mixed},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.bodyweight,
    minSets: 3,
    maxSets: 5,
    minReps: 16,
    maxReps: 30,
    baseRest: 50,
    pattern: 'jump',
    tags: {'knee_load'},
  ),
  _ExerciseTemplate(
    name: 'Свинг гирей',
    description: 'Динамическая нагрузка на заднюю цепь.',
    tips: 'Импульс от таза, спина нейтральная.',
    videoUrl:
        'https://www.youtube.com/results?search_query=kettlebell+swing+technique',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.strength},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.kettlebell,
    minSets: 3,
    maxSets: 5,
    minReps: 10,
    maxReps: 20,
    baseRest: 70,
    pattern: 'hinge',
    tags: {'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Трастеры с гантелями',
    description: 'Присед + жим, комплексная силовая работа.',
    tips: 'Дыхание ритмично, колени стабильны.',
    videoUrl:
        'https://www.youtube.com/results?search_query=dumbbell+thruster+technique',
    focuses: {WorkoutFocus.cardio, WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.advanced,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 14,
    baseRest: 75,
    pattern: 'complex',
    tags: {'knee_load', 'shoulder_load'},
  ),
  _ExerciseTemplate(
    name: 'Кошка-корова',
    description: 'Мягкая мобилизация позвоночника.',
    tips: 'Двигайтесь вместе с дыханием.',
    videoUrl: 'https://www.youtube.com/results?search_query=cat+cow+stretch',
    focuses: {WorkoutFocus.mobility, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 2,
    maxSets: 4,
    minReps: 8,
    maxReps: 16,
    baseRest: 20,
    pattern: 'mobility',
  ),
  _ExerciseTemplate(
    name: 'Собака мордой вниз',
    description: 'Растяжка задней поверхности тела.',
    tips: 'Пятки тяните к полу, шея расслаблена.',
    videoUrl: 'https://www.youtube.com/results?search_query=downward+dog+pose',
    focuses: {WorkoutFocus.mobility, WorkoutFocus.recovery},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 2,
    maxSets: 4,
    minReps: 20,
    maxReps: 50,
    baseRest: 20,
    pattern: 'mobility',
  ),
  _ExerciseTemplate(
    name: 'Растяжка сгибателей бедра',
    description: 'Снимает напряжение в передней линии бедра.',
    tips: 'Подкрутите таз и держите корпус ровным.',
    videoUrl: 'https://www.youtube.com/results?search_query=hip+flexor+stretch',
    focuses: {WorkoutFocus.recovery, WorkoutFocus.mobility},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.yogaMat,
    minSets: 2,
    maxSets: 3,
    minReps: 20,
    maxReps: 45,
    baseRest: 20,
    pattern: 'mobility',
  ),
  _ExerciseTemplate(
    name: 'Поза голубя',
    description: 'Глубокая растяжка ягодичных и тазобедренных.',
    tips: 'Не форсируйте амплитуду, дышите ровно.',
    videoUrl:
        'https://www.youtube.com/results?search_query=pigeon+pose+stretch',
    focuses: {WorkoutFocus.recovery, WorkoutFocus.mobility},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.yogaMat,
    minSets: 2,
    maxSets: 3,
    minReps: 25,
    maxReps: 60,
    baseRest: 20,
    pattern: 'mobility',
  ),
  _ExerciseTemplate(
    name: 'Тяга резинки сверху',
    description: 'Вертикальная тяга для широчайших.',
    tips: 'Локти тяните к ребрам, плечи вниз.',
    videoUrl:
        'https://www.youtube.com/results?search_query=resistance+band+lat+pulldown',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.resistanceBands,
    minSets: 3,
    maxSets: 5,
    minReps: 12,
    maxReps: 18,
    baseRest: 55,
    pattern: 'pull',
  ),
  _ExerciseTemplate(
    name: 'Сгибания рук с гантелями',
    description: 'Изоляция бицепса.',
    tips: 'Локти прижаты к корпусу.',
    videoUrl:
        'https://www.youtube.com/results?search_query=dumbbell+bicep+curl+form',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 10,
    maxReps: 16,
    baseRest: 45,
    pattern: 'arms',
  ),
  _ExerciseTemplate(
    name: 'Разгибания на трицепс с резинкой',
    description: 'Трицепс и стабильность плеча.',
    tips: 'Локти фиксируйте, работайте предплечьем.',
    videoUrl:
        'https://www.youtube.com/results?search_query=band+triceps+extension',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.beginner,
    equipment: EquipmentType.resistanceBands,
    minSets: 3,
    maxSets: 4,
    minReps: 12,
    maxReps: 20,
    baseRest: 45,
    pattern: 'arms',
  ),
  _ExerciseTemplate(
    name: 'Румынская тяга с гантелями',
    description: 'Задняя цепь и осанка.',
    tips: 'Движение в тазобедренном, спина ровная.',
    videoUrl:
        'https://www.youtube.com/results?search_query=dumbbell+romanian+deadlift+form',
    focuses: {WorkoutFocus.strength},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 8,
    maxReps: 12,
    baseRest: 70,
    pattern: 'hinge',
    tags: {'back_load'},
  ),
  _ExerciseTemplate(
    name: 'Фермерская ходьба',
    description: 'Функциональная сила корпуса и хвата.',
    tips: 'Плечи вниз, шаг ровный.',
    videoUrl:
        'https://www.youtube.com/results?search_query=farmer+carry+exercise',
    focuses: {WorkoutFocus.strength, WorkoutFocus.mixed},
    level: FitnessLevel.intermediate,
    equipment: EquipmentType.dumbbells,
    minSets: 3,
    maxSets: 5,
    minReps: 20,
    maxReps: 60,
    baseRest: 55,
    pattern: 'carry',
    tags: {'back_load'},
  ),
];
