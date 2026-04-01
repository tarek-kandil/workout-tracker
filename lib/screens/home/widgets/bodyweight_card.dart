import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/home_providers.dart';

class BodyweightCard extends ConsumerWidget {
  const BodyweightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestBodyweightProvider);
    final recentAsync = ref.watch(recentBodyweightsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight_outlined),
                const SizedBox(width: 8),
                Text('Body Weight',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                latestAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (entry) => entry == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${entry.weightKg.toStringAsFixed(1)} kg',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('MMM d').format(entry.date),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
              ],
            ),
            recentAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (entries) {
                if (entries.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Log your body weight in Settings to see a trend here.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 60,
                    child: _Sparkline(entries: entries.reversed.toList()),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  final List entries;
  const _Sparkline({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              (e.value.weightKg as double),
            ))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
