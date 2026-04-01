import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/repositories/user_profile_repository.dart';
import 'package:project/src/domain/repositories/workout_history_repository.dart';
import 'package:project/src/domain/services/progress_analyzer.dart';
import 'package:project/src/domain/usecases/generate_personal_plan_use_case.dart';

class UserTrainingSnapshot {
  const UserTrainingSnapshot({
    required this.profile,
    required this.plan,
    required this.progressStats,
  });

  final UserProfile profile;
  final WeeklyWorkoutPlan plan;
  final ProgressStats progressStats;
}

class LoadUserPlanUseCase {
  const LoadUserPlanUseCase({
    required UserProfileRepository profileRepository,
    required WorkoutHistoryRepository workoutHistoryRepository,
    required GeneratePersonalPlanUseCase generatePlanUseCase,
    required ProgressAnalyzer progressAnalyzer,
  })  : _profileRepository = profileRepository,
        _workoutHistoryRepository = workoutHistoryRepository,
        _generatePlanUseCase = generatePlanUseCase,
        _progressAnalyzer = progressAnalyzer;

  final UserProfileRepository _profileRepository;
  final WorkoutHistoryRepository _workoutHistoryRepository;
  final GeneratePersonalPlanUseCase _generatePlanUseCase;
  final ProgressAnalyzer _progressAnalyzer;

  Future<UserTrainingSnapshot> call({
    required String userId,
    required String userName,
    required DateTime now,
  }) async {
    final existing = await _profileRepository.fetchProfile(userId);
    final profile = existing ?? UserProfile.defaultProfile(userId: userId, name: userName);
    if (existing == null) {
      await _profileRepository.saveProfile(profile);
    }

    final sessions = await _workoutHistoryRepository.fetchRecentSessions(userId);
    final plan = _generatePlanUseCase(
      profile: profile,
      recentSessions: sessions,
      now: now,
    );
    final progressStats = _progressAnalyzer.analyze(sessions);
    return UserTrainingSnapshot(
      profile: profile,
      plan: plan,
      progressStats: progressStats,
    );
  }
}
