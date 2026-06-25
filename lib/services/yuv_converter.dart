import 'dart:typed_data';
import 'package:camera/camera.dart';

class YuvConverter {
  YuvConverter();

  Uint8List convert(CameraImage image, {Uint8List? outBuffer}) {
    final width = image.width;
    final height = image.height;
    final expectedSize = width * height * 3;

    final rgb = outBuffer ?? Uint8List(expectedSize);

    if (image.planes.length == 3) {
      _convertYuv420888(image, rgb);
    } else {
      _convertNv21(image, rgb);
    }

    return rgb;
  }

  void _convertYuv420888(CameraImage image, Uint8List rgb) {
    final y = image.planes[0].bytes;
    final u = image.planes[1].bytes;
    final v = image.planes[2].bytes;

    final yRow = image.planes[0].bytesPerRow;
    final uRow = image.planes[1].bytesPerRow;
    final vRow = image.planes[2].bytesPerRow;

    final yPs = image.planes[0].bytesPerPixel ?? 1;
    final uPs = image.planes[1].bytesPerPixel ?? 1;
    final vPs = image.planes[2].bytesPerPixel ?? 1;

    final width = image.width;
    final height = image.height;
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

        final yy = yVal;
        int r = yy + ((vv * 1436) >> 10);
        int g = yy - ((uu * 352) >> 10) - ((vv * 731) >> 10);
        int b = yy + ((uu * 1815) >> 10);

        rgb[outIdx++] = _clamp(r);
        rgb[outIdx++] = _clamp(g);
        rgb[outIdx++] = _clamp(b);
      }
    }
  }

  void _convertNv21(CameraImage image, Uint8List rgb) {
    final y = image.planes[0].bytes;
    final uv = image.planes[1].bytes;

    final yRow = image.planes[0].bytesPerRow;
    final uvRow = image.planes[1].bytesPerRow;

    final width = image.width;
    final height = image.height;
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
}
