import 'dart:typed_data';

class ProcessedFrame {
  final Uint8List rgbBytes;
  final int width;
  final int height;
  final DateTime timestamp;
  final Uint8List? yBytes;
  final Uint8List? uvBytes;
  final int? yRowStride;
  final int? uvRowStride;

  ProcessedFrame({
    required this.rgbBytes,
    required this.width,
    required this.height,
    required this.timestamp,
    this.yBytes,
    this.uvBytes,
    this.yRowStride,
    this.uvRowStride,
  });
}
