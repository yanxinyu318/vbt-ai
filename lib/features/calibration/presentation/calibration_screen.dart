import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vbt/domain/entities/calibration.dart';
import 'package:vbt/services/calibration_service.dart';

class CalibrationScreen extends StatefulWidget {
  final CalibrationService calibrationService;
  final VoidCallback? onCalibrated;

  const CalibrationScreen({
    super.key,
    required this.calibrationService,
    this.onCalibrated,
  });

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  CameraController? _controller;
  Offset? _pointA;
  Offset? _pointB;
  double? _pixelDistance;
  double? _pixelsPerMeter;
  CalibrationMethod _method = CalibrationMethod.plateDiameter;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final granted = await Permission.camera.request().isGranted;
    if (!granted) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _onTap(Offset point) {
    final previewSize = _controller!.value.previewSize!;
    final scaleX = previewSize.width / context.size!.width;
    final scaleY = previewSize.height / context.size!.height;

    final scaled = Offset(point.dx * scaleX, point.dy * scaleY);

    if (_pointA == null) {
      setState(() {
        _pointA = scaled;
        _pointB = null;
        _pixelDistance = null;
        _pixelsPerMeter = null;
      });
    } else if (_pointB == null) {
      setState(() {
        _pointB = scaled;
        _pixelDistance = _pointA != null
            ? _offsetDistance(_pointA!, scaled)
            : null;
        if (_pixelDistance != null && _pixelDistance! > 0) {
          _pixelsPerMeter = widget.calibrationService
              .calcPixelsPerMeter(_pixelDistance!, _method);
        }
      });
    } else {
      setState(() {
        _pointA = scaled;
        _pointB = null;
        _pixelDistance = null;
        _pixelsPerMeter = null;
      });
    }
  }

  double _offsetDistance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return _sqrt(dx * dx + dy * dy);
  }

  Future<void> _confirm() async {
    if (_pixelsPerMeter == null || _pixelsPerMeter! <= 0) return;
    if (!widget.calibrationService.validateCalibration(_pixelsPerMeter!)) return;

    await widget.calibrationService.save(
      Calibration(
        pixelsPerMeter: _pixelsPerMeter!,
        calibratedAt: DateTime.now(),
      ),
    );
    widget.onCalibrated?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calibrate')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _controller == null || !_controller!.value.isInitialized
              ? const Center(child: Text('Camera not available'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final label = _method == CalibrationMethod.plateDiameter
        ? 'Tap two edges of a plate'
        : 'Tap both ends of the barbell';

    return Column(
      children: [
        _buildMethodToggle(),
        Expanded(
          child: GestureDetector(
            onTapUp: (details) => _onTap(details.localPosition),
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: Stack(
                children: [
                  ClipRect(child: _controller!.buildPreview()),
                  CustomPaint(
                    painter: _CalibrationPainter(
                      pointA: _pointA,
                      pointB: _pointB,
                      pixelDistance: _pixelDistance,
                      method: _method,
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(label,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildResultBar(),
      ],
    );
  }

  Widget _buildMethodToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _methodChip(CalibrationMethod.plateDiameter, 'Plate (45cm)'),
          const SizedBox(width: 8),
          _methodChip(CalibrationMethod.barbellLength, 'Barbell (220cm)'),
        ],
      ),
    );
  }

  Widget _methodChip(CalibrationMethod method, String label) {
    final selected = _method == method;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _method = method;
        _pointA = null;
        _pointB = null;
        _pixelDistance = null;
        _pixelsPerMeter = null;
      }),
    );
  }

  Widget _buildResultBar() {
    final valid = _pixelsPerMeter != null &&
        widget.calibrationService.validateCalibration(_pixelsPerMeter!);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _pixelsPerMeter != null
                  ? '${_pixelsPerMeter!.toStringAsFixed(1)} px/m'
                  : 'Tap two points',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Spacer(),
          if (_pointA != null)
            TextButton(
              onPressed: () => setState(() {
                _pointA = null;
                _pointB = null;
                _pixelDistance = null;
                _pixelsPerMeter = null;
              }),
              child: const Text('Reset'),
            ),
          const SizedBox(width: 8),
          if (valid)
            FilledButton(onPressed: _confirm, child: const Text('Confirm')),
        ],
      ),
    );
  }

  double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v, y = 1;
    const e = 1e-10;
    while (x - y > e) {
      x = (x + y) / 2;
      y = v / x;
    }
    return x;
  }
}

class _CalibrationPainter extends CustomPainter {
  final Offset? pointA;
  final Offset? pointB;
  final double? pixelDistance;
  final CalibrationMethod method;

  _CalibrationPainter({
    this.pointA,
    this.pointB,
    this.pixelDistance,
    required this.method,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    if (pointA != null) {
      canvas.drawCircle(pointA!, 6, paint..style = PaintingStyle.fill);
    }
    if (pointB != null) {
      canvas.drawCircle(pointB!, 6, paint..style = PaintingStyle.fill);
    }
    if (pointA != null && pointB != null) {
      paint..style = PaintingStyle.stroke..color = Colors.cyan;
      canvas.drawLine(pointA!, pointB!, paint);

      if (pixelDistance != null) {
        final mid = Offset(
          (pointA!.dx + pointB!.dx) / 2,
          (pointA!.dy + pointB!.dy) / 2 - 12,
        );
        final knownCm = method == CalibrationMethod.plateDiameter ? 45 : 220;
        final textSpan = TextSpan(
          text: '${pixelDistance!.toStringAsFixed(0)} px = $knownCm cm',
          style: const TextStyle(color: Colors.cyan, fontSize: 14),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(_CalibrationPainter old) =>
      pointA != old.pointA || pointB != old.pointB || pixelDistance != old.pixelDistance;
}
