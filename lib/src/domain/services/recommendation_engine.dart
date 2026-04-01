import 'dart:math';

import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';

class RecommendationEngine {
  WeeklyWorkoutPlan buildWeeklyPlan({
    required UserProfile profile,
    required List<WorkoutSessionResult> recentSessions,
    required DateTime generatedAt,
  }) {
    final adherence = _adherence(recentSessions);
    final averageDifficulty = _averageDifficulty(recentSessions);
    final averageFatigue = _averageFatigue(recentSessions);
    final averageEnjoyment = _averageEnjoyment(recentSessions);

    final adjustedSessions = _recommendedSessions(
      targetSessions: profile.sessionsPerWeek,
      adherence: adherence,
    );
    final baseIntensity = _baseIntensity(profile.fitnessLevel);
    final goalShift = _goalIntensityModifier(profile.goal);
    final lifestyleShift = _lifestyleModifier(profile.lifestyleType);
    final adherenceShift = _adherenceModifier(adherence);
    final difficultyShift = _difficultyModifier(averageDifficulty);
    final fatigueShift = _fatigueModifier(averageFatigue);
    final enjoymentShift = _enjoymentModifier(averageEnjoyment);
    final intensity =
        (baseIntensity +
                goalShift +
                lifestyleShift +
                adherenceShift +
                difficultyShift +
                fatigueShift +
                enjoymentShift)
            .clamp(35, 92);

    final focusPattern = _focusPattern(profile.goal, adjustedSessions);
    final dailyPlans = List<DailyWorkoutPlan>.generate(adjustedSessions, (index) {
      final focus = focusPattern[index];
      final dayIntensity = (intensity + (index.isEven ? 0 : -3)).clamp(35, 92);
      final exercises = _buildExercisesForDay(
        focus: focus,
        availableEquipment: profile.availableEquipment,
        daySeed: index,
      );

      return DailyWorkoutPlan(
        dayIndex: index + 1,
        title: 'День ${index + 1}: ${focus.label}',
        focus: focus,
        intensityPercent: dayIntensity.toInt(),
        estimatedMinutes: profile.sessionDurationMinutes,
        exercises: exercises,
      );
    });

    final adherenceTarget = (adherence * 100 + 8).clamp(55, 95).toInt();
    final rationale = <String>[
      'План учитывает цель: ${profile.goal.label}.',
      'Интенсивность подобрана по уровню ${profile.fitnessLevel.label.toLowerCase()}.',
      'Режим дня: ${profile.lifestyleType.label.toLowerCase()}.',
      'Сессий в неделю: $adjustedSessions, целевая дисциплина $adherenceTarget%.',
    ];
    if (profile.injuryNotes.trim().isNotEmpty) {
      rationale.add('Есть заметки по ограничениям: ${profile.injuryNotes.trim()}.');
    }

    return WeeklyWorkoutPlan(
      generatedAt: generatedAt,
      dailyPlans: dailyPlans,
      rationale: rationale,
      adherenceTargetPercent: adherenceTarget,
    );
  }

  double _adherence(List<WorkoutSessionResult> sessions) {
    if (sessions.isEmpty) {
      return 0.74;
    }
    final completed = sessions.where((session) => session.completed).length;
    return completed / sessions.length;
  }

  double _averageDifficulty(List<WorkoutSessionResult> sessions) {
    final completed = sessions
        .where((session) => session.completed)
        .map((session) => session.perceivedDifficulty);
    if (completed.isEmpty) {
      return 6;
    }
    final total = completed.reduce((sum, value) => sum + value);
    return total / completed.length;
  }

  double _averageFatigue(List<WorkoutSessionResult> sessions) {
    final completed = sessions
        .where((session) => session.completed)
        .map((session) => session.fatigueLevel);
    if (completed.isEmpty) {
      return 5;
    }
    final total = completed.reduce((sum, value) => sum + value);
    return total / completed.length;
  }

  double _averageEnjoyment(List<WorkoutSessionResult> sessions) {
    final completed = sessions
        .where((session) => session.completed)
        .map((session) => session.enjoymentScore);
    if (completed.isEmpty) {
      return 6;
    }
    final total = completed.reduce((sum, value) => sum + value);
    return total / completed.length;
  }

  int _recommendedSessions({
    required int targetSessions,
    required double adherence,
  }) {
    final safeTarget = targetSessions.clamp(2, 6);
    if (adherence < 0.55) {
      return max(2, safeTarget - 1);
    }
    if (adherence > 0.87) {
      return min(6, safeTarget + 1);
    }
    return safeTarget;
  }

  int _baseIntensity(FitnessLevel level) {
    return switch (level) {
      FitnessLevel.beginner => 50,
      FitnessLevel.intermediate => 64,
      FitnessLevel.advanced => 77,
    };
  }

  int _goalIntensityModifier(TrainingGoal goal) {
    return switch (goal) {
      TrainingGoal.weightLoss => 3,
      TrainingGoal.muscleGain => 6,
      TrainingGoal.endurance => 4,
      TrainingGoal.mobility => -6,
    };
  }

  int _adherenceModifier(double adherence) {
    if (adherence < 0.55) {
      return -11;
    }
    if (adherence < 0.72) {
      return -5;
    }
    if (adherence > 0.87) {
      return 4;
    }
    return 0;
  }

  int _lifestyleModifier(LifestyleType type) {
    return switch (type) {
      LifestyleType.office => -4,
      LifestyleType.student => -1,
      LifestyleType.activeWork => 2,
      LifestyleType.athlete => 5,
    };
  }

  int _difficultyModifier(double difficulty) {
    if (difficulty >= 8.5) {
      return -7;
    }
    if (difficulty <= 4.5) {
      return 5;
    }
    return 0;
  }

  int _fatigueModifier(double fatigue) {
    if (fatigue >= 8.0) {
      return -8;
    }
    if (fatigue <= 4.0) {
      return 2;
    }
    return 0;
  }

  int _enjoymentModifier(double enjoyment) {
    if (enjoyment <= 4.5) {
      return -4;
    }
    if (enjoyment >= 8.0) {
      return 2;
    }
    return 0;
  }

  List<WorkoutFocus> _focusPattern(TrainingGoal goal, int sessions) {
    final template = switch (goal) {
      TrainingGoal.weightLoss => const [
          WorkoutFocus.cardio,
          WorkoutFocus.strength,
          WorkoutFocus.mixed,
          WorkoutFocus.cardio,
        ],
      TrainingGoal.muscleGain => const [
          WorkoutFocus.strength,
          WorkoutFocus.strength,
          WorkoutFocus.mixed,
          WorkoutFocus.recovery,
        ],
      TrainingGoal.endurance => const [
          WorkoutFocus.cardio,
          WorkoutFocus.cardio,
          WorkoutFocus.strength,
          WorkoutFocus.mixed,
        ],
      TrainingGoal.mobility => const [
          WorkoutFocus.mobility,
          WorkoutFocus.recovery,
          WorkoutFocus.mobility,
          WorkoutFocus.mixed,
        ],
    };
    return List<WorkoutFocus>.generate(
      sessions,
      (index) => template[index % template.length],
    );
  }

  List<WorkoutExercise> _buildExercisesForDay({
    required WorkoutFocus focus,
    required Set<EquipmentType> availableEquipment,
    required int daySeed,
  }) {
    final catalog = _exerciseCatalog;
    final primary = catalog
        .where(
          (template) =>
              template.focus == focus &&
              (template.equipment == EquipmentType.bodyweight ||
                  availableEquipment.contains(template.equipment)),
        )
        .toList();

    final fallback = catalog
        .where(
          (template) =>
              template.focus == WorkoutFocus.mixed &&
              (template.equipment == EquipmentType.bodyweight ||
                  availableEquipment.contains(template.equipment)),
        )
        .toList();

    final pool = [...primary, ...fallback];
    if (pool.isEmpty) {
      return const [
        WorkoutExercise(
          name: 'Ходьба на месте',
          description: 'Поддерживайте умеренный темп и ровное дыхание.',
          executionTips: 'Плечи расслаблены, шаг короткий, дыхание через нос.',
          videoUrl: 'https://www.youtube.com/watch?v=R5x8m6f4d6A',
          sets: 3,
          reps: 60,
          restSeconds: 30,
          equipment: EquipmentType.bodyweight,
        ),
      ];
    }
    final start = daySeed % pool.length;
    final count = min(4, pool.length);

    return List<WorkoutExercise>.generate(count, (offset) {
      final item = pool[(start + offset) % pool.length];
      return WorkoutExercise(
        name: item.name,
        description: item.description,
        executionTips: item.executionTips,
        videoUrl: item.videoUrl,
        sets: item.sets,
        reps: item.reps,
        restSeconds: item.restSeconds,
        equipment: item.equipment,
      );
    });
  }
}

class _ExerciseTemplate {
  const _ExerciseTemplate({
    required this.name,
    required this.description,
    required this.executionTips,
    required this.videoUrl,
    required this.focus,
    required this.equipment,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  final String name;
  final String description;
  final String executionTips;
  final String videoUrl;
  final WorkoutFocus focus;
  final EquipmentType equipment;
  final int sets;
  final int reps;
  final int restSeconds;
}

const List<_ExerciseTemplate> _exerciseCatalog = [
  _ExerciseTemplate(
    name: 'Приседания',
    description: 'Контроль коленей и нейтральная спина.',
    executionTips: 'Колени в сторону носков, пятки на полу, корпус ровный.',
    videoUrl: 'https://www.youtube.com/watch?v=aclHkVaku9U',
    focus: WorkoutFocus.strength,
    equipment: EquipmentType.bodyweight,
    sets: 4,
    reps: 12,
    restSeconds: 60,
  ),
  _ExerciseTemplate(
    name: 'Жим гантелей стоя',
    description: 'Локти чуть вперед, пресс напряжён.',
    executionTips: 'Не прогибайтесь в пояснице, движение вверх по дуге.',
    videoUrl: 'https://www.youtube.com/watch?v=B-aVuyhvLHU',
    focus: WorkoutFocus.strength,
    equipment: EquipmentType.dumbbells,
    sets: 4,
    reps: 10,
    restSeconds: 75,
  ),
  _ExerciseTemplate(
    name: 'Тяга резинки к поясу',
    description: 'Сводите лопатки, без рывка.',
    executionTips: 'Локти вдоль корпуса, усилие на выдохе.',
    videoUrl: 'https://www.youtube.com/watch?v=7q8h3Q0m7K0',
    focus: WorkoutFocus.strength,
    equipment: EquipmentType.resistanceBands,
    sets: 4,
    reps: 12,
    restSeconds: 60,
  ),
  _ExerciseTemplate(
    name: 'Бёрпи',
    description: 'Держите темп, но не теряйте технику.',
    executionTips: 'Мягкое приземление, спина нейтральная.',
    videoUrl: 'https://www.youtube.com/watch?v=TU8QYVW0gDU',
    focus: WorkoutFocus.cardio,
    equipment: EquipmentType.bodyweight,
    sets: 5,
    reps: 10,
    restSeconds: 45,
  ),
  _ExerciseTemplate(
    name: 'Скакалка без скакалки',
    description: 'Пружинящие стопы, мягкая амортизация.',
    executionTips: 'Легкие прыжки, локти прижаты к корпусу.',
    videoUrl: 'https://www.youtube.com/watch?v=1BZM6B4xt7U',
    focus: WorkoutFocus.cardio,
    equipment: EquipmentType.bodyweight,
    sets: 6,
    reps: 45,
    restSeconds: 30,
  ),
  _ExerciseTemplate(
    name: 'Русские повороты',
    description: 'Поворот корпусом, не только руками.',
    executionTips: 'Держите пресс включённым, не округляйте спину.',
    videoUrl: 'https://www.youtube.com/watch?v=wkD8rjkodUI',
    focus: WorkoutFocus.mixed,
    equipment: EquipmentType.bodyweight,
    sets: 3,
    reps: 20,
    restSeconds: 40,
  ),
  _ExerciseTemplate(
    name: 'Планка',
    description: 'Линия тела прямая, без провиса в пояснице.',
    executionTips: 'Подкрутите таз и удерживайте напряжение пресса.',
    videoUrl: 'https://www.youtube.com/watch?v=ASdvN_XEl_c',
    focus: WorkoutFocus.mixed,
    equipment: EquipmentType.yogaMat,
    sets: 4,
    reps: 40,
    restSeconds: 30,
  ),
  _ExerciseTemplate(
    name: 'Мобилизация грудного отдела',
    description: 'Плавные контролируемые движения.',
    executionTips: 'Двигайтесь в комфортной амплитуде без боли.',
    videoUrl: 'https://www.youtube.com/watch?v=9s8NQf4K2YI',
    focus: WorkoutFocus.mobility,
    equipment: EquipmentType.yogaMat,
    sets: 3,
    reps: 10,
    restSeconds: 30,
  ),
  _ExerciseTemplate(
    name: 'Растяжка сгибателей бедра',
    description: 'Удержание позиции с ровным дыханием.',
    executionTips: 'Таз подкручен, держите корпус вертикально.',
    videoUrl: 'https://www.youtube.com/watch?v=7bRaX6M2nr8',
    focus: WorkoutFocus.recovery,
    equipment: EquipmentType.yogaMat,
    sets: 3,
    reps: 45,
    restSeconds: 20,
  ),
];
