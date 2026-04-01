import 'package:project/src/data/firebase_stubs/firebase_profile_store_stub.dart';
import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/repositories/workout_history_repository.dart';

class WorkoutHistoryRepositoryImpl implements WorkoutHistoryRepository {
  const WorkoutHistoryRepositoryImpl(this._store);

  final UserProfileStore _store;

  @override
  Future<List<WorkoutSessionResult>> fetchRecentSessions(String userId) {
    return _store.fetchRecentSessions(userId);
  }

  @override
  Future<void> saveSession(String userId, WorkoutSessionResult result) {
    return _store.saveSession(userId, result);
  }
}
