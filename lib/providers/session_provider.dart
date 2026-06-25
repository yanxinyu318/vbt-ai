import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/domain/entities/rep_metrics.dart';
import 'package:vbt/services/barbell_detector.dart';
import 'package:vbt/services/calibration_service.dart';
import 'package:vbt/services/camera_service.dart';
import 'package:vbt/services/frame_skip_strategy.dart';
import 'package:vbt/services/metrics_calculator.dart';
import 'package:vbt/services/position_tracker.dart';
import 'package:vbt/services/processed_frame.dart';
import 'package:vbt/services/rep_detector.dart';

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
  });

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
    );
  }
}

class SessionNotifier extends ChangeNotifier {
  final CameraService _camera;
  final BarbellDetector _detector;
  final CalibrationService _calibration;
  final RepDetector _repDetector;

  PositionTracker? _tracker;
  MetricsCalculator? _metrics;
  StreamSubscription<ProcessedFrame>? _frameSub;
  final Stopwatch _sessionTimer = Stopwatch();

  SessionNotifier({
    required CameraService camera,
    required BarbellDetector detector,
    required CalibrationService calibration,
    RepDetector? repDetector,
  })  : _camera = camera,
        _detector = detector,
        _calibration = calibration,
        _repDetector = repDetector ?? RepDetector();

  SessionState _state = const SessionState();
  SessionState get state => _state;

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
      await _detector.movenet.initialize();

      _state = _state.copyWith(
        status: SessionStatus.ready,
        isCalibrated: cal != null,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        status: SessionStatus.error,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  void startSession() {
    if (_state.status != SessionStatus.ready) return;

    _tracker?.reset();
    final repCount = _repDetector.completedReps.length;

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
              error: e.toString(),
            ));

    notifyListeners();
  }

  void _onFrame(ProcessedFrame frame) {
    if (_state.status != SessionStatus.recording) return;

    try {
      final position = _detector.detect(frame);
      if (position == null) return;

      final smoothed = _tracker!.update(position);
      final repEvent = _repDetector.process(smoothed);

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
        }
      }

      _state = _state.copyWith(
        currentVelocity: smoothed.velocity,
        barbellPosition: position,
        sessionDurationSec: _sessionTimer.elapsedMilliseconds / 1000,
      );
      notifyListeners();
    } catch (_) {}
  }

  void stopSession() {
    _frameSub?.cancel();
    _sessionTimer.stop();

    if (_tracker != null && _metrics != null) {
      _metrics!.calculateRep(
        _tracker!.positionBuffer,
        _state.repCount + 1,
      );
    }

    _state = _state.copyWith(status: SessionStatus.finished);
    notifyListeners();
  }

  void resetForNewSession() {
    _frameSub?.cancel();
    _sessionTimer.reset();
    _tracker?.reset();
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
  final detector = ref.read(barbellDetectorProvider);
  final cal = ref.read(calibrationServiceProvider);
  return SessionNotifier(camera: camera, detector: detector, calibration: cal);
});

final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService(skipStrategy: FrameSkipStrategy());
});
final barbellDetectorProvider = Provider<BarbellDetector>((ref) => BarbellDetector());
final calibrationServiceProvider = Provider<CalibrationService>((ref) => CalibrationService());
