import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/domain/entities/rep_metrics.dart';
import 'package:vbt/services/calibration_service.dart';
import 'package:vbt/services/camera_service.dart';
import 'package:vbt/services/frame_skip_strategy.dart';
import 'package:vbt/services/metrics_calculator.dart';
import 'package:vbt/services/position_tracker.dart';
import 'package:vbt/services/processed_frame.dart';
import 'package:vbt/services/rep_detector.dart';
import 'package:vbt/services/tracking_fusion.dart';

enum SessionStatus { idle, initializing, ready, recording, finished, error }

class SessionState {
  final SessionStatus status;
  final String? error;
  final double currentVelocity;
  final int repCount;
  final List<RepMetrics> completedReps;
  final BarbellPosition? barbellPosition;
  final double sessionDurationSec;
  final bool isCalibrated;
  final PerformanceMode performanceMode;
  final Offset? pointA;
  final Offset? pointB;

  const SessionState({
    this.status = SessionStatus.idle,
    this.error,
    this.currentVelocity = 0,
    this.repCount = 0,
    this.completedReps = const [],
    this.barbellPosition,
    this.sessionDurationSec = 0,
    this.isCalibrated = false,
    this.performanceMode = PerformanceMode.balanced,
    this.pointA,
    this.pointB,
  });

  bool get hasBothPoints => pointA != null && pointB != null;

  Offset? get referenceCenter {
    if (pointA == null || pointB == null) return null;
    return Offset(
      (pointA!.dx + pointB!.dx) / 2,
      (pointA!.dy + pointB!.dy) / 2,
    );
  }

  SessionState copyWith({
    SessionStatus? status,
    String? error,
    double? currentVelocity,
    int? repCount,
    List<RepMetrics>? completedReps,
    BarbellPosition? barbellPosition,
    double? sessionDurationSec,
    bool? isCalibrated,
    PerformanceMode? performanceMode,
    Offset? pointA,
    Offset? pointB,
  }) {
    return SessionState(
      status: status ?? this.status,
      error: error ?? this.error,
      currentVelocity: currentVelocity ?? this.currentVelocity,
      repCount: repCount ?? this.repCount,
      completedReps: completedReps ?? this.completedReps,
      barbellPosition: barbellPosition ?? this.barbellPosition,
      sessionDurationSec: sessionDurationSec ?? this.sessionDurationSec,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      performanceMode: performanceMode ?? this.performanceMode,
      pointA: pointA ?? this.pointA,
      pointB: pointB ?? this.pointB,
    );
  }
}

class SessionNotifier extends ChangeNotifier {
  final CameraService _camera;
  final TrackingFusion _fusion;
  final CalibrationService _calibration;
  final RepDetector _repDetector;

  PositionTracker? _tracker;
  MetricsCalculator? _metrics;
  StreamSubscription<ProcessedFrame>? _frameSub;
  final Stopwatch _sessionTimer = Stopwatch();

  SessionNotifier({
    required CameraService camera,
    required TrackingFusion fusion,
    required CalibrationService calibration,
    RepDetector? repDetector,
  })  : _camera = camera,
        _fusion = fusion,
        _calibration = calibration,
        _repDetector = repDetector ?? RepDetector();

  SessionState _state = const SessionState();
  SessionState get state => _state;

  double _frameWidth = 720;
  double _frameHeight = 1280;
  double _cameraFrameWidth = 720;
  double _cameraFrameHeight = 1280;

  void setFrameSize(double screenWidth, double screenHeight, double cameraFrameWidth, double cameraFrameHeight) {
    _frameWidth = screenWidth;
    _frameHeight = screenHeight;
    _cameraFrameWidth = cameraFrameWidth;
    _cameraFrameHeight = cameraFrameHeight;
  }

  void setCalibrationPoint(Offset screenPoint) {
    if (_state.status != SessionStatus.ready) return;

    if (_state.pointA == null) {
      _state = _state.copyWith(pointA: screenPoint);
    } else if (_state.pointB == null) {
      _state = _state.copyWith(pointB: screenPoint);
    }
    notifyListeners();
  }

  void clearCalibration() {
    _state = _state.copyWith(
      pointA: null,
      pointB: null,
    );
    notifyListeners();
  }

  Future<void> initialize() async {
    _state = _state.copyWith(status: SessionStatus.initializing);
    notifyListeners();

    try {
      _repDetector.reset();
      _camera.skipStrategy.reset();

      final cal = await _calibration.load();
      final ppm = cal?.pixelsPerMeter ?? 100;

      _tracker = PositionTracker(pixelsPerMeter: ppm);
      _metrics = MetricsCalculator(pixelsPerMeter: ppm);

      await _camera.initialize();

      _fusion.movenet.initialize().then((_) {
        debugPrint('[FUSE] MoveNet ready (optional sanity check)');
      }).catchError((e) {
        debugPrint('[FUSE] MoveNet init failed (non-fatal): $e');
      });

      _state = _state.copyWith(
        status: SessionStatus.ready,
        isCalibrated: cal != null,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: SessionStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      notifyListeners();
    }
  }

  void startSession() {
    if (_state.status != SessionStatus.ready) return;
    if (!_state.hasBothPoints) return;

    _tracker?.reset();
    final repCount = _repDetector.completedReps.length;

    if (_state.pointA != null && _state.pointB != null) {
      final screenW = _frameWidth;
      final screenH = _frameHeight;
      final frameW = _cameraFrameWidth;
      final frameH = _cameraFrameHeight;

      final frameAspect = frameW / frameH;
      final screenAspect = screenW / screenH;

      double scale, offsetX = 0, offsetY = 0;
      if (screenAspect > frameAspect) {
        scale = screenW / frameW;
        final renderedH = frameH * scale;
        offsetY = (screenH - renderedH) / 2;
      } else {
        scale = screenH / frameH;
        final renderedW = frameW * scale;
        offsetX = (screenW - renderedW) / 2;
      }

      final pA = _state.pointA!;
      final pB = _state.pointB!;

      final ax = (pA.dx - offsetX) / scale;
      final ay = (pA.dy - offsetY) / scale;
      final bx = (pB.dx - offsetX) / scale;
      final by = (pB.dy - offsetY) / scale;

      final cx = (ax + bx) / 2;
      final cy = (ay + by) / 2;

      _fusion.initialize(cx, cy);
      debugPrint('[FUSE] ROI init: center=(${cx.toStringAsFixed(1)},${cy.toStringAsFixed(1)})');
    }

    _state = _state.copyWith(
      status: SessionStatus.recording,
      currentVelocity: 0,
      repCount: repCount,
      completedReps: List.from(_state.completedReps),
    );
    _sessionTimer.reset();
    _sessionTimer.start();

    _frameSub?.cancel();
    _frameSub = _camera.frameStream.listen(_onFrame,
        onError: (e) => _state = _state.copyWith(
              status: SessionStatus.error,
              error: e.toString().replaceFirst('Exception: ', ''),
            ));

    notifyListeners();
  }

  void _onFrame(ProcessedFrame frame) {
    if (_state.status != SessionStatus.recording) return;

    try {
      final position = _fusion.process(frame);
      if (position != null) {
        final smoothed = _tracker!.update(position);
        final repEvent = _repDetector.process(smoothed);

        if (repEvent.type == RepEventType.repStart) {
          debugPrint('[REP] started');
        }
        if (repEvent.type == RepEventType.repEnd) {
          final repNumber = _state.repCount + 1;
          final repPositions = _repDetector.currentRepPositions;
          if (repPositions.isNotEmpty && _metrics != null) {
            final dr = _repDetector.completedReps.isNotEmpty
                ? _repDetector.completedReps.last
                : null;
            final metrics = _metrics!.calculateRep(
              repPositions,
              repNumber,
              concentricTimeMs: dr?.concentricDuration.inMilliseconds ?? 0,
              eccentricTimeMs: dr?.eccentricDuration.inMilliseconds ?? 0,
              totalRepTimeMs: dr?.duration.inMilliseconds ?? 0,
            );
            _state = _state.copyWith(
              repCount: repNumber,
              completedReps: [..._state.completedReps, metrics],
            );
            debugPrint('[REP] #$repNumber done v=${metrics.meanVelocity.toStringAsFixed(2)}');
          }
        }

        _state = _state.copyWith(
          currentVelocity: smoothed.velocity,
          barbellPosition: position,
          sessionDurationSec: _sessionTimer.elapsedMilliseconds / 1000,
        );
      }

      notifyListeners();
    } catch (_) {}
  }

  void stopSession() {
    _frameSub?.cancel();
    _sessionTimer.stop();
    _fusion.reset();

    if (_tracker != null && _metrics != null && _tracker!.positionBuffer.isNotEmpty) {
      final repNumber = _state.repCount + 1;
      final metrics = _metrics!.calculateRep(
        _tracker!.positionBuffer,
        repNumber,
      );
      _state = _state.copyWith(
        repCount: repNumber,
        completedReps: [..._state.completedReps, metrics],
      );
    }

    _state = _state.copyWith(
      status: SessionStatus.finished,
    );
    notifyListeners();
  }

  void resetForNewSession() {
    _frameSub?.cancel();
    _sessionTimer.reset();
    _tracker?.reset();
    _fusion.reset();
    _state = SessionState(
      status: SessionStatus.ready,
      isCalibrated: _calibration.isCalibrated,
    );
    notifyListeners();
  }

  void changePerformanceMode(PerformanceMode mode) {
    _state = _state.copyWith(performanceMode: mode);
    _camera.skipStrategy.updateMode(mode);
    notifyListeners();
  }

  Future<void> recalibrate() async {
    await _calibration.load();
    _state = _state.copyWith(isCalibrated: _calibration.isCalibrated);
    notifyListeners();
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    super.dispose();
  }
}

final sessionProvider = ChangeNotifierProvider<SessionNotifier>((ref) {
  final camera = ref.read(cameraServiceProvider);
  final fusion = ref.read(trackingFusionProvider);
  final cal = ref.read(calibrationServiceProvider);
  return SessionNotifier(camera: camera, fusion: fusion, calibration: cal);
});

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService(skipStrategy: FrameSkipStrategy());
});
final trackingFusionProvider = Provider<TrackingFusion>((ref) => TrackingFusion());
final calibrationServiceProvider = Provider<CalibrationService>((ref) => CalibrationService());
