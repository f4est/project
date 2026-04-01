import 'package:project/src/domain/entities/user_profile.dart';

enum WorkoutFocus { strength, cardio, mobility, recovery, mixed }

extension WorkoutFocusX on WorkoutFocus {
  String get label => switch (this) {
        WorkoutFocus.strength => 'Силовая',
        WorkoutFocus.cardio => 'Кардио',
        WorkoutFocus.mobility => 'Мобильность',
        WorkoutFocus.recovery => 'Восстановление',
        WorkoutFocus.mixed => 'Смешанная',
      };
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.name,
    required this.description,
    required this.executionTips,
    required this.videoUrl,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.equipment,
  });

  final String name;
  final String description;
  final String executionTips;
  final String videoUrl;
  final int sets;
  final int reps;
  final int restSeconds;
  final EquipmentType equipment;
}

class DailyWorkoutPlan {
  const DailyWorkoutPlan({
    required this.dayIndex,
    required this.title,
    required this.focus,
    required this.intensityPercent,
    required this.estimatedMinutes,
    required this.exercises,
  });

  final int dayIndex;
  final String title;
  final WorkoutFocus focus;
  final int intensityPercent;
  final int estimatedMinutes;
  final List<WorkoutExercise> exercises;
}

class WeeklyWorkoutPlan {
  const WeeklyWorkoutPlan({
    required this.generatedAt,
    required this.dailyPlans,
    required this.rationale,
    required this.adherenceTargetPercent,
  });

  final DateTime generatedAt;
  final List<DailyWorkoutPlan> dailyPlans;
  final List<String> rationale;
  final int adherenceTargetPercent;
}
