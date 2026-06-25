import 'package:flutter/material.dart';
import 'package:vbt/domain/entities/barbell_position.dart';

class BarbellOverlayPainter extends CustomPainter {
  final BarbellPosition? position;
  final double frameWidth;
  final double frameHeight;

  BarbellOverlayPainter({
    this.position,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (position == null) return;

    final scaleX = size.width / frameWidth;
    final scaleY = size.height / frameHeight;
    final px = position!.x * scaleX;
    final py = position!.y * scaleY;

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

  @override
  bool shouldRepaint(BarbellOverlayPainter old) =>
      position?.x != old.position?.x || position?.y != old.position?.y;
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
