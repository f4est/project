import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraQualityPage extends StatefulWidget {
  const CameraQualityPage({super.key});

  @override
  State<CameraQualityPage> createState() => _CameraQualityPageState();
}

class _CameraQualityPageState extends State<CameraQualityPage> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isBusy = false;
  bool _isReady = false;
  bool _isPermissionError = false;
  int _repCount = 0;
  double _qualityScore = 0;
  double _previousKneeAngle = 170;
  bool _isDownPhase = false;
  String _formHint = 'Встаньте в кадр полностью';

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isPermissionError = true;
          _formHint = 'Камера не найдена';
        });
        return;
      }

      final preferred = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        preferred,
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
    } catch (_) {
      setState(() {
        _isPermissionError = true;
        _formHint = 'Не удалось запустить камеру. Проверьте разрешения.';
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _cameraController;
    final detector = _poseDetector;
    if (_isBusy || controller == null || detector == null) {
      return;
    }
    _isBusy = true;

    try {
      final inputImage = _toInputImage(image, controller);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await detector.processImage(inputImage);
      if (poses.isEmpty) {
        if (mounted) {
          setState(() {
            _qualityScore = 0;
            _formHint = 'Тело не найдено. Отойдите на 2-3 метра.';
          });
        }
        _isBusy = false;
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

      if (leftKnee == null ||
          rightKnee == null ||
          leftHip == null ||
          rightHip == null ||
          leftAnkle == null ||
          rightAnkle == null ||
          leftShoulder == null ||
          rightShoulder == null) {
        if (mounted) {
          setState(() {
            _formHint = 'В кадре должны быть видны плечи, таз, колени и голеностоп.';
          });
        }
        _isBusy = false;
        return;
      }

      final leftAngle = _jointAngle(
        Offset(leftHip.x, leftHip.y),
        Offset(leftKnee.x, leftKnee.y),
        Offset(leftAnkle.x, leftAnkle.y),
      );
      final rightAngle = _jointAngle(
        Offset(rightHip.x, rightHip.y),
        Offset(rightKnee.x, rightKnee.y),
        Offset(rightAnkle.x, rightAnkle.y),
      );
      final kneeAngle = (leftAngle + rightAngle) / 2;

      final shoulderTilt = (leftShoulder.y - rightShoulder.y).abs();
      final hipTilt = (leftHip.y - rightHip.y).abs();
      final symmetryPenalty = min(30.0, shoulderTilt * 0.05 + hipTilt * 0.05);
      final depthBonus = kneeAngle < 120 ? 18.0 : 0.0;
      final score = (78 + depthBonus - symmetryPenalty).clamp(0, 100).toDouble();

      if (_previousKneeAngle > 155 && kneeAngle < 115 && !_isDownPhase) {
        _isDownPhase = true;
      } else if (_isDownPhase && kneeAngle > 155) {
        _isDownPhase = false;
        _repCount += 1;
      }
      _previousKneeAngle = kneeAngle;

      final hint = score >= 85
          ? 'Техника хорошая. Держите темп.'
          : score >= 65
              ? 'Почти хорошо. Контролируйте ровное положение корпуса.'
              : 'Исправьте технику: следите за симметрией и амплитудой.';

      if (mounted) {
        setState(() {
          _qualityScore = score;
          _formHint = hint;
        });
      }
    } catch (_) {
      // Ignore frame-level failures to keep live tracking stable.
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final rotation = InputImageRotationValue.fromRawValue(
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
    final mag = sqrt(ab.dx * ab.dx + ab.dy * ab.dy) *
        sqrt(cb.dx * cb.dx + cb.dy * cb.dy);
    if (mag == 0) {
      return 180;
    }
    final cos = (dot / mag).clamp(-1.0, 1.0);
    return acos(cos) * 180 / pi;
  }

  @override
  Widget build(BuildContext context) {
    final qualityColor = _qualityScore >= 85
        ? Colors.green
        : _qualityScore >= 65
            ? Colors.orange
            : Colors.red;

    return Scaffold(
      appBar: AppBar(title: const Text('Камера: контроль техники')),
      body: _isPermissionError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _formHint,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : !_isReady || _cameraController == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(child: CameraPreview(_cameraController!)),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: Card(
                        color: Colors.black.withValues(alpha: 0.62),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Качество техники: ${_qualityScore.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: qualityColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Повторы: $_repCount',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formHint,
                                style: const TextStyle(color: Colors.white),
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
