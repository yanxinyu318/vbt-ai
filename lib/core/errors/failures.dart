sealed class Failure {
  final String message;
  const Failure(this.message);
}

class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

class DetectionFailure extends Failure {
  const DetectionFailure(super.message);
}

class CalibrationFailure extends Failure {
  const CalibrationFailure(super.message);
}

class ModelLoadFailure extends Failure {
  const ModelLoadFailure(super.message);
}
