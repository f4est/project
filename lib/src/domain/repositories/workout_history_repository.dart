import 'package:project/src/domain/entities/workout_session.dart';

abstract class WorkoutHistoryRepository {
  Future<List<WorkoutSessionResult>> fetchRecentSessions(String userId);

  Future<void> saveSession(String userId, WorkoutSessionResult result);
}
