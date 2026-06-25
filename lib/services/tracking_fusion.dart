import 'package:flutter/foundation.dart';
import 'package:vbt/domain/entities/barbell_position.dart';
import 'package:vbt/ml/movenet_service.dart';
import 'package:vbt/services/optical_flow_service.dart';
import 'package:vbt/services/processed_frame.dart';

class TrackingFusion {
  final OpticalFlowService _opticalFlow;
  final MoveNetService _movenet;
  final double _movenetThreshold;
  final double _maxDeviation;
  bool _movenetReady = false;

  TrackingFusion({
    OpticalFlowService? opticalFlow,
    MoveNetService? movenet,
    double movenetThreshold = 0.4,
    double maxDeviation = 0.15,
  })  : _opticalFlow = opticalFlow ?? OpticalFlowService(),
        _movenet = movenet ?? MoveNetService(),
        _movenetThreshold = movenetThreshold,
        _maxDeviation = maxDeviation;

  OpticalFlowService get opticalFlow => _opticalFlow;
  MoveNetService get movenet => _movenet;

  Future<void> initializeMovenet() async {
    await _movenet.initialize();
    _movenetReady = true;
  }

  void initialize(double initX, double initY) {
    _opticalFlow.initialize(initX, initY);
  }

  void reset() {
    _opticalFlow.reset();
  }

  BarbellPosition? process(ProcessedFrame frame) {
    BarbellPosition? movenetResult;
    if (_movenetReady) {
      final raw = _movenet.detect(
        frame.rgbBytes,
        frame.width,
        frame.height,
      );
      if (raw != null && raw.confidence >= _movenetThreshold) {
        movenetResult = BarbellPosition(
          x: raw.y,
          y: 1.0 - raw.x,
          confidence: raw.confidence,
          timestamp: frame.timestamp,
        );
      }
    }

    final ofResult = _opticalFlow.process(frame);

    if (ofResult != null) {
      if (movenetResult != null) {
        final dx = ofResult.centroidX - movenetResult.x;
        final dy = ofResult.centroidY - movenetResult.y;
        final devSq = dx * dx + dy * dy;
        final maxSq = _maxDeviation * _maxDeviation;

        if (devSq > maxSq) {
          debugPrint('[FUSE] OF=(${ofResult.centroidX.toStringAsFixed(3)},${ofResult.centroidY.toStringAsFixed(3)}) '
              'MN=(${movenetResult.x.toStringAsFixed(3)},${movenetResult.y.toStringAsFixed(3)}) '
              'dev=${devSq.toStringAsFixed(4)} > ${maxSq.toStringAsFixed(4)} REJECT');
        } else {
          debugPrint('[FUSE] OF=(${ofResult.centroidX.toStringAsFixed(3)},${ofResult.centroidY.toStringAsFixed(3)}) '
              'MN=(${movenetResult.x.toStringAsFixed(3)},${movenetResult.y.toStringAsFixed(3)}) '
              'dev=${devSq.toStringAsFixed(4)} OK');
        }
      } else {
        debugPrint('[FUSE] OF=(${ofResult.centroidX.toStringAsFixed(3)},${ofResult.centroidY.toStringAsFixed(3)}) '
            'v=${ofResult.validVectors}/${ofResult.totalBlocks} no-MN');
      }

      return BarbellPosition(
        x: ofResult.centroidX,
        y: ofResult.centroidY,
        confidence: ofResult.confidence,
        timestamp: frame.timestamp,
      );
    }

    if (movenetResult != null) {
      debugPrint('[FUSE] MN-only=(${movenetResult.x.toStringAsFixed(3)},${movenetResult.y.toStringAsFixed(3)})');
      return movenetResult;
    }

    return null;
  }
}
