import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/services/position_tracker.dart';

enum RepPhase { idle, eccentric, concentric }

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
  final double _minDisplacementPx;

  RepPhase _phase = RepPhase.idle;
  DateTime? _repStart;
  DateTime? _concentricStart;
  List<BarbellPosition>? _currentRep;
  final List<DetectedRep> _completedReps = [];
  double _minY = double.infinity;
  double _maxY = double.negativeInfinity;

  RepDetector({
    int windowSize = 7,
    double velocityThreshold = 0.08,
    Duration minRepDuration = const Duration(milliseconds: 300),
    double minDisplacementPx = 30,
  })  : _recent = Queue<SmoothedPosition>(),
        _windowSize = windowSize,
        _velocityThreshold = velocityThreshold,
        _minRepDuration = minRepDuration,
        _minDisplacementPx = minDisplacementPx;

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
    final event = _processPhase(pos, velAvg);

    if (event.type == RepEventType.repEnd) {
      debugPrint('[REP] rep #${_completedReps.length} completed (${_completedReps.last.duration.inMilliseconds}ms)');
    }

    return event;
  }

  RepEvent _processPhase(SmoothedPosition pos, double velAvg) {

    switch (_phase) {
      case RepPhase.idle:
        if (velAvg > _velocityThreshold) {
          return _startRep(pos);
        }
        return _noEvent(pos);

      case RepPhase.eccentric:
        _minY = _minY < pos.y ? _minY : pos.y;
        _maxY = _maxY > pos.y ? _maxY : pos.y;
        _currentRep?.add(BarbellPosition(
          x: pos.x, y: pos.y,
          confidence: pos.confidence, timestamp: pos.timestamp,
        ));
        if (velAvg < -_velocityThreshold) {
          _concentricStart = pos.timestamp;
          _phase = RepPhase.concentric;
          return _noEvent(pos);
        }
        return _noEvent(pos);

      case RepPhase.concentric:
        _minY = _minY < pos.y ? _minY : pos.y;
        _maxY = _maxY > pos.y ? _maxY : pos.y;
        _currentRep?.add(BarbellPosition(
          x: pos.x, y: pos.y,
          confidence: pos.confidence, timestamp: pos.timestamp,
        ));
        if (velAvg > _velocityThreshold * 0.3) {
          return _endRep(pos);
        }
        return _noEvent(pos);
    }
  }

  RepEvent _startRep(SmoothedPosition pos) {
    _repStart = pos.timestamp;
    _concentricStart = null;
    _minY = pos.y;
    _maxY = pos.y;
    _currentRep = [
      BarbellPosition(
        x: pos.x, y: pos.y,
        confidence: pos.confidence, timestamp: pos.timestamp,
      ),
    ];
    _phase = RepPhase.eccentric;
    return RepEvent(position: _currentRep!.last, type: RepEventType.repStart);
  }

  RepEvent _endRep(SmoothedPosition pos) {
    if (_currentRep == null || _repStart == null) {
      _phase = RepPhase.idle;
      return _noEvent(pos);
    }

    _currentRep!.add(BarbellPosition(
      x: pos.x, y: pos.y,
      confidence: pos.confidence, timestamp: pos.timestamp,
    ));

    final duration = pos.timestamp.difference(_repStart!);
    final displacement = (_maxY - _minY).abs();

    if (duration >= _minRepDuration && displacement >= _minDisplacementPx) {
      _completedReps.add(DetectedRep(
        positions: List.from(_currentRep!),
        startTime: _repStart!,
        endTime: pos.timestamp,
        concentricStartTime: _concentricStart,
      ));
      final event = RepEvent(position: _currentRep!.last, type: RepEventType.repEnd);
      _currentRep = null;
      _repStart = null;
      _concentricStart = null;
      _minY = double.infinity;
      _maxY = double.negativeInfinity;
      _phase = RepPhase.idle;
      return event;
    }

    _currentRep = null;
    _repStart = null;
    _concentricStart = null;
    _minY = double.infinity;
    _maxY = double.negativeInfinity;
    _phase = RepPhase.idle;
    return _noEvent(pos);
  }

  RepEvent _noEvent(SmoothedPosition pos) {
    return RepEvent(position: BarbellPosition(
      x: pos.x, y: pos.y,
      confidence: pos.confidence, timestamp: pos.timestamp,
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
    _minY = double.infinity;
    _maxY = double.negativeInfinity;
  }
}
