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

class PlanController extends ChangeNotifier {
  PlanController({
    required LoadUserPlanUseCase loadUserPlanUseCase,
    required WorkoutHistoryRepository workoutHistoryRepository,
    required SaveOnboardingProfileUseCase saveOnboardingProfileUseCase,
    required SaveUserProfileUseCase saveUserProfileUseCase,
    DateTime Function()? clock,
  })  : _loadUserPlanUseCase = loadUserPlanUseCase,
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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  WeeklyWorkoutPlan? get plan => _plan;
  UserProfile? get profile => _profile;
  ProgressStats? get progressStats => _progressStats;

  Future<void> loadForUser(AuthUser user) async {
    _activeUserId = user.id;
    _activeUserName = user.displayName;
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
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
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
}
