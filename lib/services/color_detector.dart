import 'dart:typed_data';
import 'package:vbt/services/processed_frame.dart';

class ColorDetectorResult {
  final double x;
  final double y;
  final double confidence;

  const ColorDetectorResult({
    required this.x,
    required this.y,
    required this.confidence,
  });
}

class ColorDetectorConfig {
  final double hueLow;
  final double hueHigh;
  final double satMin;
  final double valMin;
  final double valMax;

  const ColorDetectorConfig({
    required this.hueLow,
    required this.hueHigh,
    this.satMin = 0.3,
    this.valMin = 0.2,
    this.valMax = 0.9,
  });
}

class ColorDetector {
  final List<ColorDetectorConfig> _plateColors;

  ColorDetector()
      : _plateColors = [
          const ColorDetectorConfig(hueLow: 0.95, hueHigh: 1.0, satMin: 0.5, valMin: 0.3),
          const ColorDetectorConfig(hueLow: 0.0, hueHigh: 0.05, satMin: 0.5, valMin: 0.3),
          const ColorDetectorConfig(hueLow: 0.55, hueHigh: 0.7, satMin: 0.4, valMin: 0.3),
          const ColorDetectorConfig(hueLow: 0.13, hueHigh: 0.2, satMin: 0.4, valMin: 0.3),
          const ColorDetectorConfig(hueLow: 0.25, hueHigh: 0.4, satMin: 0.3, valMin: 0.3),
          const ColorDetectorConfig(hueLow: 0.0, hueHigh: 1.0, satMin: 0.0, valMin: 0.0, valMax: 0.15),
        ];

  ColorDetectorResult? detect(ProcessedFrame frame) {
    return detectFromBytes(frame.rgbBytes, frame.width, frame.height);
  }

  ColorDetectorResult? detectFromBytes(
    Uint8List rgbBytes,
    int width,
    int height,
  ) {
    final halfW = width ~/ 2;
    final halfH = height ~/ 2;
    double sumX = 0, sumY = 0;
    int count = 0;

    for (int y = 0; y < height; y += 3) {
      for (int x = 0; x < width; x += 3) {
        final idx = (y * width + x) * 3;
        final r = rgbBytes[idx] / 255.0;
        final g = rgbBytes[idx + 1] / 255.0;
        final b = rgbBytes[idx + 2] / 255.0;

        final (h, s, v) = _rgbToHsv(r, g, b);

        for (final config in _plateColors) {
          final hueOk = (config.hueLow <= config.hueHigh)
              ? (h >= config.hueLow && h <= config.hueHigh)
              : (h >= config.hueLow || h <= config.hueHigh);

          if (hueOk &&
              s >= config.satMin &&
              v >= config.valMin &&
              v <= config.valMax) {
            sumX += x;
            sumY += y;
            count++;
            break;
          }
        }
      }
    }

    if (count < 20) return null;

    final cx = sumX / count;
    final cy = sumY / count;
    final spread = count / ((halfW ~/ 3) * (halfH ~/ 3));
    final confidence = (spread).clamp(0.0, 1.0);

    return ColorDetectorResult(
      x: cx,
      y: cy,
      confidence: confidence,
    );
  }

  (double h, double s, double v) _rgbToHsv(double r, double g, double b) {
    final max = _max3(r, g, b);
    final min = _min3(r, g, b);
    final delta = max - min;

    final v = max;

    if (delta < 1e-8) return (0.0, 0.0, v);

    final s = delta / max;

    double h;
    if (max == r) {
      h = ((g - b) / delta) % 6.0;
    } else if (max == g) {
      h = ((b - r) / delta) + 2.0;
    } else {
      h = ((r - g) / delta) + 4.0;
    }

    h = (h / 6.0).clamp(0.0, 1.0);
    if (h < 0) h += 1.0;

    return (h, s, v);
  }

  double _max3(double a, double b, double c) => (a >= b)
      ? (a >= c ? a : c)
      : (b >= c ? b : c);

  double _min3(double a, double b, double c) => (a <= b)
      ? (a <= c ? a : c)
      : (b <= c ? b : c);
}
