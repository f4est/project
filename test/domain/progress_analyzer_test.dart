import 'package:flutter_test/flutter_test.dart';
import 'package:project/src/domain/entities/workout_session.dart';
import 'package:project/src/domain/services/progress_analyzer.dart';

void main() {
  group('ProgressAnalyzer', () {
    test('calculates points level streak and league', () {
      final analyzer = ProgressAnalyzer();

      final stats = analyzer.analyze([
        WorkoutSessionResult(
          date: DateTime(2026, 3, 10),
          completed: true,
          perceivedDifficulty: 6,
          fatigueLevel: 5,
          enjoymentScore: 8,
          workoutMinutes: 40,
          feedback: 'Good',
        ),
        WorkoutSessionResult(
          date: DateTime(2026, 3, 9),
          completed: true,
          perceivedDifficulty: 6,
          fatigueLevel: 4,
          enjoymentScore: 9,
          workoutMinutes: 35,
          feedback: 'Nice',
        ),
        WorkoutSessionResult(
          date: DateTime(2026, 3, 8),
          completed: false,
          perceivedDifficulty: 0,
          fatigueLevel: 0,
          enjoymentScore: 0,
          workoutMinutes: 0,
          feedback: '',
        ),
      ]);

      expect(stats.totalPoints, greaterThan(0));
      expect(stats.level, greaterThanOrEqualTo(1));
      expect(stats.streakDays, 2);
      expect(stats.completionRatePercent, greaterThanOrEqualTo(60));
      expect(stats.leagueName.isNotEmpty, isTrue);
      expect(stats.coachControlMessage.isNotEmpty, isTrue);
    });
  });
}
