import 'dart:collection';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/services/kalman_filter.dart';
import 'package:vbt/services/velocity_calculator.dart';

class SmoothedPosition {
  final double x;
  final double y;
  final double velocity;
  final double confidence;
  final DateTime timestamp;

  const SmoothedPosition({
    required this.x,
    required this.y,
    required this.velocity,
    required this.confidence,
    required this.timestamp,
  });
}

class PositionTracker {
  final KalmanFilter2D _kalman;
  final VelocityCalculator _velocityCalc;
  final Queue<BarbellPosition> _buffer;
  final int _maxBufferSize;
  DateTime? _lastTimestamp;

  SmoothedPosition? _lastSmoothed;
  double _currentVelocity = 0;
  static const double _maxJumpPx = 120.0;
  int _outlierCount = 0;
  static const int _maxOutliers = 10;

  PositionTracker({
    KalmanFilter2D? kalman,
    VelocityCalculator? velocityCalc,
    int maxBufferSize = 300,
    double pixelsPerMeter = 100,
  })  : _kalman = kalman ?? KalmanFilter2D(),
        _velocityCalc = velocityCalc ?? VelocityCalculator(pixelsPerMeter: pixelsPerMeter),
        _buffer = Queue<BarbellPosition>(),
        _maxBufferSize = maxBufferSize;

  SmoothedPosition? get lastSmoothed => _lastSmoothed;
  double get currentVelocity => _currentVelocity;
  List<BarbellPosition> get positionBuffer => _buffer.toList(growable: false);

  SmoothedPosition update(BarbellPosition raw) {
    final dt = _lastTimestamp != null
        ? raw.timestamp.difference(_lastTimestamp!).inMicroseconds / 1000000.0
        : 0.016;

    _lastTimestamp = raw.timestamp;

    if (_buffer.isNotEmpty) {
      final last = _buffer.last;
      final dx = raw.x - last.x;
      final dy = raw.y - last.y;
      final jump = (dx * dx + dy * dy);
      if (jump > _maxJumpPx * _maxJumpPx) {
        _outlierCount++;
        if (_outlierCount > _maxOutliers) {
          _kalman.reset();
          _buffer.clear();
          _currentVelocity = 0;
          _outlierCount = 0;
        }
        final predicted = _kalman.filter(raw.x, raw.y, dt);
        return SmoothedPosition(
          x: predicted.x,
          y: predicted.y,
          velocity: 0,
          confidence: raw.confidence,
          timestamp: raw.timestamp,
        );
      }
      _outlierCount = 0;
    }

    final filtered = _kalman.filter(raw.x, raw.y, dt);

    if (_buffer.length >= _maxBufferSize) {
      _buffer.removeFirst();
    }
    _buffer.add(raw);

    if (_buffer.length >= 2) {
      _currentVelocity = _velocityCalc.instantVelocity(
        _buffer.elementAt(_buffer.length - 2),
        _buffer.last,
      );
    }

    _lastSmoothed = SmoothedPosition(
      x: filtered.x,
      y: filtered.y,
      velocity: _currentVelocity,
      confidence: raw.confidence,
      timestamp: raw.timestamp,
    );

    return _lastSmoothed!;
  }

  VelocityResult computeSessionMetrics() {
    return _velocityCalc.calculate(_buffer.toList());
  }

  void reset() {
    _kalman.reset();
    _buffer.clear();
    _lastTimestamp = null;
    _lastSmoothed = null;
    _currentVelocity = 0;
  }
}
