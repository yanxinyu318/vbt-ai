import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vbt/features/camera/presentation/widgets/pose_overlay.dart';
import 'package:vbt/services/angle_calculator.dart';
import 'package:vbt/services/angular_velocity_engine.dart';
import 'package:vbt/services/pose_service.dart';

class PoseScreen extends StatefulWidget {
  const PoseScreen({super.key});

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  CameraController? _controller;
  late PoseDetector _detector;
  final AngularVelocityEngine _velEngine = AngularVelocityEngine();

  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  PoseResult? _poseResult;
  Map<String, JointAngle>? _angles;
  Map<String, AngularVelocityResult>? _velocities;
  String _exerciseType = 'squat';
  bool _processing = false;
  bool _initialized = false;
  bool _switching = false;

  static const _exercises = ['squat', 'bench', 'deadlift', 'overhead'];
  static const _exerciseLabels = {
    'squat': '深蹲',
    'bench': '卧推',
    'deadlift': '硬拉',
    'overhead': '推举',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await Permission.camera.request().isGranted;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相机权限被拒绝')),
        );
      }
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _currentCameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_currentCameraIndex < 0) _currentCameraIndex = 0;

    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );

    await _startCamera();
  }

  Future<void> _startCamera() async {
    final camera = _cameras[_currentCameraIndex];

    _controller?.stopImageStream();
    await _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      fps: 30,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {
        _initialized = true;
        _switching = false;
      });
      await _controller!.startImageStream(_onFrame);
    }
  }

  Future<void> _switchCamera() async {
    if (_switching || _cameras.length < 2) return;

    _skipCounter = 0;
    _processing = false;
    _poseResult = null;
    _angles = null;
    _velocities = null;

    setState(() => _switching = true);

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  int _skipCounter = 0;
  static const int _skipEvery = 8;

  void _onFrame(CameraImage image) {
    _skipCounter++;
    if (_skipCounter % _skipEvery != 0) return;
    if (_processing || !_initialized || _switching) return;

    _processing = true;
    _processFrame(image).whenComplete(() => _processing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final nv21 = _cameraImageToNv21(image);
      if (nv21 == null) return;

      final inputImage = InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _detector.processImage(inputImage);
      if (!mounted || _switching) return;

      if (poses.isEmpty) {
        dev.log('[POSE] no poses detected', name: 'PoseScreen');
        return;
      }

      final pose = poses.first;
      final landmarks = <PoseLandmarkType, PoseLandmarkData>{};
      for (final entry in pose.landmarks.entries) {
        landmarks[entry.key] = PoseLandmarkData(
          x: entry.value.x,
          y: entry.value.y,
          z: entry.value.z,
          likelihood: entry.value.likelihood,
        );
      }

      final poseResult = PoseResult(
        landmarks: landmarks,
        timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      );

      final angles = AngleCalculator.calculateExerciseAngles(
        poseResult,
        _exerciseType,
      );

      final velocities = _velEngine.processAll(angles);

      if (!mounted || _switching) return;
      setState(() {
        _poseResult = poseResult;
        _angles = angles;
        _velocities = velocities;
      });
    } catch (e, st) {
      dev.log('[POSE] error: $e', name: 'PoseScreen', stackTrace: st);
    }
  }

  Uint8List? _cameraImageToNv21(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final ySize = yPlane.bytes.length;
    final uvSize = uPlane.bytes.length + vPlane.bytes.length;
    final nv21 = Uint8List(ySize + uvSize);

    nv21.setRange(0, ySize, yPlane.bytes);

    int pos = ySize;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvHeight = (image.height / 2).ceil();

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < (image.width / 2).ceil(); col++) {
        final uvIndex = row * uvRowStride + col * uvPixelStride;
        if (uvIndex < vPlane.bytes.length) {
          nv21[pos++] = vPlane.bytes[uvIndex];
        }
        if (uvIndex < uPlane.bytes.length) {
          nv21[pos++] = uPlane.bytes[uvIndex];
        }
      }
    }

    return nv21;
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_initialized || _switching
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.cyan),
                  SizedBox(height: 16),
                  Text('正在初始化…', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _buildCameraView(),
    );
  }

  Widget _buildCameraView() {
    final controller = _controller!;
    final previewSize = controller.value.previewSize!;
    final rotation = controller.description.sensorOrientation;
    final isFront = controller.description.lensDirection == CameraLensDirection.front;

    return Stack(
      children: [
        ClipRect(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: Transform(
                  alignment: Alignment.center,
                  transform: isFront
                      ? (Matrix4.diagonal3Values(-1, 1, 1))
                      : Matrix4.identity(),
                  child: controller.buildPreview(),
                ),
              ),
            ),
          ),
        ),
        if (_poseResult != null)
          CustomPaint(
            size: Size.infinite,
            painter: PoseOverlayPainter(
              poseResult: _poseResult,
              angles: _angles,
              velocities: _velocities,
              frameWidth: previewSize.height,
              frameHeight: previewSize.width,
              sensorWidth: previewSize.width,
              sensorHeight: previewSize.height,
              sensorOrientation: rotation,
              mirrorX: isFront,
            ),
          ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 48,
          right: 8,
          child: _buildExerciseSelector(),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        if (_cameras.length > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: _switchCamera,
              icon: Icon(
                isFront ? Icons.camera_rear : Icons.camera_front,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        if (_velocities != null && _velocities!.isNotEmpty)
          Positioned(
            bottom: 48,
            left: 16,
            right: 16,
            child: _buildVelocityPanel(),
          ),
      ],
    );
  }

  Widget _buildExerciseSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: _exercises.map((ex) {
          final selected = ex == _exerciseType;
          return ChoiceChip(
            label: Text(_exerciseLabels[ex]!),
            selected: selected,
            onSelected: (_) => setState(() => _exerciseType = ex),
            selectedColor: Colors.cyan.withValues(alpha: 0.3),
            backgroundColor: Colors.white10,
            labelStyle: TextStyle(
              color: selected ? Colors.cyan : Colors.white60,
              fontSize: 11,
            ),
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  static const _jointLabelsZh = {
    'squat_left_knee': '左膝',
    'squat_right_knee': '右膝',
    'bench_left_elbow': '左肘',
    'bench_right_elbow': '右肘',
    'deadlift_left_hip': '左髋',
    'deadlift_right_hip': '右髋',
    'overhead_left_elbow': '左肘',
    'overhead_right_elbow': '右肘',
  };

  static String _jointLabelZh(String key) =>
      _jointLabelsZh[key] ?? key.replaceAll('_', ' ');

  Widget _buildVelocityPanel() {
    final entries = _velocities!.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    final primary = entries.first;
    final vel = primary.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${vel.angleDeg.toStringAsFixed(1)}°',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${vel.smoothedVelocityDegPerSec.toStringAsFixed(1)}°/s',
            style: TextStyle(
              fontSize: 16,
              color: _velColor(vel.smoothedVelocityDegPerSec),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _jointLabelZh(primary.key),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Color _velColor(double vel) {
    final abs = vel.abs();
    if (abs < 50) return Colors.white;
    if (abs < 150) return Colors.cyan;
    if (abs < 300) return Colors.limeAccent;
    return Colors.greenAccent;
  }
}
