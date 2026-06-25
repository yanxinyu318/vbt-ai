import 'package:vbt/data/datasources/calibration_local_source.dart';
import 'package:vbt/domain/entities/calibration.dart';
import 'package:vbt/domain/repositories/calibration_repository.dart';

class CalibrationRepositoryImpl implements CalibrationRepository {
  final CalibrationLocalSource _localSource;

  CalibrationRepositoryImpl({CalibrationLocalSource? localSource})
      : _localSource = localSource ?? CalibrationLocalSource();

  @override
  Future<Calibration?> getCalibration() => _localSource.load();

  @override
  Future<void> saveCalibration(Calibration calibration) =>
      _localSource.save(calibration);
}
