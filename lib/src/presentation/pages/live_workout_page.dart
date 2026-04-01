import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:project/src/domain/services/live_workout_analyzer.dart';
import 'package:project/src/presentation/controllers/app_settings_controller.dart';
import 'package:project/src/domain/entities/workout_plan.dart';

class LiveWorkoutPage extends StatefulWidget {
  const LiveWorkoutPage({
    super.key,
    required this.dayPlan,
    required this.appSettings,
    required this.onSessionFinished,
  });

  final DailyWorkoutPlan dayPlan;
  final AppSettings appSettings;
  final Future<void> Function({
    required bool completed,
    required int perceivedDifficulty,
    required int fatigueLevel,
    required int enjoymentScore,
    required int workoutMinutes,
    required String feedback,
  })
  onSessionFinished;

  @override
  State<LiveWorkoutPage> createState() => _LiveWorkoutPageState();
}

class _LiveWorkoutPageState extends State<LiveWorkoutPage> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  Timer? _restTimer;
  final FlutterTts _tts = FlutterTts();
  final LiveWorkoutAnalyzer _analyzer = LiveWorkoutAnalyzer();

  bool _isReady = false;
  bool _isBusy = false;
  bool _permissionError = false;
  bool _isRestPhase = false;
  bool _isSessionFinished = false;
  int _exerciseIndex = 0;
  int _setIndex = 1;
  int _repInSet = 0;
  int _totalCompletedReps = 0;
  int _restSecondsLeft = 0;
  double _qualityScore = 0;
  DateTime _startedAt = DateTime.now();
  DateTime _lastLowQualityHintAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _liveHint = 'Подготовьтесь и начните движение.';
  List<String> _liveErrors = const [];

  WorkoutExercise get _currentExercise =>
      widget.dayPlan.exercises[_exerciseIndex];

  int get _totalWorkReps => widget.dayPlan.exercises.fold<int>(
    0,
    (sum, exercise) => sum + exercise.reps * exercise.sets,
  );

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _setup();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _cameraController?.dispose();
    _poseDetector?.close();
    _tts.stop();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      await _configureVoice();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _permissionError = true;
          _liveHint = 'Камера не найдена.';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      final detector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );

      await controller.startImageStream(_processFrame);

      setState(() {
        _cameraController = controller;
        _poseDetector = detector;
        _isReady = true;
      });

      await _speak(
        'Тренировка с камерой начата. ${_currentExercise.name}. Подход $_setIndex.',
      );
    } catch (_) {
      setState(() {
        _permissionError = true;
        _liveHint = 'Не удалось запустить камеру. Проверьте разрешения.';
      });
    }
  }

  Future<void> _configureVoice() async {
    await _tts.setLanguage('ru-RU');
    await _tts.setSpeechRate(
      _speechRateFromStyle(widget.appSettings.voiceStyle),
    );
    await _tts.setPitch(_pitchFromStyle(widget.appSettings.voiceStyle));
    await _tts.setVolume(1.0);

    try {
      final voicesRaw = await _tts.getVoices;
      if (voicesRaw is! List || voicesRaw.isEmpty) {
        return;
      }

      Map<String, String>? best;
      var bestScore = -1;
      for (final item in voicesRaw) {
        if (item is! Map) {
          continue;
        }
        final voice = Map<String, dynamic>.from(item);
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final locale = (voice['locale'] ?? '').toString().toLowerCase();
        var score = 0;
        if (locale.contains('ru')) score += 10;
        final prefersFemale = widget.appSettings.voiceGender == 'female';
        final isFemale = name.contains('female') || name.contains('woman');
        final isMale = name.contains('male') || name.contains('man');
        if (prefersFemale && isFemale) score += 5;
        if (!prefersFemale && isMale) score += 5;
        if (name.contains('neural') || name.contains('natural')) score += 4;
        if (name.contains('premium') || name.contains('enhanced')) score += 3;
        if (score > bestScore) {
          bestScore = score;
          best = {
            'name': (voice['name'] ?? '').toString(),
            'locale': (voice['locale'] ?? '').toString(),
          };
        }
      }
      if (best != null) {
        await _tts.setVoice(best);
      }
    } catch (_) {
      // Keep default RU voice if advanced selection is unavailable.
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isBusy || _isRestPhase || _isSessionFinished) {
      return;
    }
    final controller = _cameraController;
    final detector = _poseDetector;
    if (controller == null || detector == null) {
      return;
    }
    _isBusy = true;
    try {
      final inputImage = _toInputImage(image, controller);
      if (inputImage == null) {
        return;
      }
      final poses = await detector.processImage(inputImage);
      if (poses.isEmpty) {
        if (mounted) {
          setState(() {
            _qualityScore = 0;
            _liveHint = 'Встаньте так, чтобы в кадр попадало всё тело.';
          });
        }
        return;
      }
      final pose = poses.first;
      final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
      final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
      final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final nose = pose.landmarks[PoseLandmarkType.nose];

      if (leftKnee == null ||
          rightKnee == null ||
          leftHip == null ||
          rightHip == null ||
          leftAnkle == null ||
          rightAnkle == null ||
          leftShoulder == null ||
          rightShoulder == null ||
          nose == null) {
        if (mounted) {
          setState(() {
            _liveHint = 'Камера видит не все ключевые точки тела.';
            _qualityScore = 0;
            _liveErrors = const ['Встаньте так, чтобы в кадре было всё тело.'];
          });
        }
        return;
      }

      final leftKneeAngle = _jointAngle(
        Offset(leftHip.x, leftHip.y),
        Offset(leftKnee.x, leftKnee.y),
        Offset(leftAnkle.x, leftAnkle.y),
      );
      final rightKneeAngle = _jointAngle(
        Offset(rightHip.x, rightHip.y),
        Offset(rightKnee.x, rightKnee.y),
        Offset(rightAnkle.x, rightAnkle.y),
      );
      final shoulderMid = Offset(
        (leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2,
      );
      final hipMid = Offset(
        (leftHip.x + rightHip.x) / 2,
        (leftHip.y + rightHip.y) / 2,
      );
      final ankleMid = Offset(
        (leftAnkle.x + rightAnkle.x) / 2,
        (leftAnkle.y + rightAnkle.y) / 2,
      );
      final bodyCoverage = (ankleMid.dy - nose.y) / image.height;
      if (bodyCoverage < 0.62) {
        if (mounted) {
          setState(() {
            _qualityScore = 0;
            _liveHint = 'Отойдите назад: нужно видеть тело почти полностью.';
            _liveErrors = const [
              'В кадр должны входить голова, таз и ноги полностью.',
            ];
          });
        }
        return;
      }
      final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
      final torsoHeight = max(1.0, (hipMid.dy - shoulderMid.dy).abs());

      final shoulderTilt = (leftShoulder.y - rightShoulder.y).abs();
      final hipTilt = (leftHip.y - rightHip.y).abs();
      final torsoLean = _angleFromVertical(shoulderMid, hipMid);
      final twistOffset = shoulderWidth <= 1
          ? 0.0
          : (shoulderMid.dx - hipMid.dx) / shoulderWidth;
      final plankLineError = (180 - _jointAngle(shoulderMid, hipMid, ankleMid))
          .abs();
      final hipHeightBias = (hipMid.dy - shoulderMid.dy) / torsoHeight - 1.0;

      final output = _analyzer.analyze(
        exerciseName: _currentExercise.name,
        now: DateTime.now(),
        metrics: BodyMetrics(
          kneeAngle: (leftKneeAngle + rightKneeAngle) / 2,
          shoulderTilt: shoulderTilt,
          hipTilt: hipTilt,
          torsoLean: torsoLean,
          twistOffset: twistOffset,
          plankLineError: plankLineError,
          hipHeightBias: hipHeightBias,
        ),
      );

      if (output.repDelta > 0) {
        _onRepDetected(delta: output.repDelta);
      }

      if (mounted) {
        setState(() {
          _qualityScore = output.qualityScore;
          _liveHint = output.hint;
          _liveErrors = output.errors;
        });
      }

      if (output.qualityScore < 60) {
        final now = DateTime.now();
        if (now.difference(_lastLowQualityHintAt) >
            const Duration(seconds: 9)) {
          _lastLowQualityHintAt = now;
          final advice = output.errors.isNotEmpty
              ? output.errors.first
              : 'Скорректируйте технику и темп';
          unawaited(_speak(advice));
        }
      }
    } finally {
      _isBusy = false;
    }
  }

  void _onRepDetected({int delta = 1}) {
    if (_isRestPhase || _isSessionFinished) {
      return;
    }
    final targetReps = _currentExercise.reps;
    final targetSets = _currentExercise.sets;

    setState(() {
      _repInSet += delta;
      _totalCompletedReps += delta;
    });

    if (_repInSet >= targetReps) {
      if (_setIndex >= targetSets) {
        _advanceExercise();
      } else {
        _startRest();
      }
    }
  }

  void _startRest() {
    _restTimer?.cancel();
    setState(() {
      _isRestPhase = true;
      _restSecondsLeft = _currentExercise.restSeconds;
    });
    unawaited(_speak('Подход завершён. Отдых $_restSecondsLeft секунд.'));

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _isRestPhase = false;
          _setIndex += 1;
          _repInSet = 0;
        });
        unawaited(_speak('Начинаем следующий подход.'));
      } else {
        setState(() {
          _restSecondsLeft -= 1;
        });
      }
    });
  }

  void _advanceExercise() {
    if (_exerciseIndex >= widget.dayPlan.exercises.length - 1) {
      _finishSession();
      return;
    }
    setState(() {
      _exerciseIndex += 1;
      _setIndex = 1;
      _repInSet = 0;
      _isRestPhase = false;
      _restSecondsLeft = 0;
    });
    unawaited(_speak('Следующее упражнение: ${_currentExercise.name}.'));
  }

  Future<void> _finishSession() async {
    if (_isSessionFinished) {
      return;
    }
    _isSessionFinished = true;
    _restTimer?.cancel();
    final durationMinutes = max(
      10,
      DateTime.now().difference(_startedAt).inMinutes,
    );
    final quality = _qualityScore;
    final perceivedDifficulty = (10 - (quality / 18)).clamp(3, 9).round();
    final fatigue = (7 + (100 - quality) / 25).clamp(4, 9).round();
    final enjoyment = (5 + quality / 20).clamp(4, 10).round();

    await _speak('Тренировка завершена. Результат сохранён.');
    await widget.onSessionFinished(
      completed: true,
      perceivedDifficulty: perceivedDifficulty,
      fatigueLevel: fatigue,
      enjoymentScore: enjoyment,
      workoutMinutes: durationMinutes,
      feedback:
          'Контроль с камерой: качество ${quality.toStringAsFixed(0)}%, повторы $_totalCompletedReps.',
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _speak(String text) async {
    if (!widget.appSettings.audioCoachEnabled) {
      return;
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  double _speechRateFromStyle(String style) {
    return switch (style) {
      'energetic' => 0.5,
      'neutral' => 0.44,
      _ => 0.4,
    };
  }

  double _pitchFromStyle(String style) {
    return switch (style) {
      'energetic' => 1.08,
      'neutral' => 1.0,
      _ => 0.96,
    };
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final rotation =
        InputImageRotationValue.fromRawValue(
          controller.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }

    final bytes = WriteBuffer();
    for (final plane in image.planes) {
      bytes.putUint8List(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: bytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  double _jointAngle(Offset a, Offset b, Offset c) {
    final ab = Offset(a.dx - b.dx, a.dy - b.dy);
    final cb = Offset(c.dx - b.dx, c.dy - b.dy);
    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final mag =
        sqrt(ab.dx * ab.dx + ab.dy * ab.dy) *
        sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    if (mag == 0) {
      return 180;
    }
    final cos = (dot / mag).clamp(-1.0, 1.0);
    return acos(cos) * 180 / pi;
  }

  double _angleFromVertical(Offset top, Offset bottom) {
    final dx = (bottom.dx - top.dx).abs();
    final dy = max(1.0, (bottom.dy - top.dy).abs());
    return atan(dx / dy) * 180 / pi;
  }

  @override
  Widget build(BuildContext context) {
    final total = max(1, _totalWorkReps);
    final progress = (_totalCompletedReps / total).clamp(0.0, 1.0).toDouble();
    final qualityColor = _qualityScore >= 85
        ? Colors.green
        : _qualityScore >= 65
        ? Colors.orange
        : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text('Тренировка с камерой • ${widget.dayPlan.title}'),
      ),
      body: _permissionError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_liveHint),
              ),
            )
          : !_isReady || _cameraController == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CameraViewport(controller: _cameraController!),
                        const IgnorePointer(child: _FramingGuideOverlay()),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Упражнение: ${_currentExercise.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Подход $_setIndex/${_currentExercise.sets} • Повторы $_repInSet/${_currentExercise.reps}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Качество выполнения: ${_qualityScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: qualityColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isRestPhase
                                ? 'Отдых: $_restSecondsLeft сек'
                                : _liveHint,
                          ),
                          if (!_isRestPhase && _liveErrors.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            for (final error in _liveErrors.take(2))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $error',
                                  style: const TextStyle(
                                    color: Color(0xFFC24747),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _finishSession,
                                  child: const Text('Завершить'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CameraViewport extends StatelessWidget {
  const _CameraViewport({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenRatio = constraints.maxWidth / constraints.maxHeight;
        final previewRatio = controller.value.aspectRatio;
        var scale = previewRatio / screenRatio;
        if (scale < 1) {
          scale = 1 / scale;
        }

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: ColoredBox(
                color: Colors.black,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: previewRatio,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FramingGuideOverlay extends StatelessWidget {
  const _FramingGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x99B6FFF1), width: 2),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Станьте в полный рост',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
