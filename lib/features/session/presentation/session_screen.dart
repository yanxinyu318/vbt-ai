import 'package:flutter/material.dart';
import 'package:vbt/domain/entities/rep_metrics.dart';
import 'package:vbt/features/session/presentation/widgets/rep_summary_card.dart';

class SessionScreen extends StatelessWidget {
  final List<RepMetrics> reps;
  final double durationSec;

  const SessionScreen({
    super.key,
    required this.reps,
    required this.durationSec,
  });

  @override
  Widget build(BuildContext context) {
    final meanV = reps.isEmpty
        ? 0.0
        : reps.map((r) => r.meanVelocity).reduce((a, b) => a + b) / reps.length;
    final peakV = reps.isEmpty
        ? 0.0
        : reps.map((r) => r.peakVelocity).reduce((a, b) => a > b ? a : b);

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
          child: Column(
            children: [
              _SummaryHeader(
                repCount: reps.length,
                meanVelocity: meanV,
                peakVelocity: peakV,
                durationSec: durationSec,
              ),
              Expanded(
                child: reps.isEmpty
                    ? const Center(
                        child: Text('No reps recorded',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: reps.length,
                        itemBuilder: (ctx, i) => RepSummaryCard(
                          rep: reps[i],
                          index: i + 1,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int repCount;
  final double meanVelocity;
  final double peakVelocity;
  final double durationSec;

  const _SummaryHeader({
    required this.repCount,
    required this.meanVelocity,
    required this.peakVelocity,
    required this.durationSec,
  });

  @override
  Widget build(BuildContext context) {
    final dur = Duration(seconds: durationSec.toInt());
    final durStr =
        '${dur.inMinutes.toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text('Session Summary',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Metric(label: 'Reps', value: '$repCount'),
              _Metric(
                  label: 'Mean Vel',
                  value: meanVelocity.toStringAsFixed(2)),
              _Metric(
                  label: 'Peak Vel',
                  value: peakVelocity.toStringAsFixed(2)),
              _Metric(label: 'Time', value: durStr),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      ],
    );
  }
}
