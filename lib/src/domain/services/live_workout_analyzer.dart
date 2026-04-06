import 'dart:math';

class BodyMetrics {
  const BodyMetrics({
    required this.kneeAngle,
    required this.elbowAngle,
    required this.shoulderTilt,
    required this.hipTilt,
    required this.torsoLean,
    required this.twistOffset,
    required this.plankLineError,
    required this.hipHeightBias,
  });

  final double kneeAngle;
  final double elbowAngle;
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

enum _ExercisePattern {
  squat,
  twist,
  plank,
  lunge,
  mountain,
  cardio,
  bridge,
  push,
  generic,
}

class LiveWorkoutAnalyzer {
  _ExercisePattern? _activePattern;
  bool _isDownPhase = false;
  int _twistDirection = 0;
  double _kneeMax = 170;
  double _kneeMin = 170;
  double _elbowMax = 170;
  double _elbowMin = 170;
  double _filteredKneeAngle = 170;
  double _filteredElbowAngle = 170;
  int _downStableFrames = 0;
  int _upStableFrames = 0;
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
      _kneeMax = 170;
      _kneeMin = 170;
      _elbowMax = 170;
      _elbowMin = 170;
      _filteredKneeAngle = 170;
      _filteredElbowAngle = 170;
      _downStableFrames = 0;
      _upStableFrames = 0;
      _lastRepAt = DateTime.fromMillisecondsSinceEpoch(0);
      _lastPlankTick = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return switch (pattern) {
      _ExercisePattern.squat => _analyzeSquat(metrics: metrics, now: now),
      _ExercisePattern.twist => _analyzeTwist(metrics: metrics, now: now),
      _ExercisePattern.plank => _analyzePlank(metrics: metrics, now: now),
      _ExercisePattern.lunge => _analyzeLunge(metrics: metrics, now: now),
      _ExercisePattern.mountain => _analyzeMountain(metrics: metrics, now: now),
      _ExercisePattern.cardio => _analyzeCardio(metrics: metrics, now: now),
      _ExercisePattern.bridge => _analyzeBridge(metrics: metrics, now: now),
      _ExercisePattern.push => _analyzePush(metrics: metrics, now: now),
      _ExercisePattern.generic => _analyzeGeneric(metrics: metrics),
    };
  }

  LiveAnalyzerOutput _analyzeSquat({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    _filteredKneeAngle = _smooth(_filteredKneeAngle, metrics.kneeAngle);
    _kneeMax = max(_kneeMax, _filteredKneeAngle);
    _kneeMin = min(_kneeMin, _filteredKneeAngle);
    const downThreshold = 145.0;
    const upThreshold = 158.0;
    final amplitude = _kneeMax - _kneeMin;

    var repDelta = 0;
    if (!_isDownPhase && _filteredKneeAngle < downThreshold) {
      _downStableFrames += 1;
      if (_downStableFrames >= 1) {
        _isDownPhase = true;
        _upStableFrames = 0;
      }
    } else if (!_isDownPhase) {
      _downStableFrames = 0;
    }

    if (_isDownPhase &&
        _filteredKneeAngle > upThreshold &&
        amplitude > 14 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 550)) {
      _upStableFrames += 1;
      if (_upStableFrames >= 1) {
        repDelta = 1;
        _isDownPhase = false;
        _lastRepAt = now;
        _kneeMax = _filteredKneeAngle;
        _kneeMin = _filteredKneeAngle;
        _downStableFrames = 0;
        _upStableFrames = 0;
      }
    } else if (_isDownPhase) {
      _upStableFrames = 0;
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

  LiveAnalyzerOutput _analyzeLunge({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    _filteredKneeAngle = _smooth(_filteredKneeAngle, metrics.kneeAngle);
    _kneeMax = max(_kneeMax, _filteredKneeAngle);
    _kneeMin = min(_kneeMin, _filteredKneeAngle);
    const downThreshold = 146.0;
    const upThreshold = 158.0;
    final amplitude = _kneeMax - _kneeMin;

    var repDelta = 0;
    if (!_isDownPhase && _filteredKneeAngle < downThreshold) {
      _downStableFrames += 1;
      if (_downStableFrames >= 1) {
        _isDownPhase = true;
        _upStableFrames = 0;
      }
    } else if (!_isDownPhase) {
      _downStableFrames = 0;
    }

    if (_isDownPhase &&
        _filteredKneeAngle > upThreshold &&
        amplitude > 12 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 600)) {
      _upStableFrames += 1;
      if (_upStableFrames >= 1) {
        repDelta = 1;
        _isDownPhase = false;
        _lastRepAt = now;
        _kneeMax = _filteredKneeAngle;
        _kneeMin = _filteredKneeAngle;
        _downStableFrames = 0;
        _upStableFrames = 0;
      }
    } else if (_isDownPhase) {
      _upStableFrames = 0;
    }

    final errors = <String>[];
    if (metrics.kneeAngle > 145) {
      errors.add('Опускайтесь глубже в выпаде');
    }
    if (metrics.torsoLean > 20) {
      errors.add('Держите корпус ровнее');
    }
    if (metrics.hipTilt > 22) {
      errors.add('Стабилизируйте таз');
    }

    final score =
        (74 -
                min(25, metrics.torsoLean * 0.8) -
                min(18, metrics.hipTilt * 0.35) +
                (metrics.kneeAngle < 130 ? 15 : 0))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Повтор засчитан.'
          : errors.isEmpty
          ? 'Шаг и амплитуда стабильны.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzeMountain({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    _filteredKneeAngle = _smooth(_filteredKneeAngle, metrics.kneeAngle);
    _kneeMax = max(_kneeMax, _filteredKneeAngle);
    _kneeMin = min(_kneeMin, _filteredKneeAngle);
    final amplitude = _kneeMax - _kneeMin;
    var repDelta = 0;
    if (_filteredKneeAngle < 132 &&
        amplitude > 10 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 380)) {
      repDelta = 1;
      _lastRepAt = now;
      _kneeMax = _filteredKneeAngle;
      _kneeMin = _filteredKneeAngle;
    }

    final errors = <String>[];
    if (metrics.plankLineError > 20) {
      errors.add('Стабилизируйте корпус в линии');
    }
    if (metrics.shoulderTilt > 20) {
      errors.add('Уберите перекос плеч');
    }

    final score =
        (70 -
                min(20, metrics.plankLineError * 1.1) -
                min(14, metrics.shoulderTilt * 0.4) +
                (metrics.kneeAngle < 125 ? 12 : 0))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Темп хороший.'
          : errors.isEmpty
          ? 'Работайте в контролируемом ритме.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzeBridge({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    var repDelta = 0;
    if (!_isDownPhase && metrics.hipHeightBias > 0.08) {
      _isDownPhase = true;
    } else if (_isDownPhase &&
        metrics.hipHeightBias < -0.02 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 650)) {
      repDelta = 1;
      _isDownPhase = false;
      _lastRepAt = now;
    }

    final errors = <String>[];
    if (metrics.hipHeightBias < 0.03) {
      errors.add('Поднимайте таз выше');
    }
    if (metrics.shoulderTilt > 18 || metrics.hipTilt > 18) {
      errors.add('Сохраняйте симметрию корпуса');
    }

    final score =
        (76 +
                min(16, max(0, metrics.hipHeightBias) * 100) -
                min(20, metrics.shoulderTilt * 0.4) -
                min(20, metrics.hipTilt * 0.5))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Хорошее разгибание таза.'
          : errors.isEmpty
          ? 'Держите верхнюю точку 1 секунду.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzeCardio({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    _filteredKneeAngle = _smooth(_filteredKneeAngle, metrics.kneeAngle);
    _kneeMax = max(_kneeMax, _filteredKneeAngle);
    _kneeMin = min(_kneeMin, _filteredKneeAngle);
    final amplitude = _kneeMax - _kneeMin;

    var repDelta = 0;
    if (_filteredKneeAngle < 142 &&
        amplitude > 11 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 420)) {
      repDelta = 1;
      _lastRepAt = now;
      _kneeMax = _filteredKneeAngle;
      _kneeMin = _filteredKneeAngle;
    }

    final errors = <String>[];
    if (metrics.torsoLean > 26) {
      errors.add('Держите корпус стабильнее');
    }
    if (metrics.shoulderTilt > 24) {
      errors.add('Старайтесь не заваливаться в сторону');
    }

    final score =
        (70 +
                min(18, amplitude * 0.8) -
                min(18, metrics.torsoLean * 0.5) -
                min(14, metrics.shoulderTilt * 0.35))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Движение засчитано.'
          : errors.isEmpty
          ? 'Держите ритм и мягко приземляйтесь.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
    );
  }

  LiveAnalyzerOutput _analyzePush({
    required BodyMetrics metrics,
    required DateTime now,
  }) {
    _filteredElbowAngle = _smooth(_filteredElbowAngle, metrics.elbowAngle);
    _elbowMax = max(_elbowMax, _filteredElbowAngle);
    _elbowMin = min(_elbowMin, _filteredElbowAngle);
    const downThreshold = 112.0;
    const upThreshold = 145.0;
    final amplitude = _elbowMax - _elbowMin;

    var repDelta = 0;
    if (!_isDownPhase && _filteredElbowAngle < downThreshold) {
      _downStableFrames += 1;
      if (_downStableFrames >= 1) {
        _isDownPhase = true;
        _upStableFrames = 0;
      }
    } else if (!_isDownPhase) {
      _downStableFrames = 0;
    }

    if (_isDownPhase &&
        _filteredElbowAngle > upThreshold &&
        amplitude > 18 &&
        now.difference(_lastRepAt) > const Duration(milliseconds: 600)) {
      _upStableFrames += 1;
      if (_upStableFrames >= 1) {
        repDelta = 1;
        _isDownPhase = false;
        _lastRepAt = now;
        _elbowMax = _filteredElbowAngle;
        _elbowMin = _filteredElbowAngle;
        _downStableFrames = 0;
        _upStableFrames = 0;
      }
    } else if (_isDownPhase) {
      _upStableFrames = 0;
    }

    final errors = <String>[];
    if (_filteredElbowAngle > 130) {
      errors.add('Опускайтесь ниже в нижней фазе отжимания');
    }
    if (metrics.plankLineError > 22) {
      errors.add('Держите корпус в прямой линии');
    }
    if (metrics.hipHeightBias.abs() > 0.12) {
      errors.add('Не проваливайте таз');
    }

    final score =
        (74 +
                min(20, amplitude * 0.7) -
                min(22, metrics.plankLineError * 0.9) -
                min(16, metrics.hipHeightBias.abs() * 90))
            .clamp(0, 100)
            .toDouble();

    return LiveAnalyzerOutput(
      qualityScore: score,
      hint: repDelta > 0
          ? 'Повтор засчитан.'
          : errors.isEmpty
          ? 'Держите корпус ровно и двигайтесь плавно.'
          : errors.first,
      errors: errors,
      repDelta: repDelta,
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
    if (name.contains('выпад')) {
      return _ExercisePattern.lunge;
    }
    if (name.contains('скалолаз')) {
      return _ExercisePattern.mountain;
    }
    if (name.contains('мост')) {
      return _ExercisePattern.bridge;
    }
    if (name.contains('отжим')) {
      return _ExercisePattern.push;
    }
    if (name.contains('джампинг') ||
        name.contains('высокие колени') ||
        name.contains('конькобежец') ||
        name.contains('берпи')) {
      return _ExercisePattern.cardio;
    }
    return _ExercisePattern.generic;
  }

  double _smooth(double prev, double next) {
    if ((prev - 170).abs() < 0.001) {
      return next;
    }
    return prev * 0.4 + next * 0.6;
  }
}
