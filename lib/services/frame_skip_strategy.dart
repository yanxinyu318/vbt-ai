import 'dart:collection';

enum PerformanceMode { batterySaver, balanced, performance }

class FrameSkipStrategy {
  PerformanceMode mode;
  final Queue<double> _recentMs;
  final int _historySize;
  double _lastFrameMs = 0;
  int _framesSkipped = 0;
  FrameSkipStrategy({
    this.mode = PerformanceMode.balanced,
    int historySize = 30,
  })  : _recentMs = Queue<double>(),
        _historySize = historySize;

  void updateMode(PerformanceMode newMode) {
    mode = newMode;
    reset();
  }

  int get targetFps {
    return switch (mode) {
      PerformanceMode.batterySaver => 15,
      PerformanceMode.balanced => 30,
      PerformanceMode.performance => 60,
    };
  }

  double get _minIntervalMs => 1000.0 / targetFps;

  bool shouldProcess() {
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();
    if (_lastFrameMs == 0) {
      _lastFrameMs = now;
      return true;
    }
    final elapsed = now - _lastFrameMs;

    final skipCount = _adaptiveSkipCount();
    if (skipCount > 0 && _framesSkipped < skipCount) {
      _framesSkipped++;
      return false;
    }

    if (elapsed < _minIntervalMs) {
      _framesSkipped++;
      return false;
    }

    _framesSkipped = 0;
    _lastFrameMs = now;
    return true;
  }

  int _adaptiveSkipCount() {
    if (_recentMs.isEmpty) return 0;
    final avg = _recentMs.reduce((a, b) => a + b) / _recentMs.length;
    if (avg > _minIntervalMs * 2) return 3;
    if (avg > _minIntervalMs * 1.5) return 2;
    if (avg > _minIntervalMs * 1.1) return 1;
    return 0;
  }

  void recordProcessingTime(Duration duration) {
    _recentMs.addLast(duration.inMicroseconds / 1000.0);
    while (_recentMs.length > _historySize) {
      _recentMs.removeFirst();
    }
  }

  void reset() {
    _recentMs.clear();
    _lastFrameMs = 0;
    _framesSkipped = 0;
  }
}
