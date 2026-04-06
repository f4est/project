import 'package:flutter_test/flutter_test.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/services/recommendation_engine.dart';

void main() {
  group('RecommendationEngine', () {
    test('contains expanded exercise catalog for personalization', () {
      final engine = RecommendationEngine();
      expect(engine.catalogSize, greaterThanOrEqualTo(30));
    });

    test('creates weekly plan with intensity lowered for weak adherence', () {
      final engine = RecommendationEngine();
      final profile = UserProfile.defaultProfile(
        userId: 'u1',
        name: 'Alex',
      ).copyWith(
        fitnessLevel: FitnessLevel.beginner,
        goal: TrainingGoal.weightLoss,
        sessionsPerWeek: 4,
      );

      final history = <WorkoutSessionResult>[
        WorkoutSessionResult(
          date: DateTime(2026, 3, 1),
          completed: true,
          perceivedDifficulty: 8,
        ),
        WorkoutSessionResult(
          date: DateTime(2026, 3, 2),
          completed: false,
          perceivedDifficulty: 0,
        ),
        WorkoutSessionResult(
          date: DateTime(2026, 3, 3),
          completed: false,
          perceivedDifficulty: 0,
        ),
        WorkoutSessionResult(
          date: DateTime(2026, 3, 4),
          completed: true,
          perceivedDifficulty: 9,
        ),
      ];

      final plan = engine.buildWeeklyPlan(
        profile: profile,
        recentSessions: history,
        generatedAt: DateTime(2026, 3, 5),
      );

      expect(plan.dailyPlans.length, 3);
      expect(plan.adherenceTargetPercent, lessThan(80));
      expect(
        plan.dailyPlans.every((day) => day.intensityPercent <= 55),
        isTrue,
      );
    });

    test('prefers strength focus for muscle gain goal', () {
      final engine = RecommendationEngine();
      final profile = UserProfile.defaultProfile(
        userId: 'u2',
        name: 'Nina',
      ).copyWith(
        fitnessLevel: FitnessLevel.intermediate,
        goal: TrainingGoal.muscleGain,
        sessionsPerWeek: 3,
        availableEquipment: {
          EquipmentType.bodyweight,
          EquipmentType.dumbbells,
        },
      );

      final plan = engine.buildWeeklyPlan(
        profile: profile,
        recentSessions: const [],
        generatedAt: DateTime(2026, 3, 5),
      );

      expect(plan.dailyPlans.length, 3);
      expect(
        plan.dailyPlans.where((day) => day.focus == WorkoutFocus.strength).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        plan.dailyPlans.expand((day) => day.exercises).isNotEmpty,
        isTrue,
      );
    });

    test('reduces intensity when fatigue feedback is high', () {
      final engine = RecommendationEngine();
      final profile = UserProfile.defaultProfile(
        userId: 'u3',
        name: 'Mila',
      ).copyWith(
        fitnessLevel: FitnessLevel.intermediate,
        goal: TrainingGoal.endurance,
        sessionsPerWeek: 4,
      );

      final lowFatiguePlan = engine.buildWeeklyPlan(
        profile: profile,
        recentSessions: [
          WorkoutSessionResult(
            date: DateTime(2026, 3, 1),
            completed: true,
            perceivedDifficulty: 6,
            fatigueLevel: 3,
            enjoymentScore: 8,
            workoutMinutes: 35,
            feedback: 'Отлично',
          ),
        ],
        generatedAt: DateTime(2026, 3, 5),
      );

      final highFatiguePlan = engine.buildWeeklyPlan(
        profile: profile,
        recentSessions: [
          WorkoutSessionResult(
            date: DateTime(2026, 3, 2),
            completed: true,
            perceivedDifficulty: 8,
            fatigueLevel: 9,
            enjoymentScore: 4,
            workoutMinutes: 35,
            feedback: 'Слишком тяжело',
          ),
        ],
        generatedAt: DateTime(2026, 3, 5),
      );

      final lowFatigueAverage = lowFatiguePlan.dailyPlans
              .map((day) => day.intensityPercent)
              .reduce((a, b) => a + b) /
          lowFatiguePlan.dailyPlans.length;
      final highFatigueAverage = highFatiguePlan.dailyPlans
              .map((day) => day.intensityPercent)
              .reduce((a, b) => a + b) /
          highFatiguePlan.dailyPlans.length;

      expect(highFatigueAverage, lessThan(lowFatigueAverage));
    });
  });
}
