import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    required this.nowProvider,
    required this.onSessionFinished,
  });

  final DailyWorkoutPlan dayPlan;
  final AppSettings appSettings;
  final DateTime Function() nowProvider;
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
  CameraLensDirection _lensDirection = CameraLensDirection.front;

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
  DateTime _lastTechniqueHintAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFrameUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _liveHint = 'Подготовьтесь и начните движение.';
  String _repStatus =
      'Повторы начнут считаться после первого корректного движения.';
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
    _startedAt = widget.nowProvider();
    _lastFrameUpdateAt = widget.nowProvider();
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
      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      await _poseDetector?.close();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _permissionError = true;
          _liveHint = 'Камера не найдена.';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );

      final detector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );

      final controller = await _startCameraWithFallback(camera);

      setState(() {
        _cameraController = controller;
        _poseDetector = detector;
        _isReady = true;
        _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
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

  Future<void> _switchCamera() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isReady = false;
      _lensDirection = _lensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _liveHint = _lensDirection == CameraLensDirection.front
          ? 'Переключено на фронтальную камеру.'
          : 'Переключено на основную камеру.';
    });
    await _setup();
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
    final now = widget.nowProvider();
    if (now.difference(_lastFrameProcessedAt) <
        const Duration(milliseconds: 70)) {
      return;
    }
    _lastFrameProcessedAt = now;
    final controller = _cameraController;
    final detector = _poseDetector;
    if (controller == null || detector == null) {
      return;
    }
    _isBusy = true;
    try {
      final inputImage = _toInputImage(image, controller);
      if (inputImage == null) {
        await _notifyTechniqueIssue(
          'Формат камеры не поддерживается для анализа.',
          voiceText: 'Не удаётся обработать кадр с камеры.',
        );
        if (mounted) {
          setState(() {
            _liveHint = 'Камера работает, но анализ кадра не запускается.';
            _repStatus = 'Повтор не засчитан: кадр не обработан.';
          });
        }
        return;
      }
      final poses = await detector.processImage(inputImage);
      _lastFrameUpdateAt = widget.nowProvider();
      if (poses.isEmpty) {
        await _notifyTechniqueIssue(
          'Камера не видит тело полностью.',
          voiceText: 'Встаньте так, чтобы камера видела вас полностью.',
        );
        if (mounted) {
          setState(() {
            _qualityScore = 0;
            _liveHint = 'Встаньте так, чтобы в кадр попадало всё тело.';
            _repStatus = 'Повтор не засчитан: не видно позу.';
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
      final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
      final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
      final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
      final nose = pose.landmarks[PoseLandmarkType.nose];

      final hasLeftLeg =
          _landmarkReady(leftKnee) &&
          _landmarkReady(leftHip) &&
          _landmarkReady(leftAnkle);
      final hasRightLeg =
          _landmarkReady(rightKnee) &&
          _landmarkReady(rightHip) &&
          _landmarkReady(rightAnkle);
      final hasShoulders =
          _landmarkReady(leftShoulder) || _landmarkReady(rightShoulder);
      final hasHips = _landmarkReady(leftHip) || _landmarkReady(rightHip);

      if ((!hasLeftLeg && !hasRightLeg) ||
          !hasShoulders ||
          !hasHips ||
          !_landmarkReady(nose)) {
        await _notifyTechniqueIssue(
          'Не видны ключевые точки тела.',
          voiceText: 'Поставьте камеру так, чтобы были видны корпус и ноги.',
        );
        if (mounted) {
          setState(() {
            _liveHint = 'Камера видит не все ключевые точки тела.';
            _qualityScore = 0;
            _liveErrors = const [
              'Встаньте так, чтобы было видно корпус и ноги.',
            ];
            _repStatus = 'Повтор не засчитан: не хватает точек для анализа.';
          });
        }
        return;
      }
      final nosePoint = nose!;

      final shoulderMid = _midpoint(leftShoulder, rightShoulder);
      final hipMid = _midpoint(leftHip, rightHip);
      final ankleMid = _midpoint(leftAnkle, rightAnkle);
      if (shoulderMid == null || hipMid == null || ankleMid == null) {
        await _notifyTechniqueIssue(
          'Недостаточно точек для построения позы.',
          voiceText: 'Подвиньте камеру, чтобы были видны плечи, таз и ноги.',
        );
        if (mounted) {
          setState(() {
            _liveHint = 'Поправьте положение камеры.';
            _qualityScore = 0;
            _liveErrors = const ['Нужно лучше видеть корпус и ноги.'];
            _repStatus = 'Повтор не засчитан: позиция камеры не подходит.';
          });
        }
        return;
      }
      final leftKneeAngle = hasLeftLeg
          ? _jointAngle(
              Offset(leftHip!.x, leftHip.y),
              Offset(leftKnee!.x, leftKnee.y),
              Offset(leftAnkle!.x, leftAnkle.y),
            )
          : null;
      final rightKneeAngle = hasRightLeg
          ? _jointAngle(
              Offset(rightHip!.x, rightHip.y),
              Offset(rightKnee!.x, rightKnee.y),
              Offset(rightAnkle!.x, rightAnkle.y),
            )
          : null;
      final kneeAngle =
          _averageNullable(leftKneeAngle, rightKneeAngle) ??
          leftKneeAngle ??
          rightKneeAngle ??
          170;
      final leftElbowAngle =
          (leftShoulder != null && leftElbow != null && leftWrist != null)
          ? _jointAngle(
              Offset(leftShoulder.x, leftShoulder.y),
              Offset(leftElbow.x, leftElbow.y),
              Offset(leftWrist.x, leftWrist.y),
            )
          : null;
      final rightElbowAngle =
          (rightShoulder != null && rightElbow != null && rightWrist != null)
          ? _jointAngle(
              Offset(rightShoulder.x, rightShoulder.y),
              Offset(rightElbow.x, rightElbow.y),
              Offset(rightWrist.x, rightWrist.y),
            )
          : null;
      final elbowAngle =
          _averageNullable(leftElbowAngle, rightElbowAngle) ??
          leftElbowAngle ??
          rightElbowAngle ??
          170;
      final bodySpan = (ankleMid - Offset(nosePoint.x, nosePoint.y)).distance;
      final frameSpan = max(image.width.toDouble(), image.height.toDouble());
      final bodyCoverage = bodySpan / max(1.0, frameSpan);
      if (bodyCoverage < 0.32) {
        await _notifyTechniqueIssue(
          'Слишком близко к камере.',
          voiceText: 'Отойдите назад, чтобы в кадре были корпус и ноги.',
        );
        if (mounted) {
          setState(() {
            _qualityScore = 0;
            _liveHint =
                'Отойдите немного назад: в кадре должны быть корпус и ноги.';
            _liveErrors = const [
              'Старайтесь держать в кадре хотя бы верх тела и ноги до щиколоток.',
            ];
            _repStatus = 'Повтор не засчитан: мало тела в кадре.';
          });
        }
        return;
      }
      final shoulderWidth = _horizontalDistance(leftShoulder, rightShoulder);
      final torsoHeight = max(1.0, (hipMid.dy - shoulderMid.dy).abs());

      final shoulderTilt = _lineTiltAngle(leftShoulder, rightShoulder);
      final hipTilt = _lineTiltAngle(leftHip, rightHip);
      final torsoLean = _angleFromVertical(shoulderMid, hipMid);
      final twistOffset = shoulderWidth <= 1
          ? 0.0
          : (shoulderMid.dx - hipMid.dx) / shoulderWidth;
      final plankLineError = (180 - _jointAngle(shoulderMid, hipMid, ankleMid))
          .abs();
      final hipHeightBias = (hipMid.dy - shoulderMid.dy) / torsoHeight - 1.0;

      final output = _analyzer.analyze(
        exerciseName: _currentExercise.name,
        now: widget.nowProvider(),
        metrics: BodyMetrics(
          kneeAngle: kneeAngle,
          elbowAngle: elbowAngle,
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
        if (mounted) {
          setState(() {
            _repStatus = 'Повтор засчитан.';
          });
        }
      } else if (!_isRestPhase) {
        final reason = output.errors.isNotEmpty
            ? output.errors.first
            : 'Завершите движение полной амплитудой.';
        if (mounted) {
          setState(() {
            _repStatus = 'Повтор не засчитан: $reason';
          });
        }
        await _notifyTechniqueIssue(reason, voiceText: reason);
      }

      if (mounted) {
        setState(() {
          _qualityScore = output.qualityScore;
          _liveHint = output.hint;
          _liveErrors = output.errors;
        });
      }

      if (output.qualityScore < 60) {
        final now = widget.nowProvider();
        if (now.difference(_lastLowQualityHintAt) >
            const Duration(seconds: 9)) {
          _lastLowQualityHintAt = now;
          final advice = output.errors.isNotEmpty
              ? output.errors.first
              : 'Скорректируйте технику и темп';
          unawaited(_speak(advice));
        }
      }
    } catch (e) {
      final userError = _userFacingAnalysisError(e);
      await _notifyTechniqueIssue(
        userError,
        voiceText:
            'Не получается распознать движение. Попробуйте другой ракурс.',
      );
      if (mounted) {
        setState(() {
          _repStatus = 'Повтор не засчитан: $userError';
        });
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _notifyTechniqueIssue(
    String message, {
    required String voiceText,
  }) async {
    final now = widget.nowProvider();
    if (now.difference(_lastTechniqueHintAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastTechniqueHintAt = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
    await _speak(voiceText);
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
      widget.nowProvider().difference(_startedAt).inMinutes,
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
    final rotation = _inputImageRotationFromController(controller);
    final rawFormat = InputImageFormatValue.fromRawValue(image.format.raw);
    final format = _supportedFormat(rawFormat);
    if (format == null || image.planes.isEmpty) {
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

  InputImageRotation _inputImageRotationFromController(
    CameraController controller,
  ) {
    final sensor = controller.description.sensorOrientation;
    final deviceDegrees = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final lens = controller.description.lensDirection;
    final rotationComp = lens == CameraLensDirection.front
        ? (sensor + deviceDegrees) % 360
        : (sensor - deviceDegrees + 360) % 360;
    return InputImageRotationValue.fromRawValue(rotationComp) ??
        InputImageRotation.rotation0deg;
  }

  Future<CameraController> _startCameraWithFallback(
    CameraDescription camera,
  ) async {
    Object? lastError;
    for (final config in _cameraConfigsForPlatform()) {
      CameraController? controller;
      try {
        controller = CameraController(
          camera,
          config.resolutionPreset,
          enableAudio: false,
          imageFormatGroup: config.imageFormatGroup,
        );
        await controller.initialize();
        await controller.startImageStream(_processFrame);
        return controller;
      } catch (e) {
        lastError = e;
        await controller?.dispose();
      }
    }
    throw Exception(
      'Не удалось запустить камеру: ${lastError ?? 'неизвестная ошибка'}',
    );
  }

  List<_CameraConfig> _cameraConfigsForPlatform() {
    if (Platform.isAndroid) {
      return const [
        _CameraConfig(ResolutionPreset.medium, ImageFormatGroup.nv21),
        _CameraConfig(ResolutionPreset.medium, ImageFormatGroup.yuv420),
        _CameraConfig(ResolutionPreset.high, ImageFormatGroup.yuv420),
        _CameraConfig(ResolutionPreset.low, ImageFormatGroup.nv21),
        _CameraConfig(ResolutionPreset.low, ImageFormatGroup.yuv420),
      ];
    }
    return const [
      _CameraConfig(ResolutionPreset.medium, ImageFormatGroup.bgra8888),
      _CameraConfig(ResolutionPreset.high, ImageFormatGroup.bgra8888),
    ];
  }

  InputImageFormat? _supportedFormat(InputImageFormat? format) {
    return switch (format) {
      InputImageFormat.nv21 => InputImageFormat.nv21,
      InputImageFormat.bgra8888 => InputImageFormat.bgra8888,
      InputImageFormat.yuv420 => InputImageFormat.yuv420,
      _ => null,
    };
  }

  String _userFacingAnalysisError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('format') || text.contains('inputimage')) {
      return 'Камера передает неподходящий формат. Перезапустите тренировку.';
    }
    if (text.contains('camera')) {
      return 'Поток камеры нестабилен. Попробуйте переключить камеру.';
    }
    if (text.contains('pose') || text.contains('ml')) {
      return 'Система не видит движение достаточно четко. Добавьте свет и отойдите дальше.';
    }
    if (text.contains('illegalstate') || text.contains('state')) {
      return 'Сервис распознавания перезапускается. Повторите попытку через пару секунд.';
    }
    return 'Распознавание временно недоступно. Попробуйте сменить ракурс.';
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

  Offset? _midpoint(PoseLandmark? a, PoseLandmark? b) {
    if (a == null && b == null) {
      return null;
    }
    if (a != null && b != null) {
      return Offset((a.x + b.x) / 2, (a.y + b.y) / 2);
    }
    final p = a ?? b!;
    return Offset(p.x, p.y);
  }

  double _lineTiltAngle(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) {
      return 0;
    }
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    if (dx < 1) {
      return 90;
    }
    return atan(dy / dx) * 180 / pi;
  }

  double _horizontalDistance(PoseLandmark? a, PoseLandmark? b) {
    if (a == null || b == null) {
      return 0;
    }
    return (a.x - b.x).abs();
  }

  double? _averageNullable(double? a, double? b) {
    if (a == null && b == null) {
      return null;
    }
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return (a + b) / 2;
  }

  bool _landmarkReady(PoseLandmark? point) {
    if (point == null) {
      return false;
    }
    final likelihood = point.likelihood;
    if (likelihood.isNaN || likelihood <= 0) {
      return true;
    }
    return likelihood >= 0.35;
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
        actions: [
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
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
                if (_lastFrameUpdateAt !=
                        DateTime.fromMillisecondsSinceEpoch(0) &&
                    widget.nowProvider().difference(_lastFrameUpdateAt) >
                        const Duration(seconds: 3))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Временная потеря трекинга: поправьте камеру, освещение или дистанцию.',
                      ),
                    ),
                  ),
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
                          const SizedBox(height: 4),
                          Text(
                            _repStatus,
                            style: TextStyle(
                              color: _repStatus.startsWith('Повтор засчитан')
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
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

class _CameraConfig {
  const _CameraConfig(this.resolutionPreset, this.imageFormatGroup);

  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup imageFormatGroup;
}

class _CameraViewport extends StatelessWidget {
  const _CameraViewport({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final previewSize = controller.value.previewSize;
    final previewAspectRatio = previewSize == null
        ? controller.value.aspectRatio
        : previewSize.height / previewSize.width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1,
              height: 1 / previewAspectRatio,
              child: CameraPreview(controller),
            ),
          ),
        ),
      ),
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
