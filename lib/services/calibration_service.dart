import 'package:vbt/core/constants/app_constants.dart';
import 'package:vbt/data/repositories/calibration_repository_impl.dart';
import 'package:vbt/domain/entities/calibration.dart';
import 'package:vbt/domain/repositories/calibration_repository.dart';

class CalibrationService {
  final CalibrationRepository _repository;
  Calibration? _cached;

  CalibrationService({CalibrationRepository? repository})
      : _repository = repository ?? CalibrationRepositoryImpl();

  Calibration? get current => _cached;

  Future<Calibration?> load() async {
    _cached = await _repository.getCalibration();
    return _cached;
  }

  Future<void> save(Calibration calibration) async {
    _cached = calibration;
    await _repository.saveCalibration(calibration);
  }

  double calcPixelsPerMeter(double pixelDistance, CalibrationMethod method) {
    switch (method) {
      case CalibrationMethod.plateDiameter:
        return pixelDistance / (AppConstants.standardPlateDiameterCm / 100);
      case CalibrationMethod.barbellLength:
        return pixelDistance / (AppConstants.standardBarbellLengthCm / 100);
    }
  }

  bool get isCalibrated => _cached != null && _cached!.pixelsPerMeter > 0;

  Future<void> clear() async {
    _cached = null;
  }

  bool validateCalibration(double pixelsPerMeter) {
    return pixelsPerMeter > 10 && pixelsPerMeter < 5000;
  }
}

enum CalibrationMethod { plateDiameter, barbellLength }
