import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vbt/domain/entities/barbell_position.dart';

class BarbellOverlayPainter extends CustomPainter {
  final BarbellPosition? position;
  final double frameWidth;
  final double frameHeight;
  final Offset? pointA;
  final Offset? pointB;
  final bool showRoi;

  BarbellOverlayPainter({
    this.position,
    required this.frameWidth,
    required this.frameHeight,
    this.pointA,
    this.pointB,
    this.showRoi = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pointA != null) {
      _drawCrosshair(canvas, pointA!, Colors.red, 20);
    }
    if (pointB != null) {
      _drawCrosshair(canvas, pointB!, Colors.red, 20);
    }
    if (pointA != null && pointB != null) {
      final center = Offset(
        (pointA!.dx + pointB!.dx) / 2,
        (pointA!.dy + pointB!.dy) / 2,
      );
      final linePaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(pointA!, pointB!, linePaint);
      _drawCrosshair(canvas, center, Colors.green, 14);
    }

    if (showRoi && pointA != null && pointB != null) {
      final roiRect = Rect.fromPoints(pointA!, pointB!);
      final dashPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      _drawDashedRect(canvas, roiRect, dashPaint, dashLength: 8, gapLength: 5);
    }

    if (position == null) return;

    final frameAspect = frameWidth / frameHeight;
    final screenAspect = size.width / size.height;

    double scale, offsetX = 0, offsetY = 0;
    if (screenAspect > frameAspect) {
      scale = size.width / frameWidth;
      final renderedH = frameHeight * scale;
      offsetY = (size.height - renderedH) / 2;
    } else {
      scale = size.height / frameHeight;
      final renderedW = frameWidth * scale;
      offsetX = (size.width - renderedW) / 2;
    }

    final px = position!.x * scale + offsetX;
    final py = position!.y * scale + offsetY;

    final dotPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(Offset(px, py), 10, dotPaint);

    final ringPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset(px, py), 18, ringPaint);

    final crossPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final r = 14.0;
    canvas.drawLine(Offset(px - r, py), Offset(px + r, py), crossPaint);
    canvas.drawLine(Offset(px, py - r), Offset(px, py + r), crossPaint);
  }

  void _drawCrosshair(Canvas canvas, Offset center, Color color, double size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, {
    double dashLength = 8,
    double gapLength = 5,
  }) {
    final path = Path();

    path.moveTo(rect.left, rect.top);
    var x = rect.left;
    while (x < rect.right) {
      final end = min(x + dashLength, rect.right);
      path.lineTo(end, rect.top);
      x = end + gapLength;
    }

    path.moveTo(rect.right, rect.top);
    var y = rect.top;
    while (y < rect.bottom) {
      final end = min(y + dashLength, rect.bottom);
      path.lineTo(rect.right, end);
      y = end + gapLength;
    }

    path.moveTo(rect.right, rect.bottom);
    x = rect.right;
    while (x > rect.left) {
      final end = max(x - dashLength, rect.left);
      path.lineTo(end, rect.bottom);
      x = end - gapLength;
    }

    path.moveTo(rect.left, rect.bottom);
    y = rect.bottom;
    while (y > rect.top) {
      final end = max(y - dashLength, rect.top);
      path.lineTo(rect.left, end);
      y = end - gapLength;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BarbellOverlayPainter old) =>
      position?.x != old.position?.x ||
      position?.y != old.position?.y ||
      pointA != old.pointA ||
      pointB != old.pointB ||
      showRoi != old.showRoi;
}

class VelocityOverlay extends StatelessWidget {
  final double velocity;
  final int repCount;
  final double durationSec;
  final bool recording;

  const VelocityOverlay({
    super.key,
    required this.velocity,
    required this.repCount,
    required this.durationSec,
    required this.recording,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 2),
        Text(
          velocity.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w200,
            color: _velocityColor,
            letterSpacing: -2,
            height: 1,
          ),
        ),
        Text(
          'm/s',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Pill(label: 'REP $repCount', icon: Icons.repeat),
            const SizedBox(width: 12),
            _Pill(
              label: _formatDuration(durationSec),
              icon: Icons.timer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (recording)
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            child: _StopButton(),
          ),
      ],
    );
  }

  Color get _velocityColor {
    final abs = velocity.abs();
    if (abs < 0.3) return Colors.white;
    if (abs < 0.6) return Colors.cyan;
    if (abs < 1.0) return Colors.limeAccent;
    return Colors.greenAccent;
  }

  String _formatDuration(double sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Pill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(true),
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x42FF0000), blurRadius: 16, spreadRadius: 4)],
        ),
        child: const Icon(Icons.stop, color: Colors.white, size: 28),
      ),
    );
  }
}
