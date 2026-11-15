import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:vbt/domain/entities/rep_metrics.dart';

class RepSummaryCard extends StatelessWidget {
  final RepMetrics rep;
  final int index;

  const RepSummaryCard({super.key, required this.rep, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
        title: Row(
          children: [
            _Stat(label: '平均', value: '${rep.meanVelocity.toStringAsFixed(2)} m/s'),
            const SizedBox(width: 16),
            _Stat(label: '峰值', value: '${rep.peakVelocity.toStringAsFixed(2)} m/s'),
          ],
        ),
        subtitle: Row(
          children: [
            if (rep.power > 0)
              _Stat(
                  label: '功率',
                  value: '${rep.power.toStringAsFixed(0)} W'),
            const SizedBox(width: 16),
            _Stat(
                label: '行程',
                value: '${rep.rom.toStringAsFixed(2)} m'),
            const SizedBox(width: 16),
            _Stat(
                label: '时间',
                value: '${(rep.totalRepTimeMs / 1000).toStringAsFixed(1)}s'),
          ],
        ),
        children: [
          if (rep.velocityTrace.length >= 2)
            SizedBox(
              height: 140,
              child: _VelocityChart(trace: rep.velocityTrace),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Pill(label: '峰值加速度',
                  value: '${rep.peakAcceleration.toStringAsFixed(2)} m/s²'),
              _Pill(label: '向心',
                  value: '${(rep.concentricTimeMs / 1000).toStringAsFixed(2)}s'),
              _Pill(label: '离心',
                  value: '${(rep.eccentricTimeMs / 1000).toStringAsFixed(2)}s'),
              if (rep.estimatedOneRm > 0)
                _Pill(label: '预估 1RM',
                    value: '${rep.estimatedOneRm.toStringAsFixed(1)} kg'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.7),
                  fontSize: 11)),
          const SizedBox(width: 6),
          Text(value,
              style:
                  const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

class _VelocityChart extends StatelessWidget {
  final List<double> trace;

  const _VelocityChart({required this.trace});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < trace.length; i++) {
      spots.add(FlSpot(i.toDouble(), trace[i]));
    }

    final maxVel = trace.reduce((a, b) => a > b ? a : b);
    final minVel = trace.reduce((a, b) => a < b ? a : b);
    final pad = (maxVel - minVel) * 0.15;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxVel - minVel) / 4).clamp(0.01, double.infinity),
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        minY: minVel - pad,
        maxY: maxVel + pad,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.cyan,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.cyan.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
