import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';
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
  }) : _profileRepository = profileRepository,
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
    final profile =
        existing ?? UserProfile.defaultProfile(userId: userId, name: userName);
    if (existing == null) {
      await _profileRepository.saveProfile(profile);
    }

    final sessions = await _workoutHistoryRepository.fetchRecentSessions(
      userId,
    );
    final plan = _generatePlanUseCase(
      profile: profile,
      recentSessions: sessions,
      now: now,
    );
    final sessionsForProgress = _withCalendarMisses(
      sessions: sessions,
      profile: profile,
      now: now,
    );
    final progressStats = _progressAnalyzer.analyze(sessionsForProgress);
    return UserTrainingSnapshot(
      profile: profile,
      plan: plan,
      progressStats: progressStats,
    );
  }

  List<WorkoutSessionResult> _withCalendarMisses({
    required List<WorkoutSessionResult> sessions,
    required UserProfile profile,
    required DateTime now,
  }) {
    final normalized = List<WorkoutSessionResult>.from(sessions);
    final weekStart = _startOfWeek(now);
    final today = DateTime(now.year, now.month, now.day);
    final completedThisWeek = sessions
        .where(
          (s) =>
              s.completed &&
              !_dateOnly(s.date).isBefore(weekStart) &&
              !_dateOnly(s.date).isAfter(today),
        )
        .length;

    final expectedByPlan = profile.sessionsPerWeek.clamp(1, 7);
    final expectedThisWeek = expectedByPlan > now.weekday
        ? now.weekday
        : expectedByPlan;
    final missedRaw = expectedThisWeek - completedThisWeek;
    final missed = missedRaw < 0 ? 0 : (missedRaw > 7 ? 7 : missedRaw);
    for (var i = 0; i < missed; i++) {
      normalized.add(
        WorkoutSessionResult(
          date: today.subtract(Duration(days: i)),
          completed: false,
          perceivedDifficulty: 5,
          fatigueLevel: 5,
          enjoymentScore: 5,
          workoutMinutes: profile.sessionDurationMinutes,
          feedback: 'Пропуск тренировки',
        ),
      );
    }
    return normalized;
  }

  DateTime _startOfWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
