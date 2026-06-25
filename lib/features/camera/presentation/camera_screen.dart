import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vbt/features/camera/presentation/widgets/barbell_overlay.dart';
import 'package:vbt/features/session/presentation/session_screen.dart';
import 'package:vbt/providers/session_provider.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final state = session.state;

    return PopScope(
      canPop: state.status != SessionStatus.recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.status == SessionStatus.recording) {
          _showStopConfirm();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(state, session),
      ),
    );
  }

  Widget _buildBody(SessionState state, SessionNotifier session) {
    switch (state.status) {
      case SessionStatus.initializing:
      case SessionStatus.idle:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.cyan),
              SizedBox(height: 16),
              Text('Initializing camera...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        );
      case SessionStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(state.error ?? 'Unknown error',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        );
      case SessionStatus.ready:
        return _buildCameraPreview(session);
      case SessionStatus.recording:
        return _buildCameraPreview(session);
      case SessionStatus.finished:
        return _buildCameraPreview(session);
    }
  }

  Widget _buildCameraPreview(SessionNotifier session) {
    final cam = ref.read(cameraServiceProvider);
    final controller = cam.controller;
    final state = session.state;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    final previewSize = controller.value.previewSize!;
    final frameW = controller.value.isRecordingVideo ? previewSize.width : previewSize.height;
    final frameH = controller.value.isRecordingVideo ? previewSize.height : previewSize.width;

    return Stack(
      children: [
        ClipRect(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: controller.buildPreview(),
              ),
            ),
          ),
        ),
        if (state.status == SessionStatus.ready)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ready', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => session.startSession(),
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Start Session', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        if (state.status == SessionStatus.recording) ...[
          CustomPaint(
            size: Size.infinite,
            painter: BarbellOverlayPainter(
              position: state.barbellPosition,
              frameWidth: frameW,
              frameHeight: frameH,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VelocityOverlay(
              velocity: state.currentVelocity,
              repCount: state.repCount,
              durationSec: state.sessionDurationSec,
              recording: true,
            ),
          ),
        ],
        if (state.status == SessionStatus.finished)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                Text('${state.repCount} reps completed',
                    style: const TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(
                          reps: state.completedReps,
                          durationSec: state.sessionDurationSec,
                        ),
                      ),
                    );
                  },
                  child: const Text('View Summary'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showStopConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('End Session?', style: TextStyle(color: Colors.white)),
        content: const Text('All recorded reps will be saved.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(sessionProvider).stopSession();
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('End'),
          ),
        ],
      ),
    );
  }
}
