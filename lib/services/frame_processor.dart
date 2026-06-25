import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'processed_frame.dart';

class _FrameMessage {
  final Uint8List yBytes;
  final Uint8List uBytes;
  final Uint8List vBytes;
  final int width;
  final int height;
  final int yRow;
  final int uRow;
  final int vRow;
  final int yPs;
  final int uPs;
  final int vPs;
  final int planeCount;
  final DateTime timestamp;

  _FrameMessage({
    required this.yBytes,
    required this.uBytes,
    required this.vBytes,
    required this.width,
    required this.height,
    required this.yRow,
    required this.uRow,
    required this.vRow,
    required this.yPs,
    required this.uPs,
    required this.vPs,
    required this.planeCount,
    required this.timestamp,
  });

  factory _FrameMessage.fromCameraImage(CameraImage image, DateTime timestamp) {
    return _FrameMessage(
      yBytes: image.planes[0].bytes,
      uBytes: image.planes.length > 1 ? image.planes[1].bytes : Uint8List(0),
      vBytes: image.planes.length > 2 ? image.planes[2].bytes : Uint8List(0),
      width: image.width,
      height: image.height,
      yRow: image.planes[0].bytesPerRow,
      uRow: image.planes.length > 1 ? image.planes[1].bytesPerRow : 0,
      vRow: image.planes.length > 2 ? image.planes[2].bytesPerRow : 0,
      yPs: image.planes[0].bytesPerPixel ?? 1,
      uPs: image.planes.length > 1 ? (image.planes[1].bytesPerPixel ?? 1) : 1,
      vPs: image.planes.length > 2 ? (image.planes[2].bytesPerPixel ?? 1) : 1,
      planeCount: image.planes.length,
      timestamp: timestamp,
    );
  }
}

class _ResultMessage {
  final Uint8List rgbBytes;
  final int width;
  final int height;
  final DateTime timestamp;

  _ResultMessage({
    required this.rgbBytes,
    required this.width,
    required this.height,
    required this.timestamp,
  });
}

class _ErrorMessage {
  final String text;
  _ErrorMessage(this.text);
}

void _processFrames(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  Uint8List? rgbBuffer;

  receivePort.listen((message) {
    if (message is _FrameMessage) {
      try {
        final size = message.width * message.height * 3;
        rgbBuffer ??= Uint8List(size);
        if (rgbBuffer!.length < size) {
          rgbBuffer = Uint8List(size);
        }
        final rgb = rgbBuffer!;

        if (message.planeCount == 3) {
          _convertYuv420(
            rgb,
            message.yBytes,
            message.uBytes,
            message.vBytes,
            message.width,
            message.height,
            message.yRow,
            message.uRow,
            message.vRow,
            message.yPs,
            message.uPs,
            message.vPs,
          );
        } else {
          _convertNv21(
            rgb,
            message.yBytes,
            message.uBytes,
            message.width,
            message.height,
            message.yRow,
            message.uRow,
          );
        }

        sendPort.send(_ResultMessage(
          rgbBytes: rgb,
          width: message.width,
          height: message.height,
          timestamp: message.timestamp,
        ));
      } catch (e) {
        sendPort.send(_ErrorMessage('$e'));
      }
    }
  });
}

void _convertYuv420(
  Uint8List rgb,
  Uint8List y,
  Uint8List u,
  Uint8List v,
  int width,
  int height,
  int yRow,
  int uRow,
  int vRow,
  int yPs,
  int uPs,
  int vPs,
) {
  int outIdx = 0;
  for (int h = 0; h < height; h++) {
    final yOff = yRow * h;
    for (int w = 0; w < width; w++) {
      final yVal = y[yOff + w * yPs] & 0xff;
      final uvH = h >> 1;
      final uvW = w >> 1;
      final uOff = uRow * uvH + uvW * uPs;
      final vOff = vRow * uvH + uvW * vPs;
      final uu = (u[uOff] & 0xff) - 128;
      final vv = (v[vOff] & 0xff) - 128;

      int r = yVal + ((vv * 1436) >> 10);
      int g = yVal - ((uu * 352) >> 10) - ((vv * 731) >> 10);
      int b = yVal + ((uu * 1815) >> 10);

      rgb[outIdx++] = _clamp(r);
      rgb[outIdx++] = _clamp(g);
      rgb[outIdx++] = _clamp(b);
    }
  }
}

void _convertNv21(
  Uint8List rgb,
  Uint8List y,
  Uint8List uv,
  int width,
  int height,
  int yRow,
  int uvRow,
) {
  int outIdx = 0;
  for (int h = 0; h < height; h++) {
    final yOff = yRow * h;
    for (int w = 0; w < width; w++) {
      final yVal = y[yOff + w] & 0xff;
      final uvIdx = uvRow * (h >> 1) + (w & ~1);
      final uu = (uv[uvIdx] & 0xff) - 128;
      final vv = (uv[uvIdx + 1] & 0xff) - 128;

      int r = yVal + ((vv * 1436) >> 10);
      int g = yVal - ((uu * 352) >> 10) - ((vv * 731) >> 10);
      int b = yVal + ((uu * 1815) >> 10);

      rgb[outIdx++] = _clamp(r);
      rgb[outIdx++] = _clamp(g);
      rgb[outIdx++] = _clamp(b);
    }
  }
}

int _clamp(int v) {
  if (v < 0) return 0;
  if (v > 255) return 255;
  return v;
}

class FrameProcessor {
  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _resultPort;
  StreamController<ProcessedFrame>? _outputController;
  bool _busy = false;
  DateTime? _busySince;
  static const Duration _busyTimeout = Duration(seconds: 2);
  bool _disposed = false;

  Stream<ProcessedFrame> get outputStream => _outputController!.stream;

  Future<void> start() async {
    _outputController = StreamController<ProcessedFrame>.broadcast();
    _resultPort = ReceivePort();

    final completer = Completer<void>();

    _resultPort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        completer.complete();
        return;
      }
      if (message is _ResultMessage) {
        _busy = false;
        _busySince = null;
        if (!_disposed && !_outputController!.isClosed) {
          _outputController!.add(ProcessedFrame(
            rgbBytes: message.rgbBytes,
            width: message.width,
            height: message.height,
            timestamp: message.timestamp,
          ));
        }
      }
      if (message is _ErrorMessage) {
        _busy = false;
        _busySince = null;
      }
    });

    _isolate = await Isolate.spawn(_processFrames, _resultPort!.sendPort);

    await completer.future;
  }

  bool process(CameraImage image) {
    if (_disposed || _isolateSendPort == null) return false;

    if (_busy) {
      if (_busySince != null &&
          DateTime.now().difference(_busySince!) > _busyTimeout) {
        _busy = false;
        _busySince = null;
      } else {
        return false;
      }
    }

    _busy = true;
    _busySince = DateTime.now();
    final msg = _FrameMessage.fromCameraImage(image, DateTime.now());
    _isolateSendPort!.send(msg);
    return true;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _outputController?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _resultPort?.close();
  }
}
