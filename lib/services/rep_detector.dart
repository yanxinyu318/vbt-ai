import 'dart:collection';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/services/position_tracker.dart';

enum RepPhase { idle, descending, ascending, completed }

class RepEvent {
  final BarbellPosition position;
  final RepEventType type;

  const RepEvent({required this.position, required this.type});
}

enum RepEventType { repStart, repEnd, none }

class DetectedRep {
  final List<BarbellPosition> positions;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final DateTime? concentricStartTime;

  DetectedRep({
    required this.positions,
    required this.startTime,
    required this.endTime,
    this.concentricStartTime,
  }) : duration = endTime.difference(startTime);

  Duration get eccentricDuration =>
      concentricStartTime != null
          ? concentricStartTime!.difference(startTime)
          : Duration.zero;

  Duration get concentricDuration =>
      concentricStartTime != null
          ? endTime.difference(concentricStartTime!)
          : Duration.zero;
}

class RepDetector {
  final Queue<SmoothedPosition> _recent;
  final int _windowSize;
  final double _velocityThreshold;
  final Duration _minRepDuration;

  RepPhase _phase = RepPhase.idle;
  DateTime? _repStart;
  DateTime? _concentricStart;
  List<BarbellPosition>? _currentRep;
  final List<DetectedRep> _completedReps = [];

  RepDetector({
    int windowSize = 5,
    double velocityThreshold = 0.15,
    Duration minRepDuration = const Duration(milliseconds: 200),
  })  : _recent = Queue<SmoothedPosition>(),
        _windowSize = windowSize,
        _velocityThreshold = velocityThreshold,
        _minRepDuration = minRepDuration;

  List<DetectedRep> get completedReps => List.unmodifiable(_completedReps);
  RepPhase get phase => _phase;

  List<BarbellPosition> get currentRepPositions =>
      _currentRep != null ? List.unmodifiable(_currentRep!) : const [];

  RepEvent process(SmoothedPosition pos) {
    _recent.addLast(pos);
    if (_recent.length > _windowSize) {
      _recent.removeFirst();
    }

    final velAvg = _averageVelocity();

    switch (_phase) {
      case RepPhase.idle:
        if (velAvg > _velocityThreshold) {
          return _startRep(pos);
        }
        return _noEvent(pos);

      case RepPhase.descending:
        if (velAvg < -_velocityThreshold * 0.3) {
          _concentricStart = pos.timestamp;
          _phase = RepPhase.ascending;
          return _noEvent(pos);
        }
        if (velAvg.abs() < _velocityThreshold * 0.2) {
          return _endRep(pos);
        }
        _currentRep?.add(BarbellPosition(
          x: pos.x,
          y: pos.y,
          confidence: pos.confidence,
          timestamp: pos.timestamp,
        ));
        return _noEvent(pos);

      case RepPhase.ascending:
        if (velAvg.abs() < _velocityThreshold * 0.2) {
          return _endRep(pos);
        }
        _currentRep?.add(BarbellPosition(
          x: pos.x,
          y: pos.y,
          confidence: pos.confidence,
          timestamp: pos.timestamp,
        ));
        return _noEvent(pos);

      case RepPhase.completed:
        if (velAvg.abs() < _velocityThreshold * 0.1) {
          _phase = RepPhase.idle;
        }
        return _noEvent(pos);
    }
  }

  RepEvent _startRep(SmoothedPosition pos) {
    _repStart = pos.timestamp;
    _concentricStart = null;
    _currentRep = [
      BarbellPosition(
        x: pos.x,
        y: pos.y,
        confidence: pos.confidence,
        timestamp: pos.timestamp,
      ),
    ];
    _phase = RepPhase.descending;
    return RepEvent(position: _currentRep!.last, type: RepEventType.repStart);
  }

  RepEvent _endRep(SmoothedPosition pos) {
    if (_currentRep == null || _repStart == null) {
      _phase = RepPhase.idle;
      return _noEvent(pos);
    }

    _currentRep!.add(BarbellPosition(
      x: pos.x,
      y: pos.y,
      confidence: pos.confidence,
      timestamp: pos.timestamp,
    ));

    final duration = pos.timestamp.difference(_repStart!);
    if (duration >= _minRepDuration) {
      _completedReps.add(DetectedRep(
        positions: List.from(_currentRep!),
        startTime: _repStart!,
        endTime: pos.timestamp,
        concentricStartTime: _concentricStart,
      ));
      _phase = RepPhase.completed;
      final event = RepEvent(position: _currentRep!.last, type: RepEventType.repEnd);
      _currentRep = null;
      _repStart = null;
      _concentricStart = null;
      return event;
    }

    _currentRep = null;
    _repStart = null;
    _concentricStart = null;
    _phase = RepPhase.idle;
    return _noEvent(pos);
  }

  RepEvent _noEvent(SmoothedPosition pos) {
    return RepEvent(position: BarbellPosition(
      x: pos.x,
      y: pos.y,
      confidence: pos.confidence,
      timestamp: pos.timestamp,
    ), type: RepEventType.none);
  }

  double _averageVelocity() {
    if (_recent.isEmpty) return 0;
    double sum = 0;
    for (final p in _recent) {
      sum += p.velocity;
    }
    return sum / _recent.length;
  }

  void reset() {
    _recent.clear();
    _phase = RepPhase.idle;
    _repStart = null;
    _concentricStart = null;
    _currentRep = null;
    _completedReps.clear();
  }
}
