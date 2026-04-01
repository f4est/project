import 'dart:math';

class BodyMetrics {
  const BodyMetrics({
    required this.kneeAngle,
    required this.shoulderTilt,
    required this.hipTilt,
    required this.torsoLean,
    required this.twistOffset,
    required this.plankLineError,
    required this.hipHeightBias,
  });

  final double kneeAngle;
  final double shoulderTilt;
  final double hipTilt;
  final double torsoLean;
  final double twistOffset;
  final double plankLineError;
  final double hipHeightBias;
}

class LiveAnalyzerOutput {
  const LiveAnalyzerOutput({
    required this.qualityScore,
    required this.hint,
    required this.errors,
    required this.repDelta,
  });

  final double qualityScore;
  final String hint;
  final List<String> errors;
  final int repDelta;
}

enum _ExercisePattern { squat, twist, plank, generic }

class LiveWorkoutAnalyzer {
  _ExercisePattern? _activePattern;
  bool _isDownPhase = false;
  int _twistDirection = 0;
  DateTime _lastRepAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPlankTick = DateTime.fromMillisecondsSinceEpoch(0);

  LiveAnalyzerOutput analyze({
    required String exerciseName,
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    final pattern = _resolvePattern(exerciseName);
    if (_activePattern != pattern) {
      _activePattern = pattern;
      _isDownPhase = false;
      _twistDirection = 0;
      _lastRepAt = DateTime.fromMillisecondsSinceEpoch(0);
      _lastPlankTick = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return switch (pattern) {
      _ExercisePattern.squat => _analyzeSquat(metrics: metrics, now: now),
      _ExercisePattern.twist => _analyzeTwist(metrics: metrics, now: now),
      _ExercisePattern.plank => _analyzePlank(metrics: metrics, now: now),
      _ExercisePattern.generic => _analyzeGeneric(metrics: metrics),
    };
  }

  LiveAnalyzerOutput _analyzeSquat({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    var repDelta = 0;
    if (!_isDownPhase && metrics.kneeAngle < 132) {
      _isDownPhase = true;
    } else if (_isDownPhase &&
        metrics.kneeAngle > 160 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 700)) {
      repDelta = 1;
      _isDownPhase = false;
      _lastRepAt = now;
    }

    final errors = <String>[];
    if (metrics.kneeAngle > 145) {
      errors.add('Опускайтесь ниже в приседе');
    }
    if (metrics.torsoLean > 24) {
      errors.add('Держите корпус более вертикально');
    }
    if (max(metrics.shoulderTilt, metrics.hipTilt) > 26) {
      errors.add('Выравнивайте корпус, без завала в сторону');
    }

    final depthBonus = metrics.kneeAngle < 125
        ? 23
        : metrics.kneeAngle < 140
        ? 10
        : 0;
    final score =
        (72 +
                depthBonus -
                min(28, metrics.torsoLean * 0.9) -
                min(25, (metrics.shoulderTilt + metrics.hipTilt) * 0.28))
            .clamp(0, 100)
            .toDouble();

    final hint = repDelta > 0
        ? 'Повтор засчитан.'
        : errors.isEmpty
        ? 'Ровный темп и полная амплитуда.'
        : errors.first;
    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: hint,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzeTwist({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    var repDelta = 0;
    final direction = metrics.twistOffset > 0.15
        ? 1
        : metrics.twistOffset < -0.15
        ? -1
        : 0;

    if (direction != 0 &&
        _twistDirection != 0 &&
        direction != _twistDirection &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 450)) {
      repDelta = 1;
      _lastRepAt = now;
    }
    if (direction != 0) {
      _twistDirection = direction;
    }

    final errors = <String>[];
    final amplitude = metrics.twistOffset.abs();
    if (amplitude < 0.11) {
      errors.add('Увеличьте амплитуду поворота корпуса');
    }
    if (metrics.torsoLean > 22) {
      errors.add('Держите грудной отдел стабильнее');
    }

    final score =
        (64 +
                min(26, amplitude * 150) -
                min(18, metrics.torsoLean * 0.7) -
                min(14, metrics.shoulderTilt * 0.2))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Отличный разворот.'
          : errors.isEmpty
          ? 'Поворачивайтесь плавно, без рывков.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzePlank({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    var repDelta = 0;
    final aligned = metrics.plankLineError < 14;
    if (aligned &&
        now.difference(_lastPlankTick) >= const Duration(seconds: 1)) {
      repDelta = 1;
      _lastPlankTick = now;
    }

    final errors = <String>[];
    if (metrics.plankLineError >= 14) {
      errors.add('Соберите корпус в одну линию');
    }
    if (metrics.hipHeightBias > 0.08) {
      errors.add('Опустите таз немного ниже');
    } else if (metrics.hipHeightBias < -0.08) {
      errors.add('Поднимите таз чуть выше');
    }

    final score =
        (88 -
                min(35, metrics.plankLineError * 1.6) -
                min(16, metrics.hipHeightBias.abs() * 120))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: aligned
          ? 'Планка стабильна, держите темп дыхания.'
          : (errors.isEmpty ? 'Удерживайте тело в одну линию.' : errors.first),
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzeGeneric({required BodyMetrics metrics}) {
    final score =
        (72 -
                min(20, metrics.torsoLean * 0.6) -
                min(16, (metrics.shoulderTilt + metrics.hipTilt) * 0.2))
            .clamp(0, 100)
            .toDouble();
    final errors = <String>[
      if (metrics.torsoLean > 24) 'Стабилизируйте корпус',
      if (metrics.shoulderTilt > 26 || metrics.hipTilt > 26)
        'Выравнивайте положение тела',
    ];
    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: errors.isEmpty
          ? 'Двигайтесь в контролируемом темпе.'
          : errors.first,
      errors: errors,
      repDelta: 0,
    );
  }

  _ExercisePattern _resolvePattern(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('присед')) {
      return _ExercisePattern.squat;
    }
    if (name.contains('поворот')) {
      return _ExercisePattern.twist;
    }
    if (name.contains('планк')) {
      return _ExercisePattern.plank;
    }
    return _ExercisePattern.generic;
  }
}
