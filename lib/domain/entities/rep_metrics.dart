class RepMetrics {
  final int repNumber;
  final double meanVelocity;
  final double peakVelocity;
  final double displacement;
  final double power;
  final double estimatedOneRm;
  final double peakAcceleration;
  final double rom;
  final int concentricTimeMs;
  final int eccentricTimeMs;
  final int totalRepTimeMs;
  final List<double> velocityTrace;

  const RepMetrics({
    required this.repNumber,
    required this.meanVelocity,
    required this.peakVelocity,
    required this.displacement,
    required this.power,
    required this.estimatedOneRm,
    this.peakAcceleration = 0,
    this.rom = 0,
    this.concentricTimeMs = 0,
    this.eccentricTimeMs = 0,
    this.totalRepTimeMs = 0,
    this.velocityTrace = const [],
  });
}
