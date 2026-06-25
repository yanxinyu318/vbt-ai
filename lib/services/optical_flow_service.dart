import 'dart:math';
import 'dart:typed_data';
import 'package:vbt/services/processed_frame.dart';

class OpticalFlowResult {
  final double centroidX;
  final double centroidY;
  final double confidence;
  final int validVectors;
  final int totalBlocks;

  const OpticalFlowResult({
    required this.centroidX,
    required this.centroidY,
    required this.confidence,
    required this.validVectors,
    required this.totalBlocks,
  });
}

class OpticalFlowService {
  static const int _blockSize = 16;
  static const int _searchWindow = 20;
  static const double _maxSsd = 3000.0;
  static const double _outlierSigma = 2.0;

  Uint8List? _prevGray;
  int _prevWidth = 0;
  int _prevHeight = 0;

  double _centroidX = 0;
  double _centroidY = 0;
  bool _initialized = false;

  void initialize(double initCentroidX, double initCentroidY) {
    _centroidX = initCentroidX;
    _centroidY = initCentroidY;
    _initialized = true;
    _prevGray = null;
  }

  void reset() {
    _prevGray = null;
    _initialized = false;
  }

  bool get isInitialized => _initialized;

  double get centroidX => _centroidX;
  double get centroidY => _centroidY;

  OpticalFlowResult? process(ProcessedFrame frame, {
    double? roiX,
    double? roiY,
    double? roiW,
    double? roiH,
  }) {
    if (!_initialized) return null;

    final gray = _toGrayscale(frame.rgbBytes, frame.width, frame.height);

    final int roiLeft, roiTop, roiRight, roiBottom;
    if (roiX != null && roiY != null && roiW != null && roiH != null) {
      roiLeft = max(0, roiX.toInt());
      roiTop = max(0, roiY.toInt());
      roiRight = min(frame.width, (roiX + roiW).toInt());
      roiBottom = min(frame.height, (roiY + roiH).toInt());
    } else {
      final pad = _blockSize * 4;
      roiLeft = max(0, (_centroidX - pad * 3).toInt());
      roiTop = max(0, (_centroidY - pad * 2).toInt());
      roiRight = min(frame.width, (_centroidX + pad * 3).toInt());
      roiBottom = min(frame.height, (_centroidY + pad * 2).toInt());
    }

    if (roiRight - roiLeft < _blockSize * 2 ||
        roiBottom - roiTop < _blockSize * 2) {
      _prevGray = gray;
      _prevWidth = frame.width;
      _prevHeight = frame.height;
      return null;
    }

    if (_prevGray != null &&
        _prevWidth == frame.width &&
        _prevHeight == frame.height) {
      final motions = <_MotionVector>[];

      for (int by = roiTop; by + _blockSize <= roiBottom; by += _blockSize) {
        for (int bx = roiLeft; bx + _blockSize <= roiRight; bx += _blockSize) {
          final mv = _matchBlock(
            _prevGray!, gray, bx, by,
            frame.width, frame.height,
          );
          if (mv != null) {
            motions.add(mv);
          }
        }
      }

      if (motions.length < 3) {
        _prevGray = gray;
        _prevWidth = frame.width;
        _prevHeight = frame.height;
        return null;
      }

      final filtered = _rejectOutliers(motions);
      if (filtered.isEmpty) {
        _prevGray = gray;
        _prevWidth = frame.width;
        _prevHeight = frame.height;
        return null;
      }

      double sumDx = 0, sumDy = 0, sumWeight = 0;
      for (final mv in filtered) {
        final w = 1.0 / (mv.ssd + 1.0);
        sumDx += mv.dx * w;
        sumDy += mv.dy * w;
        sumWeight += w;
      }

      final avgDx = sumDx / sumWeight;
      final avgDy = sumDy / sumWeight;

      _centroidX += avgDx;
      _centroidY += avgDy;

      _centroidX = _centroidX.clamp(
        max(0, roiLeft - _blockSize * 2).toDouble(),
        min(frame.width.toDouble(), (roiRight + _blockSize * 2).toDouble()),
      );
      _centroidY = _centroidY.clamp(
        max(0, roiTop - _blockSize * 2).toDouble(),
        min(frame.height.toDouble(), (roiBottom + _blockSize * 2).toDouble()),
      );

      final confidence = filtered.length / max(1, motions.length);

      _prevGray = gray;
      _prevWidth = frame.width;
      _prevHeight = frame.height;

      return OpticalFlowResult(
        centroidX: _centroidX,
        centroidY: _centroidY,
        confidence: confidence,
        validVectors: filtered.length,
        totalBlocks: motions.length,
      );
    }

    _prevGray = gray;
    _prevWidth = frame.width;
    _prevHeight = frame.height;
    return null;
  }

  _MotionVector? _matchBlock(
    Uint8List prev, Uint8List curr,
    int bx, int by,
    int width, int height,
  ) {
    int sumRef = 0;
    int count = 0;
    for (int dy = 0; dy < _blockSize; dy++) {
      for (int dx = 0; dx < _blockSize; dx++) {
        sumRef += prev[((by + dy) * width + (bx + dx)) & 0x7FFFFFFF];
        count++;
      }
    }
    final meanRef = sumRef / count;

    int ssdSumRef = 0;
    for (int dy = 0; dy < _blockSize; dy++) {
      for (int dx = 0; dx < _blockSize; dx++) {
        final v = prev[((by + dy) * width + (bx + dx)) & 0x7FFFFFFF] - meanRef;
        ssdSumRef += (v * v).toInt();
      }
    }
    if (ssdSumRef == 0) return null;

    double bestSsd = double.infinity;
    int bestDx = 0, bestDy = 0;

    final searchL = max(0, bx - _searchWindow);
    final searchT = max(0, by - _searchWindow);
    final searchR = min(width - _blockSize, bx + _searchWindow);
    final searchB = min(height - _blockSize, by + _searchWindow);

    for (int sy = searchT; sy <= searchB; sy += 2) {
      for (int sx = searchL; sx <= searchR; sx += 2) {
        int sumCur = 0;
        for (int dy = 0; dy < _blockSize; dy++) {
          for (int dx = 0; dx < _blockSize; dx++) {
            sumCur += curr[((sy + dy) * width + (sx + dx)) & 0x7FFFFFFF];
          }
        }
        final meanCur = sumCur / count;

        int ssd = 0;
        for (int dy = 0; dy < _blockSize; dy++) {
          for (int dx = 0; dx < _blockSize; dx++) {
            final refV = prev[((by + dy) * width + (bx + dx)) & 0x7FFFFFFF] - meanRef;
            final curV = curr[((sy + dy) * width + (sx + dx)) & 0x7FFFFFFF] - meanCur;
            final d = refV - curV;
            ssd += (d * d).toInt();
          }
        }

        if (ssd < bestSsd) {
          bestSsd = ssd.toDouble();
          bestDx = sx - bx;
          bestDy = sy - by;
        }
      }
    }

    if (bestSsd > _maxSsd) return null;

    return _MotionVector(
      dx: bestDx.toDouble(),
      dy: bestDy.toDouble(),
      ssd: bestSsd,
    );
  }

  List<_MotionVector> _rejectOutliers(List<_MotionVector> vectors) {
    if (vectors.length < 4) return vectors;

    double meanDx = 0, meanDy = 0;
    for (final v in vectors) {
      meanDx += v.dx;
      meanDy += v.dy;
    }
    meanDx /= vectors.length;
    meanDy /= vectors.length;

    double varDx = 0, varDy = 0;
    for (final v in vectors) {
      varDx += (v.dx - meanDx) * (v.dx - meanDx);
      varDy += (v.dy - meanDy) * (v.dy - meanDy);
    }
    varDx /= vectors.length;
    varDy /= vectors.length;

    final stdDx = sqrt(varDx);
    final stdDy = sqrt(varDy);
    final threshold = _outlierSigma * max(stdDx, stdDy);

    return vectors.where((v) {
      return (v.dx - meanDx).abs() <= threshold &&
          (v.dy - meanDy).abs() <= threshold;
    }).toList();
  }

  Uint8List _toGrayscale(Uint8List rgb, int width, int height) {
    final gray = Uint8List(width * height);
    for (int i = 0; i < width * height; i++) {
      final idx = i * 3;
      gray[i] = (0.299 * rgb[idx] + 0.587 * rgb[idx + 1] + 0.114 * rgb[idx + 2]).toInt();
    }
    return gray;
  }
}

class _MotionVector {
  final double dx;
  final double dy;
  final double ssd;

  const _MotionVector({
    required this.dx,
    required this.dy,
    required this.ssd,
  });
}
