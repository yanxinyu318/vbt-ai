import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MoveNetService {
  Interpreter? _interpreter;
  bool _initialized = false;

  static const int _inputSize = 192;

  static const int leftWristIdx = 9;
  static const int rightWristIdx = 10;

  bool get isReady => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final options = InterpreterOptions()..threads = 4;
    _interpreter = await Interpreter.fromAsset(
      'assets/tflite/movenet_lightning.tflite',
      options: options,
    );
    _initialized = true;
  }

  ({double x, double y, double confidence})? detect(
    Uint8List rgbBytes,
    int frameWidth,
    int frameHeight,
  ) {
    if (!_initialized || _interpreter == null) return null;

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;

      final input = _preprocess(rgbBytes, frameWidth, frameHeight, inputShape);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = _allocateOutput(outputShape);
      _interpreter!.run(input, output);

      return _extractBarbellPosition(output, frameWidth, frameHeight);
    } catch (_) {
      return null;
    }
  }

  Object _preprocess(
    Uint8List rgbBytes,
    int frameWidth,
    int frameHeight,
    List<int> inputShape,
  ) {
    final srcImage = img.Image.fromBytes(
      width: frameWidth,
      height: frameHeight,
      bytes: rgbBytes.buffer,
      numChannels: 3,
      order: img.ChannelOrder.rgb,
    );

    final resized = img.copyResize(srcImage,
        width: _inputSize, height: _inputSize,
        interpolation: img.Interpolation.linear);

    final expectedChannels = inputShape.length == 4 ? inputShape[3] : 3;

    final flat = Float32List(_inputSize * _inputSize * expectedChannels);
    int idx = 0;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final p = resized.getPixel(x, y);
        flat[idx++] = (p.r / 127.5) - 1.0;
        if (expectedChannels > 1) flat[idx++] = (p.g / 127.5) - 1.0;
        if (expectedChannels > 2) flat[idx++] = (p.b / 127.5) - 1.0;
      }
    }

    return flat.reshape(inputShape);
  }

  Object _allocateOutput(List<int> shape) {
    final size = shape.fold(1, (a, b) => a * b);
    return Float64List(size).reshape(shape);
  }

  ({double x, double y, double confidence})? _extractBarbellPosition(
    Object output,
    int frameWidth,
    int frameHeight,
  ) {
    final outputList = output as List<List<List<List<double>>>>;
    final keypoints = outputList[0][0];

    final lWrist = (keypoints[leftWristIdx][1], keypoints[leftWristIdx][0], keypoints[leftWristIdx][2]);
    final rWrist = (keypoints[rightWristIdx][1], keypoints[rightWristIdx][0], keypoints[rightWristIdx][2]);

    final lConf = lWrist.$3;
    final rConf = rWrist.$3;

    double x, y, confidence;

    if (lConf > 0.3 && rConf > 0.3) {
      x = (lWrist.$1 + rWrist.$1) / 2.0;
      y = (lWrist.$2 + rWrist.$2) / 2.0;
      confidence = (lConf + rConf) / 2.0;
    } else if (lConf > rConf) {
      x = lWrist.$1;
      y = lWrist.$2;
      confidence = lConf;
    } else if (rConf > 0.3) {
      x = rWrist.$1;
      y = rWrist.$2;
      confidence = rConf;
    } else {
      return null;
    }

    return (
      x: x * frameWidth,
      y: y * frameHeight,
      confidence: confidence,
    );
  }

  List<double>? getWristKeypoints(
    Uint8List rgbBytes,
    int frameWidth,
    int frameHeight,
  ) {
    if (!_initialized || _interpreter == null) return null;

    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final input = _preprocess(rgbBytes, frameWidth, frameHeight, inputShape);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = _allocateOutput(outputShape);
      _interpreter!.run(input, output);

      final outputList = output as List<List<List<List<double>>>>;
      final keypoints = outputList[0][0];

      return [
        keypoints[leftWristIdx][1] * frameWidth,
        keypoints[leftWristIdx][0] * frameHeight,
        keypoints[leftWristIdx][2],
        keypoints[rightWristIdx][1] * frameWidth,
        keypoints[rightWristIdx][0] * frameHeight,
        keypoints[rightWristIdx][2],
      ];
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _initialized = false;
  }
}
