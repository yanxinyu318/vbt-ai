import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vbt/services/processed_frame.dart';

class PoseLandmarkData {
  final double x;
  final double y;
  final double z;
  final double likelihood;

  const PoseLandmarkData({
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });
}

class PoseResult {
  final Map<PoseLandmarkType, PoseLandmarkData> landmarks;
  final double timestamp;

  const PoseResult({
    required this.landmarks,
    required this.timestamp,
  });

  PoseLandmarkData? operator [](PoseLandmarkType type) => landmarks[type];
}

class PoseService {
  late PoseDetector _detector;
  bool _initialized = false;
  bool _processing = false;

  bool get isReady => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.accurate,
        mode: PoseDetectionMode.stream,
      ),
    );
    _initialized = true;
    debugPrint('[POSE] initialized');
  }

  Future<PoseResult?> processFrame(ProcessedFrame frame) async {
    if (!_initialized || _processing) return null;

    _processing = true;
    try {
      final inputImage = _createInputImage(frame);
      if (inputImage == null) return null;

      final poses = await _detector.processImage(inputImage);
      if (poses.isEmpty) return null;

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

      return PoseResult(
        landmarks: landmarks,
        timestamp: frame.timestamp.millisecondsSinceEpoch / 1000.0,
      );
    } catch (e) {
      debugPrint('[POSE] error: $e');
      return null;
    } finally {
      _processing = false;
    }
  }

  InputImage? _createInputImage(ProcessedFrame frame) {
    try {
      if (frame.yBytes == null || frame.uvBytes == null) {
        debugPrint('[POSE] no YUV data, falling back to RGB conversion');
        return _createInputImageFromRgb(frame);
      }

      final nv21 = Uint8List(frame.yBytes!.length + frame.uvBytes!.length);
      nv21.setRange(0, frame.yBytes!.length, frame.yBytes!);
      nv21.setRange(frame.yBytes!.length, nv21.length, frame.uvBytes!);

      final metadata = InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.yRowStride ?? frame.width,
      );

      return InputImage.fromBytes(
        bytes: nv21,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[POSE] conversion error: $e');
      return null;
    }
  }

  InputImage? _createInputImageFromRgb(ProcessedFrame frame) {
    try {
      final bgra = Uint8List(frame.width * frame.height * 4);
      for (int i = 0, j = 0; i < frame.rgbBytes.length; i += 3, j += 4) {
        bgra[j] = frame.rgbBytes[i + 2];
        bgra[j + 1] = frame.rgbBytes[i + 1];
        bgra[j + 2] = frame.rgbBytes[i];
        bgra[j + 3] = 255;
      }

      final metadata = InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: frame.width * 4,
      );

      return InputImage.fromBytes(
        bytes: bgra,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[POSE] RGB conversion error: $e');
      return null;
    }
  }

  Future<void> close() async {
    if (_initialized) {
      await _detector.close();
      _initialized = false;
    }
  }
}
