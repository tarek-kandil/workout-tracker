import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/home_providers.dart';

class StrengthChartCard extends ConsumerWidget {
  const StrengthChartCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exerciseAsync = ref.watch(chartExerciseProvider);

    return exerciseAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (exercise) {
        if (exercise == null) return const SizedBox.shrink();
        return _ChartContent(exerciseId: exercise.id, exerciseName: exercise.name);
      },
    );
  }
}

class _ChartContent extends ConsumerWidget {
  final int exerciseId;
  final String exerciseName;
  const _ChartContent(
      {required this.exerciseId, required this.exerciseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(strengthHistoryProvider(exerciseId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$exerciseName Progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (history) {
                if (history.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Log at least 2 sessions to see your progress chart.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }

                final spots = history
                    .asMap()
                    .entries
                    .map((e) =>
                        FlSpot(e.key.toDouble(), e.value.maxWeightKg))
                    .toList();

                final minY = history
                        .map((h) => h.maxWeightKg)
                        .reduce((a, b) => a < b ? a : b) -
                    5;
                final maxY = history
                        .map((h) => h.maxWeightKg)
                        .reduce((a, b) => a > b ? a : b) +
                    5;

                // Progress label
                final gained =
                    history.last.maxWeightKg - history.first.maxWeightKg;
                final gainedLabel = gained >= 0
                    ? '+${gained.toStringAsFixed(1)} kg'
                    : '${gained.toStringAsFixed(1)} kg';

                return Column(
                  children: [
                    SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (history.length / 4)
                                    .ceilToDouble()
                                    .clamp(1, double.infinity),
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= history.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    DateFormat('MMM d')
                                        .format(history[idx].date),
                                    style: const TextStyle(fontSize: 9),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Theme.of(context).colorScheme.primary,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                  radius: 3,
                                  color: Theme.of(context).colorScheme.primary,
                                  strokeWidth: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gained >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          size: 16,
                          color: gained >= 0 ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$gainedLabel since first session',
                          style: TextStyle(
                            fontSize: 12,
                            color: gained >= 0 ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
