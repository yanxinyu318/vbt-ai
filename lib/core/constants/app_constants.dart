class AppConstants {
  AppConstants._();

  static const String appName = '杠铃速度追踪';
  static const double targetFps = 60.0;
  static const double minFps = 30.0;
  static const double standardBarbellLengthCm = 220.0;
  static const double standardPlateDiameterCm = 45.0;

  static const double movenetConfidenceThreshold = 0.3;
  static const double colorDetectorConfidenceThreshold = 0.15;
  static const int movenetInputSize = 192;
  static const String movenetModelPath = 'assets/tflite/movenet_lightning.tflite';
}
