import 'dart:typed_data';

class ProcessedFrame {
  final Uint8List rgbBytes;
  final int width;
  final int height;
  final DateTime timestamp;

  ProcessedFrame({
    required this.rgbBytes,
    required this.width,
    required this.height,
    required this.timestamp,
  });
}
