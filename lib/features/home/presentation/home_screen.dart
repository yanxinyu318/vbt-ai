import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vbt/features/calibration/presentation/calibration_screen.dart';
import 'package:vbt/features/camera/presentation/camera_screen.dart';
import 'package:vbt/features/pose/presentation/pose_screen.dart';
import 'package:vbt/features/session/presentation/session_screen.dart';
import 'package:vbt/providers/session_provider.dart';
import 'package:vbt/services/frame_skip_strategy.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center, size: 64, color: Colors.cyan),
                  const SizedBox(height: 16),
                  Text(
                    'VBT',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '杠铃速度训练',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 48),
                  _StatusChip(
                    icon: session.state.isCalibrated ? Icons.check_circle : Icons.warning,
                    label: session.state.isCalibrated ? '已标定' : '未标定',
                    color: session.state.isCalibrated ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _PerformanceModeSelector(
                    mode: session.state.performanceMode,
                    onChanged: (m) => ref.read(sessionProvider).changePerformanceMode(m),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(sessionProvider).initialize();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CameraScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('开始新训练', style: TextStyle(fontSize: 18)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CalibrationScreen(
                              calibrationService: ref.read(calibrationServiceProvider),
                              onCalibrated: () => ref.read(sessionProvider).recalibrate(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('标定'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PoseScreen()),
                        );
                      },
                      icon: const Icon(Icons.accessibility_new),
                      label: const Text('姿态与角度'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyan,
                        side: const BorderSide(color: Colors.cyan),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  if (session.state.completedReps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SessionScreen(
                                reps: session.state.completedReps,
                                durationSec: session.state.sessionDurationSec,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('上次训练'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceModeSelector extends StatelessWidget {
  final PerformanceMode mode;
  final ValueChanged<PerformanceMode> onChanged;

  const _PerformanceModeSelector({
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = PerformanceMode.values;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final m in modes) ...[
          if (m != modes.first) const SizedBox(width: 8),
          _ModeChip(
            label: switch (m) {
              PerformanceMode.batterySaver => '省电',
              PerformanceMode.balanced => '均衡',
              PerformanceMode.performance => '高性能',
            },
            icon: switch (m) {
              PerformanceMode.batterySaver => Icons.battery_std,
              PerformanceMode.balanced => Icons.balance,
              PerformanceMode.performance => Icons.bolt,
            },
            selected: m == mode,
            onTap: () => onChanged(m),
          ),
        ],
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.cyan : Colors.white38;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.cyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
