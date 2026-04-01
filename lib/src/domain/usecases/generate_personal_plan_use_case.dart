import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/services/recommendation_engine.dart';

class GeneratePersonalPlanUseCase {
  const GeneratePersonalPlanUseCase(this._engine);

  final RecommendationEngine _engine;

  WeeklyWorkoutPlan call({
    required UserProfile profile,
    required List<WorkoutSessionResult> recentSessions,
    required DateTime now,
  }) {
    return _engine.buildWeeklyPlan(
      profile: profile,
      recentSessions: recentSessions,
      generatedAt: now,
    );
  }
}
