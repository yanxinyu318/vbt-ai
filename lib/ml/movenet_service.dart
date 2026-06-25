import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MoveNetService {
  Interpreter? _interpreter;
  bool _initialized = false;
  TensorType _inputType = TensorType.float32;
  TensorType _outputType = TensorType.float32;

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
    _inputType = _interpreter!.getInputTensor(0).type;
    _outputType = _interpreter!.getOutputTensor(0).type;
    _initialized = true;
  }

  ({double x, double y, double confidence})? detect(
    Uint8List rgbBytes,
    int frameWidth,
    int frameHeight,
  ) {
    if (!_initialized || _interpreter == null) {
      return null;
    }

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape;

      final input = _preprocess(rgbBytes, frameWidth, frameHeight, inputShape, _inputType);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = _allocateOutput(outputShape, _outputType);
      _interpreter!.run(input, output);

      final result = _extractBarbellPosition(output, frameWidth, frameHeight, _outputType);
      return result;
    } catch (e) {
      debugPrint('[MOV] ERROR: $e');
      return null;
    }
  }

  Object _preprocess(
    Uint8List rgbBytes,
    int frameWidth,
    int frameHeight,
    List<int> inputShape,
    TensorType inputType,
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

    if (inputType == TensorType.uint8 || inputType == TensorType.int8) {
      final flat = Uint8List(_inputSize * _inputSize * expectedChannels);
      int idx = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final p = resized.getPixel(x, y);
          flat[idx++] = p.r.toInt();
          if (expectedChannels > 1) flat[idx++] = p.g.toInt();
          if (expectedChannels > 2) flat[idx++] = p.b.toInt();
        }
      }
      return flat.reshape(inputShape);
    }

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

  Object _allocateOutput(List<int> shape, TensorType outputType) {
    final size = shape.fold(1, (a, b) => a * b);
    if (outputType == TensorType.uint8 || outputType == TensorType.int8) {
      return Uint8List(size).reshape(shape);
    }
    return Float32List(size).reshape(shape);
  }

  ({double x, double y, double confidence})? _extractBarbellPosition(
    Object output,
    int frameWidth,
    int frameHeight,
    TensorType outputType,
  ) {
    final batch = (output as List)[0] as List;
    final person = batch[0] as List;

    double toDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return 0.0;
    }

    final lWrist = (toDouble(person[leftWristIdx][1]), toDouble(person[leftWristIdx][0]), toDouble(person[leftWristIdx][2]));
    final rWrist = (toDouble(person[rightWristIdx][1]), toDouble(person[rightWristIdx][0]), toDouble(person[rightWristIdx][2]));

    final lConf = lWrist.$3;
    final rConf = rWrist.$3;

    double x, y, confidence;

    if (lConf > 0.4 && rConf > 0.4) {
      x = (lWrist.$1 + rWrist.$1) / 2.0;
      y = (lWrist.$2 + rWrist.$2) / 2.0;
      confidence = (lConf + rConf) / 2.0;
    } else if (lConf > rConf && lConf > 0.4) {
      x = lWrist.$1;
      y = lWrist.$2;
      confidence = lConf;
    } else if (rConf > 0.4) {
      x = rWrist.$1;
      y = rWrist.$2;
      confidence = rConf;
    } else {
      return null;
    }

    return (
      x: x,
      y: y,
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
      final input = _preprocess(rgbBytes, frameWidth, frameHeight, inputShape, _inputType);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = _allocateOutput(outputShape, _outputType);
      _interpreter!.run(input, output);

      final result = _extractBarbellPosition(output, frameWidth, frameHeight, _outputType);
      if (result == null) return null;
      return [result.x, result.y, result.confidence, result.x, result.y, result.confidence];
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
