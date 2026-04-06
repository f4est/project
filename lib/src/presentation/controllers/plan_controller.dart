import 'package:flutter/foundation.dart';
import 'package:project/src/domain/entities/auth_user.dart';
import 'package:project/src/domain/entities/onboarding_profile_input.dart';
import 'package:project/src/domain/entities/progress_stats.dart';
import 'package:project/src/domain/entities/user_profile.dart';
import 'package:project/src/domain/entities/workout_plan.dart';
import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/repositories/workout_history_repository.dart';
import 'package:project/src/domain/usecases/load_user_plan_use_case.dart';
import 'package:project/src/domain/usecases/save_onboarding_profile_use_case.dart';
import 'package:project/src/domain/usecases/save_user_profile_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanController extends ChangeNotifier {
  PlanController({
    required LoadUserPlanUseCase loadUserPlanUseCase,
    required WorkoutHistoryRepository workoutHistoryRepository,
    required SaveOnboardingProfileUseCase saveOnboardingProfileUseCase,
    required SaveUserProfileUseCase saveUserProfileUseCase,
    DateTime Function()? clock,
  }) : _loadUserPlanUseCase = loadUserPlanUseCase,
       _workoutHistoryRepository = workoutHistoryRepository,
       _saveOnboardingProfileUseCase = saveOnboardingProfileUseCase,
       _saveUserProfileUseCase = saveUserProfileUseCase,
       _clock = clock ?? DateTime.now;

  final LoadUserPlanUseCase _loadUserPlanUseCase;
  final WorkoutHistoryRepository _workoutHistoryRepository;
  final SaveOnboardingProfileUseCase _saveOnboardingProfileUseCase;
  final SaveUserProfileUseCase _saveUserProfileUseCase;
  final DateTime Function() _clock;

  bool _isLoading = false;
  String? _errorMessage;
  WeeklyWorkoutPlan? _plan;
  UserProfile? _profile;
  ProgressStats? _progressStats;
  String? _activeUserId;
  String? _activeUserName;
  Set<String> _completedExercises = <String>{};
  Set<int> _completedWorkoutDays = <int>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WeeklyWorkoutPlan? get plan => _plan;
  UserProfile? get profile => _profile;
  ProgressStats? get progressStats => _progressStats;
  bool isExerciseCompleted(int dayIndex, String exerciseName) =>
      _completedExercises.contains(_exerciseKey(dayIndex, exerciseName));

  Future<void> loadForUser(AuthUser user) async {
    _activeUserId = user.id;
    _activeUserName = user.displayName;
    await _loadCompletedExercises();
    await _loadInternal();
  }

  Future<void> saveOnboardingProfile({
    required AuthUser user,
    required OnboardingProfileInput input,
  }) async {
    await _saveOnboardingProfileUseCase(
      userId: user.id,
      userName: user.displayName,
      input: input,
    );
    await loadForUser(user);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _saveUserProfileUseCase(profile);
    _profile = profile;
    notifyListeners();
    await _loadInternal();
  }

  Future<void> submitWorkoutFeedback({
    required bool completed,
    required int perceivedDifficulty,
    required int fatigueLevel,
    required int enjoymentScore,
    required int workoutMinutes,
    required String feedback,
  }) async {
    final userId = _activeUserId;
    final userName = _activeUserName;
    if (userId == null || userName == null) {
      return;
    }

    await _workoutHistoryRepository.saveSession(
      userId,
      WorkoutSessionResult(
        date: _clock(),
        completed: completed,
        perceivedDifficulty: perceivedDifficulty.clamp(1, 10),
        fatigueLevel: fatigueLevel.clamp(1, 10),
        enjoymentScore: enjoymentScore.clamp(1, 10),
        workoutMinutes: workoutMinutes.clamp(10, 180),
        feedback: feedback.trim(),
      ),
    );
    await _loadInternal();
  }

  void clear() {
    _activeUserId = null;
    _activeUserName = null;
    _plan = null;
    _profile = null;
    _progressStats = null;
    _completedExercises = <String>{};
    _completedWorkoutDays = <int>{};
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markExerciseCompleted({
    required int dayIndex,
    required String exerciseName,
    required bool completed,
  }) async {
    final userId = _activeUserId;
    if (userId == null) {
      return;
    }
    final key = _exerciseKey(dayIndex, exerciseName);
    if (completed) {
      _completedExercises.add(key);
    } else {
      _completedExercises.remove(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _exerciseStorageKey(userId),
      _completedExercises.toList(growable: false),
    );

    final dayPlan = _plan?.dailyPlans
        .where((d) => d.dayIndex == dayIndex)
        .firstOrNull;
    if (completed &&
        dayPlan != null &&
        !_completedWorkoutDays.contains(dayIndex) &&
        dayPlan.exercises.every((e) => isExerciseCompleted(dayIndex, e.name))) {
      await _workoutHistoryRepository.saveSession(
        userId,
        WorkoutSessionResult(
          date: _clock(),
          completed: true,
          perceivedDifficulty: 5,
          fatigueLevel: 5,
          enjoymentScore: 7,
          workoutMinutes: dayPlan.estimatedMinutes.clamp(10, 180),
          feedback: 'Тренировка отмечена вручную',
        ),
      );
      _completedWorkoutDays.add(dayIndex);
      await prefs.setStringList(
        _completedDaysStorageKey(userId),
        _completedWorkoutDays.map((e) => '$e').toList(growable: false),
      );
      await _loadInternal();
    }
  }

  Future<void> _loadInternal() async {
    final userId = _activeUserId;
    final userName = _activeUserName;
    if (userId == null || userName == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _loadUserPlanUseCase(
        userId: userId,
        userName: userName,
        now: _clock(),
      );
      _plan = snapshot.plan;
      _profile = snapshot.profile;
      _progressStats = snapshot.progressStats;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCompletedExercises() async {
    final userId = _activeUserId;
    if (userId == null) {
      _completedExercises = <String>{};
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _completedExercises = Set<String>.from(
      prefs.getStringList(_exerciseStorageKey(userId)) ?? const <String>[],
    );
    _completedWorkoutDays = Set<int>.from(
      (prefs.getStringList(_completedDaysStorageKey(userId)) ??
              const <String>[])
          .map((e) => int.tryParse(e))
          .whereType<int>(),
    );
  }

  String _exerciseStorageKey(String userId) =>
      'plan.completed_exercises.$userId';
  String _completedDaysStorageKey(String userId) =>
      'plan.completed_days.$userId';

  String _exerciseKey(int dayIndex, String exerciseName) =>
      '$dayIndex|${exerciseName.trim().toLowerCase()}';
}
