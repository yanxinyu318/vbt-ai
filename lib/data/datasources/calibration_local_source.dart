import 'package:shared_preferences/shared_preferences.dart';
import 'package:vbt/domain/entities/calibration.dart';

class CalibrationLocalSource {
  static const _keyPixelsPerMeter = 'calibration_pixels_per_meter';
  static const _keyTimestamp = 'calibration_timestamp';

  Future<Calibration?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ppm = prefs.getDouble(_keyPixelsPerMeter);
    final ts = prefs.getString(_keyTimestamp);
    if (ppm == null || ppm <= 0 || ts == null) return null;
    return Calibration(
      pixelsPerMeter: ppm,
      calibratedAt: DateTime.parse(ts),
    );
  }

  Future<void> save(Calibration calibration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPixelsPerMeter, calibration.pixelsPerMeter);
    await prefs.setString(_keyTimestamp, calibration.calibratedAt.toIso8601String());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPixelsPerMeter);
    await prefs.remove(_keyTimestamp);
  }
}
