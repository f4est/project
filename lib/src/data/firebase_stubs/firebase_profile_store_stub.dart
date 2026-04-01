import 'dart:async';
import 'dart:math';

import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/entities/user_profile.dart';

abstract class UserProfileStore {
  Future<UserProfile?> fetchProfile(String userId);

  Future<void> saveProfile(UserProfile profile);

  Future<List<WorkoutSessionResult>> fetchRecentSessions(String userId);

  Future<void> saveSession(String userId, WorkoutSessionResult result);
}

class FirebaseProfileStoreStub implements UserProfileStore {
  final Map<String, UserProfile> _profiles = {};
  final Map<String, List<WorkoutSessionResult>> _historyByUser = {};
  final Random _random = Random(41);

  @override
  Future<UserProfile?> fetchProfile(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _profiles[userId];
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));
    _profiles[profile.userId] = profile;
  }

  @override
  Future<List<WorkoutSessionResult>> fetchRecentSessions(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 90));

    final existing = _historyByUser[userId];
    if (existing != null) {
      return List<WorkoutSessionResult>.from(existing);
    }

    final seeded = <WorkoutSessionResult>[];
    final now = DateTime.now();
    for (var i = 1; i <= 14; i++) {
      final chance = _random.nextDouble();
      seeded.add(
        WorkoutSessionResult(
          date: now.subtract(Duration(days: i)),
          completed: chance > 0.3,
          perceivedDifficulty: 4 + _random.nextInt(5),
          fatigueLevel: 3 + _random.nextInt(6),
          enjoymentScore: 4 + _random.nextInt(6),
          workoutMinutes: 20 + _random.nextInt(35),
          feedback: 'Сеанс #$i',
        ),
      );
    }
    _historyByUser[userId] = seeded;
    return List<WorkoutSessionResult>.from(seeded);
  }

  @override
  Future<void> saveSession(String userId, WorkoutSessionResult result) async {
    await Future<void>.delayed(const Duration(milliseconds: 75));
    final current = _historyByUser[userId] ?? <WorkoutSessionResult>[];
    current.insert(0, result);
    _historyByUser[userId] = current.take(30).toList();
  }
}
