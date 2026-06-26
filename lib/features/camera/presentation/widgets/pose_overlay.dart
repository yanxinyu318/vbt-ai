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
  final double sensorWidth;
  final double sensorHeight;
  final int sensorOrientation;
  final bool mirrorX;
  final bool showSkeleton;
  final bool showAngles;
  final bool showVelocity;

  PoseOverlayPainter({
    this.poseResult,
    this.angles,
    this.velocities,
    required this.frameWidth,
    required this.frameHeight,
    this.sensorWidth = 640,
    this.sensorHeight = 480,
    this.sensorOrientation = 90,
    this.mirrorX = false,
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

    final frameAspect = sensorWidth / sensorHeight;
    final screenAspect = size.width / size.height;

    double scale, offsetX = 0, offsetY = 0;
    if (screenAspect > frameAspect) {
      scale = size.width / sensorWidth;
      final renderedH = sensorHeight * scale;
      offsetY = (size.height - renderedH) / 2;
    } else {
      scale = size.height / sensorHeight;
      final renderedW = sensorWidth * scale;
      offsetX = (size.width - renderedW) / 2;
    }

    Offset toScreen(PoseLandmarkData lm) {
      double px, py;
      if (mirrorX) {
        switch (sensorOrientation) {
          case 270:
            px = lm.y;
            py = lm.x;
            break;
          case 180:
            px = lm.x;
            py = sensorHeight - lm.y;
            break;
          case 90:
            px = sensorHeight - lm.y;
            py = sensorWidth - lm.x;
            break;
          default:
            px = sensorWidth - lm.x;
            py = lm.y;
        }
      } else {
        switch (sensorOrientation) {
          case 90:
            px = lm.y;
            py = sensorWidth - lm.x;
            break;
          case 180:
            px = sensorWidth - lm.x;
            py = sensorHeight - lm.y;
            break;
          case 270:
            px = sensorHeight - lm.y;
            py = lm.x;
            break;
          default:
            px = lm.x;
            py = lm.y;
        }
      }
      return Offset(
        px * scale + offsetX,
        py * scale + offsetY,
      );
    }

    if (showSkeleton) {
      _drawSkeleton(canvas, toScreen);
    }

    if (showAngles && angles != null) {
      _drawAngles(canvas, toScreen, size);
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

  void _drawAngles(Canvas canvas, Offset Function(PoseLandmarkData) toScreen, Size size) {
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

      final color = _angleColor(angle.angleDeg);

      final axisPaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(jointPos, proxPos, axisPaint);
      canvas.drawLine(jointPos, distPos, axisPaint);

      _drawAngleArc(canvas, proxPos, jointPos, distPos, angle.angleDeg);

      final vel = velocities?[entry.key];
      final label = '${angle.angleDeg.toStringAsFixed(1)}°';
      final velLabel = vel != null
          ? '${vel.smoothedVelocityDegPerSec.toStringAsFixed(1)}°/s'
          : '';

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$label${velLabel.isNotEmpty ? '\n$velLabel' : ''}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var labelX = jointPos.dx + 16;
      var labelY = jointPos.dy - 24;
      if (labelX + textPainter.width > size.width - 8) {
        labelX = jointPos.dx - textPainter.width - 16;
      }
      if (labelY < 8) labelY = jointPos.dy + 16;
      if (labelY + textPainter.height > size.height - 8) {
        labelY = size.height - textPainter.height - 8;
      }

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelX - 4, labelY - 2, textPainter.width + 8, textPainter.height + 4),
        const Radius.circular(4),
      );
      canvas.drawRRect(bgRect, Paint()..color = Colors.black54);

      textPainter.paint(canvas, Offset(labelX, labelY));
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
