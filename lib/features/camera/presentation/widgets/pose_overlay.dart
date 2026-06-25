import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vbt/services/pose_service.dart';
import 'package:vbt/services/angle_calculator.dart';
import 'package:vbt/services/angular_velocity_engine.dart';

class PoseOverlayPainter extends CustomPainter {
  final PoseResult? poseResult;
  final Map<String, JointAngle>? angles;
  final Map<String, AngularVelocityResult>? velocities;
  final double frameWidth;
  final double frameHeight;
  final bool showSkeleton;
  final bool showAngles;
  final bool showVelocity;

  PoseOverlayPainter({
    this.poseResult,
    this.angles,
    this.velocities,
    required this.frameWidth,
    required this.frameHeight,
    this.showSkeleton = true,
    this.showAngles = true,
    this.showVelocity = true,
  });

  static const _skeletonConnections = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (poseResult == null) return;

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

    Offset toScreen(PoseLandmarkData lm) {
      return Offset(
        lm.x * frameWidth * scale + offsetX,
        lm.y * frameHeight * scale + offsetY,
      );
    }

    if (showSkeleton) {
      _drawSkeleton(canvas, toScreen);
    }

    if (showAngles && angles != null) {
      _drawAngles(canvas, toScreen);
    }
  }

  void _drawSkeleton(Canvas canvas, Offset Function(PoseLandmarkData) toScreen) {
    final bonePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final jointPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final wristPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;

    for (final conn in _skeletonConnections) {
      final lm1 = poseResult![conn.$1];
      final lm2 = poseResult![conn.$2];
      if (lm1 != null && lm2 != null &&
          lm1.likelihood > 0.5 && lm2.likelihood > 0.5) {
        canvas.drawLine(toScreen(lm1), toScreen(lm2), bonePaint);
      }
    }

    for (final entry in poseResult!.landmarks.entries) {
      final lm = entry.value;
      if (lm.likelihood < 0.5) continue;

      final pos = toScreen(lm);
      final isWrist = entry.key == PoseLandmarkType.leftWrist ||
          entry.key == PoseLandmarkType.rightWrist;

      canvas.drawCircle(pos, isWrist ? 6 : 4, isWrist ? wristPaint : jointPaint);
    }
  }

  void _drawAngles(Canvas canvas, Offset Function(PoseLandmarkData) toScreen) {
    for (final entry in angles!.entries) {
      final angle = entry.value;
      final jointLm = poseResult![angle.joint];
      if (jointLm == null || angle.confidence < 0.5) continue;

      final jointPos = toScreen(jointLm);

      final proxLm = poseResult![angle.proximal];
      final distLm = poseResult![angle.distal];
      if (proxLm == null || distLm == null) continue;

      final proxPos = toScreen(proxLm);
      final distPos = toScreen(distLm);

      _drawAngleArc(canvas, proxPos, jointPos, distPos, angle.angleDeg);

      final vel = velocities?[entry.key];
      final label = '${angle.angleDeg.toStringAsFixed(0)}°';
      final velLabel = vel != null
          ? '${vel.smoothedVelocityDegPerSec.toStringAsFixed(0)}°/s'
          : '';

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label${velLabel.isNotEmpty ? '\n$velLabel' : ''}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(jointPos.dx + 12, jointPos.dy - 20),
      );
    }
  }

  void _drawAngleArc(
    Canvas canvas,
    Offset prox,
    Offset joint,
    Offset dist,
    double angleDeg,
  ) {
    final a1 = atan2(prox.dy - joint.dy, prox.dx - joint.dx);
    final a2 = atan2(dist.dy - joint.dy, dist.dx - joint.dx);

    final arcPaint = Paint()
      ..color = _angleColor(angleDeg)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final radius = 30.0;
    final rect = Rect.fromCircle(center: joint, radius: radius);

    double startAngle = a1;
    double sweepAngle = a2 - a1;

    if (sweepAngle > pi) sweepAngle -= 2 * pi;
    if (sweepAngle < -pi) sweepAngle += 2 * pi;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  Color _angleColor(double angleDeg) {
    if (angleDeg < 45) return Colors.red;
    if (angleDeg < 90) return Colors.orange;
    if (angleDeg < 135) return Colors.yellow;
    return Colors.greenAccent;
  }

  @override
  bool shouldRepaint(PoseOverlayPainter old) =>
      poseResult != old.poseResult ||
      angles != old.angles ||
      velocities != old.velocities;
}
