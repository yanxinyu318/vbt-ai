import 'package:flutter/foundation.dart';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/ml/movenet_service.dart';
import 'package:vbt/services/processed_frame.dart';

class BarbellDetector {
  final MoveNetService _movenet;
  final double _movenetThreshold;

  BarbellDetector({
    MoveNetService? movenet,
    double movenetThreshold = 0.4,
  })  : _movenet = movenet ?? MoveNetService(),
        _movenetThreshold = movenetThreshold;

  MoveNetService get movenet => _movenet;

  void setReference(double normX, double normY) {
    debugPrint('[DET] ref set to (${normX.toStringAsFixed(3)}, ${normY.toStringAsFixed(3)})');
  }

  void clearReference() {}

  BarbellPosition? detect(ProcessedFrame frame) {
    final result = _movenet.detect(
      frame.rgbBytes,
      frame.width,
      frame.height,
    );

    if (result == null || result.confidence < _movenetThreshold) return null;

    final portraitX = result.y;
    final portraitY = 1.0 - result.x;

    debugPrint('[DET] norm=(${portraitX.toStringAsFixed(3)}, ${portraitY.toStringAsFixed(3)}) c=${result.confidence.toStringAsFixed(2)}');

    return BarbellPosition(
      x: portraitX,
      y: portraitY,
      confidence: result.confidence,
      timestamp: frame.timestamp,
    );
  }
}
