
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/ml/movenet_service.dart';
import 'package:vbt/services/color_detector.dart';
import 'package:vbt/services/processed_frame.dart';

class BarbellDetector {
  final MoveNetService _movenet;
  final ColorDetector _colorDetector;
  final double _movenetThreshold;

  BarbellDetector({
    MoveNetService? movenet,
    ColorDetector? colorDetector,
    double movenetThreshold = 0.1,
  })  : _movenet = movenet ?? MoveNetService(),
        _colorDetector = colorDetector ?? ColorDetector(),
        _movenetThreshold = movenetThreshold;

  MoveNetService get movenet => _movenet;

  BarbellPosition? detect(ProcessedFrame frame) {
    final result = _movenet.detect(
      frame.rgbBytes,
      frame.width,
      frame.height,
    );

    if (result != null && result.confidence >= _movenetThreshold) {
      return BarbellPosition(
        x: result.x,
        y: result.y,
        confidence: result.confidence,
        timestamp: frame.timestamp,
      );
    }

    final fallback = _colorDetector.detect(frame);
    if (fallback != null && fallback.confidence >= 0.05) {
      return BarbellPosition(
        x: fallback.x,
        y: fallback.y,
        confidence: fallback.confidence * 0.5,
        timestamp: frame.timestamp,
      );
    }

    return null;
  }
}
