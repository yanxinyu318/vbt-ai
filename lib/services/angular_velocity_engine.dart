import 'dart:math';
import 'dart:collection';
import 'package:vbt/services/angle_calculator.dart';

class AngularVelocityResult {
  final String label;
  final double angleDeg;
  final double angularVelocityDegPerSec;
  final double angularVelocityRadPerSec;
  final double smoothedVelocityDegPerSec;
  final double timestamp;

  const AngularVelocityResult({
    required this.label,
    required this.angleDeg,
    required this.angularVelocityDegPerSec,
    required this.angularVelocityRadPerSec,
    required this.smoothedVelocityDegPerSec,
    required this.timestamp,
  });
}

class AngularVelocityEngine {
  final double _emaAlpha;
  final int _maxHistory;
  final Queue<_AngleSample> _history;
  double _smoothedVelocity = 0;
  String _activeJoint = '';

  AngularVelocityEngine({
    double emaAlpha = 0.3,
    int maxHistory = 120,
  })  : _emaAlpha = emaAlpha,
        _maxHistory = maxHistory,
        _history = Queue<_AngleSample>();

  double get smoothedVelocity => _smoothedVelocity;
  String get activeJoint => _activeJoint;

  AngularVelocityResult? process(JointAngle angle, {String? label}) {
    final now = angle.angleDeg;
    final ts = DateTime.now().millisecondsSinceEpoch / 1000.0;

    _history.addLast(_AngleSample(angleDeg: now, timestamp: ts));
    if (_history.length > _maxHistory) {
      _history.removeFirst();
    }

    _activeJoint = label ?? _jointLabel(angle);

    if (_history.length < 2) {
      return AngularVelocityResult(
        label: _activeJoint,
        angleDeg: now,
        angularVelocityDegPerSec: 0,
        angularVelocityRadPerSec: 0,
        smoothedVelocityDegPerSec: 0,
        timestamp: ts,
      );
    }

    final prev = _history.elementAt(_history.length - 2);
    final dt = ts - prev.timestamp;

    double rawVelocityDegPerSec = 0;
    if (dt > 1e-6) {
      rawVelocityDegPerSec = (now - prev.angleDeg) / dt;
    }

    _smoothedVelocity = _emaAlpha * rawVelocityDegPerSec +
        (1 - _emaAlpha) * _smoothedVelocity;

    return AngularVelocityResult(
      label: _activeJoint,
      angleDeg: now,
      angularVelocityDegPerSec: rawVelocityDegPerSec,
      angularVelocityRadPerSec: rawVelocityDegPerSec * pi / 180.0,
      smoothedVelocityDegPerSec: _smoothedVelocity,
      timestamp: ts,
    );
  }

  Map<String, AngularVelocityResult> processAll(
    Map<String, JointAngle> angles,
  ) {
    final results = <String, AngularVelocityResult>{};
    for (final entry in angles.entries) {
      final result = process(entry.value, label: entry.key);
      if (result != null) {
        results[entry.key] = result;
      }
    }
    return results;
  }

  String _jointLabel(JointAngle angle) {
    final jointName = angle.joint.name
        .replaceAll('PoseLandmarkType.', '')
        .replaceAll('left_', 'L.')
        .replaceAll('right_', 'R.')
        .replaceAll('shoulder', 'SH')
        .replaceAll('elbow', 'EL')
        .replaceAll('wrist', 'WR')
        .replaceAll('hip', 'HP')
        .replaceAll('knee', 'KN')
        .replaceAll('ankle', 'AN');
    return jointName;
  }

  void reset() {
    _history.clear();
    _smoothedVelocity = 0;
    _activeJoint = '';
  }
}

class _AngleSample {
  final double angleDeg;
  final double timestamp;

  const _AngleSample({required this.angleDeg, required this.timestamp});
}
