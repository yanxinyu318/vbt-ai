class KalmanFilter1D {
  double pos;
  double vel;
  double p00;
  double p01;
  double p10;
  double p11;
  bool _initialized = false;

  final double qPos;
  final double qVel;
  final double r;

  KalmanFilter1D({
    this.qPos = 1e-3,
    this.qVel = 1e-2,
    this.r = 5e-1,
  })  : pos = 0,
        vel = 0,
        p00 = 10,
        p01 = 0,
        p10 = 0,
        p11 = 10;

  void init(double position, double velocity) {
    pos = position;
    vel = velocity;
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  void predict(double dt) {
    if (dt <= 0) return;

    final dt2 = dt * dt;

    final p00n = p00 + dt * (p01 + p10) + dt2 * p11 + qPos;
    final p01n = p01 + dt * p11;
    final p10n = p10 + dt * p11;
    final p11n = p11 + qVel;

    pos = pos + vel * dt;
    p00 = p00n;
    p01 = p01n;
    p10 = p10n;
    p11 = p11n;
  }

  double update(double measurement) {
    final denom = p00 + r;
    if (denom == 0) return measurement;

    final k0 = p00 / denom;
    final k1 = p10 / denom;
    final innov = measurement - pos;

    pos = pos + k0 * innov;
    vel = vel + k1 * innov;

    final p00n = (1 - k0) * p00;
    final p01n = (1 - k0) * p01;
    final p10n = p10 - k1 * p00;
    final p11n = p11 - k1 * p01;

    p00 = p00n;
    p01 = p01n;
    p10 = p10n;
    p11 = p11n;

    return pos;
  }

  double predictUpdate(double measurement, double dt) {
    if (!_initialized) {
      init(measurement, 0);
      return measurement;
    }
    predict(dt);
    return update(measurement);
  }
}

class KalmanFilter2D {
  final KalmanFilter1D _x;
  final KalmanFilter1D _y;

  KalmanFilter2D({
    double qPos = 1e-3,
    double qVel = 1e-2,
    double r = 5e-1,
  })  : _x = KalmanFilter1D(qPos: qPos, qVel: qVel, r: r),
        _y = KalmanFilter1D(qPos: qPos, qVel: qVel, r: r);

  bool get isInitialized => _x.isInitialized && _y.isInitialized;

  void init(double x, double y, double vx, double vy) {
    _x.init(x, vx);
    _y.init(y, vy);
  }

  ({double x, double y}) filter(double mx, double my, double dt) {
    final sx = _x.predictUpdate(mx, dt);
    final sy = _y.predictUpdate(my, dt);
    return (x: sx, y: sy);
  }

  double get posX => _x.pos;
  double get posY => _y.pos;
  double get velX => _x.vel;
  double get velY => _y.vel;
  double get velocity => _speed(velX, velY);

  void reset() {
    _x..pos = 0
      ..vel = 0
      ..p00 = 10
      ..p01 = 0
      ..p10 = 0
      ..p11 = 10;
    _y..pos = 0
      ..vel = 0
      ..p00 = 10
      ..p01 = 0
      ..p10 = 0
      ..p11 = 10;
  }

  double _speed(double vx, double vy) => sqrt(vx * vx + vy * vy);
}

double sqrt(double v) {
  if (v <= 0) return 0;
  double x = v;
  double y = 1;
  const e = 1e-10;
  while (x - y > e) {
    x = (x + y) / 2;
    y = v / x;
  }
  return x;
}
