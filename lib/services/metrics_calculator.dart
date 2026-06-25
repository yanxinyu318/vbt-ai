import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/domain/entities/rep_metrics.dart';
import 'package:vbt/services/velocity_calculator.dart';

class MetricsCalculator {
  final double pixelsPerMeter;
  final double gravity;

  const MetricsCalculator({
    this.pixelsPerMeter = 100,
    this.gravity = 9.81,
  });

  RepMetrics calculateRep(
    List<BarbellPosition> positions,
    int repNumber, {
    double weightKg = 0,
    double? pixelsPerMeterOverride,
    int concentricTimeMs = 0,
    int eccentricTimeMs = 0,
    int totalRepTimeMs = 0,
  }) {
    final ppm = pixelsPerMeterOverride ?? pixelsPerMeter;
    final calc = VelocityCalculator(pixelsPerMeter: ppm);
    final result = calc.calculate(positions);

    final power = weightKg > 0 ? result.meanVelocity * weightKg * gravity : 0.0;

    final estimatedOneRm = estimate1Rm(weightKg, repNumber, result.meanVelocity);

    return RepMetrics(
      repNumber: repNumber,
      meanVelocity: result.meanVelocity,
      peakVelocity: result.peakVelocity,
      displacement: result.displacement,
      power: power,
      estimatedOneRm: estimatedOneRm,
      peakAcceleration: result.peakAcceleration,
      rom: result.rom,
      concentricTimeMs: concentricTimeMs,
      eccentricTimeMs: eccentricTimeMs,
      totalRepTimeMs: totalRepTimeMs,
      velocityTrace: result.velocityTrace,
    );
  }

  double estimate1Rm(double weightKg, int reps, double meanVelocity) {
    final epley = estimate1RmEpley(weightKg, reps);
    final velocityBased = estimate1RmVelocity(meanVelocity, weightKg);

    if (weightKg <= 0) return velocityBased;
    if (meanVelocity <= 0) return epley;

    return (epley + velocityBased) / 2;
  }

  double estimate1RmEpley(double weightKg, int reps) {
    if (reps <= 0 || weightKg <= 0) return 0;
    return weightKg * (1 + reps / 30);
  }

  double estimate1RmVelocity(double meanVelocity, double weightKg) {
    if (meanVelocity <= 0) return weightKg;

    final v1Rm = _velocityAt1Rm();
    if (meanVelocity >= v1Rm) return weightKg;

    final estimatedWeight = weightKg * (v1Rm / meanVelocity);

    return estimatedWeight.clamp(weightKg, weightKg * 3);
  }

  double _velocityAt1Rm() {
    return 0.20;
  }

  double calculatePower(double velocity, double massKg) {
    if (massKg <= 0 || velocity <= 0) return 0;
    return massKg * gravity * velocity;
  }
}
