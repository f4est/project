import 'package:flutter_test/flutter_test.dart';
import 'package:project/src/domain/services/live_workout_analyzer.dart';

void main() {
  group('LiveWorkoutAnalyzer', () {
    test('counts squat rep on down-up phase', () {
      final analyzer = LiveWorkoutAnalyzer();
      final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

      final down = analyzer.analyze(
        exerciseName: 'Приседания',
        now: baseTime,
        metrics: const BodyMetrics(
          kneeAngle: 118,
          elbowAngle: 170,
          shoulderTilt: 8,
          hipTilt: 8,
          torsoLean: 12,
          twistOffset: 0,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );
      analyzer.analyze(
        exerciseName: 'Приседания',
        now: baseTime.add(const Duration(milliseconds: 250)),
        metrics: const BodyMetrics(
          kneeAngle: 120,
          elbowAngle: 170,
          shoulderTilt: 8,
          hipTilt: 8,
          torsoLean: 12,
          twistOffset: 0,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );
      analyzer.analyze(
        exerciseName: 'Приседания',
        now: baseTime.add(const Duration(milliseconds: 700)),
        metrics: const BodyMetrics(
          kneeAngle: 168,
          elbowAngle: 170,
          shoulderTilt: 6,
          hipTilt: 6,
          torsoLean: 10,
          twistOffset: 0,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );
      final up = analyzer.analyze(
        exerciseName: 'Приседания',
        now: baseTime.add(const Duration(milliseconds: 1150)),
        metrics: const BodyMetrics(
          kneeAngle: 168,
          elbowAngle: 170,
          shoulderTilt: 6,
          hipTilt: 6,
          torsoLean: 10,
          twistOffset: 0,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );

      expect(down.repDelta, 0);
      expect(up.repDelta, 1);
      expect(up.qualityScore, greaterThan(55));
    });

    test('counts russian twist rep on direction change', () {
      final analyzer = LiveWorkoutAnalyzer();
      final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

      analyzer.analyze(
        exerciseName: 'Русские повороты',
        now: baseTime,
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 170,
          shoulderTilt: 6,
          hipTilt: 6,
          torsoLean: 8,
          twistOffset: 0.22,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );
      final result = analyzer.analyze(
        exerciseName: 'Русские повороты',
        now: baseTime.add(const Duration(milliseconds: 700)),
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 170,
          shoulderTilt: 7,
          hipTilt: 7,
          torsoLean: 8,
          twistOffset: -0.24,
          plankLineError: 0,
          hipHeightBias: 0,
        ),
      );

      expect(result.repDelta, 1);
    });

    test('counts plank hold seconds as reps', () {
      final analyzer = LiveWorkoutAnalyzer();
      final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

      final first = analyzer.analyze(
        exerciseName: 'Планка',
        now: baseTime,
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 170,
          shoulderTilt: 3,
          hipTilt: 3,
          torsoLean: 4,
          twistOffset: 0,
          plankLineError: 6,
          hipHeightBias: 0.02,
        ),
      );
      final second = analyzer.analyze(
        exerciseName: 'Планка',
        now: baseTime.add(const Duration(seconds: 1)),
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 170,
          shoulderTilt: 3,
          hipTilt: 3,
          torsoLean: 4,
          twistOffset: 0,
          plankLineError: 6,
          hipHeightBias: 0.02,
        ),
      );

      expect(first.repDelta, 1);
      expect(second.repDelta, 1);
      expect(second.errors, isEmpty);
    });

    test('counts push-up rep on down-up phase', () {
      final analyzer = LiveWorkoutAnalyzer();
      final baseTime = DateTime(2026, 1, 1, 10, 0, 0);

      analyzer.analyze(
        exerciseName: 'Отжимания от пола',
        now: baseTime,
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 92,
          shoulderTilt: 4,
          hipTilt: 4,
          torsoLean: 6,
          twistOffset: 0,
          plankLineError: 8,
          hipHeightBias: 0.02,
        ),
      );
      analyzer.analyze(
        exerciseName: 'Отжимания от пола',
        now: baseTime.add(const Duration(milliseconds: 250)),
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 88,
          shoulderTilt: 4,
          hipTilt: 4,
          torsoLean: 6,
          twistOffset: 0,
          plankLineError: 8,
          hipHeightBias: 0.02,
        ),
      );
      analyzer.analyze(
        exerciseName: 'Отжимания от пола',
        now: baseTime.add(const Duration(milliseconds: 850)),
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 164,
          shoulderTilt: 4,
          hipTilt: 4,
          torsoLean: 6,
          twistOffset: 0,
          plankLineError: 9,
          hipHeightBias: 0.02,
        ),
      );
      final up = analyzer.analyze(
        exerciseName: 'Отжимания от пола',
        now: baseTime.add(const Duration(milliseconds: 1200)),
        metrics: const BodyMetrics(
          kneeAngle: 170,
          elbowAngle: 162,
          shoulderTilt: 4,
          hipTilt: 4,
          torsoLean: 6,
          twistOffset: 0,
          plankLineError: 9,
          hipHeightBias: 0.02,
        ),
      );

      expect(up.repDelta, 1);
    });
  });
}
