import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vbt/services/pose_service.dart';

class JointAngle {
  final PoseLandmarkType joint;
  final PoseLandmarkType proximal;
  final PoseLandmarkType distal;
  final double angleDeg;
  final double angleRad;
  final double confidence;

  const JointAngle({
    required this.joint,
    required this.proximal,
    required this.distal,
    required this.angleDeg,
    required this.angleRad,
    required this.confidence,
  });
}

class AngleCalculator {
  static const double _minConfidence = 0.5;

  static final Map<String, List<PoseLandmarkType>> exerciseJoints = {
    'squat': [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    ],
    'bench': [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    ],
    'deadlift': [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
    ],
    'overhead': [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    ],
  };

  static const Map<String, List<JointDef>> _jointDefs = {
    'squat_left_knee': [
      JointDef(PoseLandmarkType.leftHip),
      JointDef(PoseLandmarkType.leftKnee),
      JointDef(PoseLandmarkType.leftAnkle),
    ],
    'squat_right_knee': [
      JointDef(PoseLandmarkType.rightHip),
      JointDef(PoseLandmarkType.rightKnee),
      JointDef(PoseLandmarkType.rightAnkle),
    ],
    'bench_left_elbow': [
      JointDef(PoseLandmarkType.leftShoulder),
      JointDef(PoseLandmarkType.leftElbow),
      JointDef(PoseLandmarkType.leftWrist),
    ],
    'bench_right_elbow': [
      JointDef(PoseLandmarkType.rightShoulder),
      JointDef(PoseLandmarkType.rightElbow),
      JointDef(PoseLandmarkType.rightWrist),
    ],
    'deadlift_left_hip': [
      JointDef(PoseLandmarkType.leftShoulder),
      JointDef(PoseLandmarkType.leftHip),
      JointDef(PoseLandmarkType.leftKnee),
    ],
    'deadlift_right_hip': [
      JointDef(PoseLandmarkType.rightShoulder),
      JointDef(PoseLandmarkType.rightHip),
      JointDef(PoseLandmarkType.rightKnee),
    ],
    'overhead_left_elbow': [
      JointDef(PoseLandmarkType.leftShoulder),
      JointDef(PoseLandmarkType.leftElbow),
      JointDef(PoseLandmarkType.leftWrist),
    ],
    'overhead_right_elbow': [
      JointDef(PoseLandmarkType.rightShoulder),
      JointDef(PoseLandmarkType.rightElbow),
      JointDef(PoseLandmarkType.rightWrist),
    ],
  };

  static JointAngle? calculateAngle(
    PoseResult pose,
    PoseLandmarkType proximal,
    PoseLandmarkType joint,
    PoseLandmarkType distal,
  ) {
    final pProx = pose[proximal];
    final pJoint = pose[joint];
    final pDist = pose[distal];

    if (pProx == null || pJoint == null || pDist == null) return null;
    if (pProx.likelihood < _minConfidence ||
        pJoint.likelihood < _minConfidence ||
        pDist.likelihood < _minConfidence) {
      return null;
    }

    final v1x = pProx.x - pJoint.x;
    final v1y = pProx.y - pJoint.y;
    final v2x = pDist.x - pJoint.x;
    final v2y = pDist.y - pJoint.y;

    final dot = v1x * v2x + v1y * v2y;
    final mag1 = sqrt(v1x * v1x + v1y * v1y);
    final mag2 = sqrt(v2x * v2x + v2y * v2y);

    if (mag1 < 1e-6 || mag2 < 1e-6) return null;

    var cosAngle = dot / (mag1 * mag2);
    cosAngle = cosAngle.clamp(-1.0, 1.0);

    final angleRad = acos(cosAngle);
    final angleDeg = angleRad * 180.0 / pi;

    final confidence = (pProx.likelihood + pJoint.likelihood + pDist.likelihood) / 3.0;

    return JointAngle(
      joint: joint,
      proximal: proximal,
      distal: distal,
      angleDeg: angleDeg,
      angleRad: angleRad,
      confidence: confidence,
    );
  }

  static Map<String, JointAngle> calculateExerciseAngles(
    PoseResult pose,
    String exerciseType,
  ) {
    final results = <String, JointAngle>{};

    final defKey = exerciseType.toLowerCase();
    final defs = _jointDefs.entries.where(
      (e) => e.key.startsWith(defKey),
    );

    for (final entry in defs) {
      final parts = entry.key.split('_');
      final side = parts[1];
      final jointName = parts.sublist(2).join('_');

      final angle = calculateAngle(
        pose,
        entry.value[0].type,
        entry.value[1].type,
        entry.value[2].type,
      );

      if (angle != null) {
        results['${side}_$jointName'] = angle;
      }
    }

    return results;
  }

  static JointAngle? calculatePrimaryAngle(PoseResult pose, String exerciseType) {
    final angles = calculateExerciseAngles(pose, exerciseType);
    if (angles.isEmpty) return null;

    JointAngle? best;
    for (final angle in angles.values) {
      if (best == null || angle.confidence > best.confidence) {
        best = angle;
      }
    }
    return best;
  }
}

class JointDef {
  final PoseLandmarkType type;
  const JointDef(this.type);
}
