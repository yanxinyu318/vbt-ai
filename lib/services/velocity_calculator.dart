import 'dart:math';
import 'package:vbt/domain/entities/barbell_position.dart';

class VelocityResult {
  final double meanVelocity;
  final double peakVelocity;
  final double displacement;
  final double meanVelocityPxPerSec;
  final double peakVelocityPxPerSec;
  final double displacementPx;
  final int frameCount;
  final double durationSec;
  final double peakAcceleration;
  final double rom;
  final double romPx;
  final List<double> velocityTrace;

  const VelocityResult({
    required this.meanVelocity,
    required this.peakVelocity,
    required this.displacement,
    required this.meanVelocityPxPerSec,
    required this.peakVelocityPxPerSec,
    required this.displacementPx,
    required this.frameCount,
    required this.durationSec,
    this.peakAcceleration = 0,
    this.rom = 0,
    this.romPx = 0,
    this.velocityTrace = const [],
  });
}

class VelocityCalculator {
  final double pixelsPerMeter;

  const VelocityCalculator({this.pixelsPerMeter = 100});

  VelocityResult calculate(List<BarbellPosition> positions) {
    if (positions.length < 2) {
      return VelocityResult(
        meanVelocity: 0,
        peakVelocity: 0,
        displacement: 0,
        meanVelocityPxPerSec: 0,
        peakVelocityPxPerSec: 0,
        displacementPx: 0,
        frameCount: positions.length,
        durationSec: 0,
      );
    }

    final sorted = List<BarbellPosition>.from(positions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double totalDispPx = 0;
    double maxVelPxPerSec = 0;
    double maxAccelPxPerSecSq = 0;
    double minY = sorted.first.y;
    double maxY = sorted.first.y;
    final velocitiesPxPerSec = <double>[];
    final prevVelocities = <double>[];
    final prevTimes = <DateTime>[];

    for (int i = 0; i < sorted.length - 1; i++) {
      final p1 = sorted[i];
      final p2 = sorted[i + 1];

      final dx = p2.x - p1.x;
      final dy = p2.y - p1.y;
      final dispPx = sqrt(dx * dx + dy * dy);

      final dt = _dtSec(p1.timestamp, p2.timestamp);
      if (dt <= 0) continue;

      totalDispPx += dispPx;
      final velPxPerSec = dispPx / dt;
      velocitiesPxPerSec.add(velPxPerSec);

      if (velPxPerSec > maxVelPxPerSec) maxVelPxPerSec = velPxPerSec;

      if (p2.y < minY) minY = p2.y;
      if (p2.y > maxY) maxY = p2.y;

      if (prevVelocities.isNotEmpty) {
        final prevDt = _dtSec(prevTimes.last, p1.timestamp);
        if (prevDt > 0) {
          final accel = (velPxPerSec - prevVelocities.last).abs() / prevDt;
          if (accel > maxAccelPxPerSecSq) maxAccelPxPerSecSq = accel;
        }
      }
      prevVelocities.add(velPxPerSec);
      prevTimes.add(p1.timestamp);
    }

    if (velocitiesPxPerSec.isEmpty) {
      return VelocityResult(
        meanVelocity: 0,
        peakVelocity: 0,
        displacement: 0,
        meanVelocityPxPerSec: 0,
        peakVelocityPxPerSec: 0,
        displacementPx: 0,
        frameCount: sorted.length,
        durationSec: 0,
      );
    }

    final meanVelPxPerSec =
        velocitiesPxPerSec.reduce((a, b) => a + b) / velocitiesPxPerSec.length;
    final totalDt = _dtSec(sorted.first.timestamp, sorted.last.timestamp);
    final romPx = (maxY - minY).abs();

    return VelocityResult(
      meanVelocity: meanVelPxPerSec / pixelsPerMeter,
      peakVelocity: maxVelPxPerSec / pixelsPerMeter,
      displacement: totalDispPx / pixelsPerMeter,
      meanVelocityPxPerSec: meanVelPxPerSec,
      peakVelocityPxPerSec: maxVelPxPerSec,
      displacementPx: totalDispPx,
      frameCount: sorted.length,
      durationSec: totalDt,
      peakAcceleration: maxAccelPxPerSecSq / pixelsPerMeter,
      rom: romPx / pixelsPerMeter,
      romPx: romPx,
      velocityTrace: velocitiesPxPerSec
          .map((v) => v / pixelsPerMeter)
          .toList(),
    );
  }

  double instantVelocity(BarbellPosition p1, BarbellPosition p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    final dispPx = sqrt(dx * dx + dy * dy);
    final dt = _dtSec(p1.timestamp, p2.timestamp);
    if (dt <= 0) return 0;
    return (dispPx / dt) / pixelsPerMeter;
  }

  double _dtSec(DateTime a, DateTime b) =>
      b.difference(a).inMicroseconds / 1000000.0;
}
