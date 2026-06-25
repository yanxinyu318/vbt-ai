import 'package:vbt/domain/entities/calibration.dart';

abstract class CalibrationRepository {
  Future<Calibration?> getCalibration();
  Future<void> saveCalibration(Calibration calibration);
}
