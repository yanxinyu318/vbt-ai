import 'dart:async';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'frame_processor.dart';
import 'frame_skip_strategy.dart';
import 'processed_frame.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  FrameProcessor? _processor;
  StreamController<ProcessedFrame>? _frameController;
  StreamSubscription? _processorSubscription;
  bool _initialized = false;
  final FrameSkipStrategy _skipStrategy;

  CameraService({FrameSkipStrategy? skipStrategy})
      : _skipStrategy = skipStrategy ?? FrameSkipStrategy();

  Stream<ProcessedFrame> get frameStream => _frameController!.stream;
  FrameSkipStrategy get skipStrategy => _skipStrategy;

  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.back}) async {
    if (_initialized) {
      await _stopImageStreamIfRunning();
      await _recreateProcessor();
      await _startImageStream();
      return;
    }
    _initialized = true;

    try {
      final granted = await Permission.camera.request().isGranted;
      if (!granted) {
        throw Exception('Camera permission denied');
      }

      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        throw Exception('No camera available on this device');
      }
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _cameras!.first,
      );

      _processor = FrameProcessor();
      await _processor!.start();

      if (_frameController == null || _frameController!.isClosed) {
        _frameController = StreamController<ProcessedFrame>.broadcast();
      }

      await _processorSubscription?.cancel();
      _processorSubscription = _processor!.outputStream.listen(
        (frame) {
          if (!(_frameController?.isClosed ?? true)) {
            _frameController!.add(frame);
          }
        },
        onError: (error) {
          if (!(_frameController?.isClosed ?? true)) {
            _frameController!.addError(error);
          }
        },
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        fps: 60,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      await _controller!.startImageStream(_onImageStream);
    } catch (e) {
      _initialized = false;
      await _processorSubscription?.cancel();
      _processorSubscription = null;
      _processor?.dispose();
      _processor = null;
      _frameController?.close();
      _frameController = null;
      rethrow;
    }
  }

  Future<void> _recreateProcessor() async {
    await _processor?.dispose();
    _processor = null;
    await _processorSubscription?.cancel();
    _processorSubscription = null;
    _processor = FrameProcessor();
    await _processor!.start();
    _processorSubscription = _processor!.outputStream.listen(
      (frame) {
        if (!(_frameController?.isClosed ?? true)) {
          _frameController!.add(frame);
        }
      },
      onError: (error) {
        if (!(_frameController?.isClosed ?? true)) {
          _frameController!.addError(error);
        }
      },
    );
  }

  Future<void> _stopImageStreamIfRunning() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  Future<void> _startImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.startImageStream(_onImageStream);
  }

  void _onImageStream(CameraImage image) {
    if (_skipStrategy.shouldProcess()) {
      final sw = Stopwatch()..start();
      _processor?.process(image);
      _skipStrategy.recordProcessingTime(sw.elapsed);
    }
  }

  Future<void> toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2 || _controller == null) return;

    await _controller!.stopImageStream();

    final currentDirection = _controller!.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    if (_cameras!.isEmpty) return;
    final newCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == newDirection,
      orElse: () => _cameras!.first,
    );

    await _controller!.dispose();

    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
      fps: 60,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_onImageStream);
  }

  CameraController? get controller => _controller;

  Future<void> dispose() async {
    _initialized = false;
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
    await _processorSubscription?.cancel();
    _processorSubscription = null;
    await _processor?.dispose();
    _processor = null;
    await _frameController?.close();
    _frameController = null;
  }
}