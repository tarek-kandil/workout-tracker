import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../providers/weight_goal_providers.dart';
import '../../../utils/weight_goal_calculations.dart';
import '../../../utils/weight_goal_ui.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/glass_route.dart';
import '../../weight/weight_goal_setup_screen.dart';
import '../../weight/weight_hub_screen.dart';

/// Home-screen tile (FR-027 – FR-030): latest weight + trend, status pill,
/// mini sparkline, next-weigh-in / calorie chips — or an empty/reached
/// state. Tapping anywhere opens the Weight Hub.
class WeightGoalCard extends ConsumerWidget {
  const WeightGoalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(weightGoalHomeViewModelProvider);
    final style = WeightGoalStatusStyle.of(vm.verdict);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        glassRoute(vm.hasPlan
            ? const WeightHubScreen()
            : const WeightGoalSetupScreen()),
      ),
      child: SizedBox(
        height: 132,
        child: GlassCard(
          child: vm.hasPlan ? _PlanBody(vm: vm, style: style) : _EmptyBody(style: style),
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final WeightGoalStatusStyle style;
  const _EmptyBody({required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.flag_outlined, size: 32, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Set your weight goal',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Get a personalized calorie target and coach.',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Set goal',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  final WeightGoalHomeViewModel vm;
  final WeightGoalStatusStyle style;
  const _PlanBody({required this.vm, required this.style});

  @override
  Widget build(BuildContext context) {
    final reached = vm.verdict == WeightGoalVerdict.goalReached;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vm.latestWeightKg != null
                        ? '${vm.latestWeightKg!.toStringAsFixed(1)} kg'
                        : '— kg',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  if (vm.trendWeightKg != null)
                    Text(
                      'Trend ${vm.trendWeightKg!.toStringAsFixed(1)} kg',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
            _MiniSparkline(points: vm.sparkline, color: style.color),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(style.icon, size: 13, color: style.color),
            const SizedBox(width: 4),
            Text(reached ? 'Goal reached' : style.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.color)),
          ],
        ),
        const Spacer(),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (reached)
              _Chip(
                icon: Icons.emoji_events_rounded,
                label: 'Choose next goal',
                color: style.color,
              )
            else ...[
              _Chip(
                icon: vm.weighInOverdue
                    ? Icons.notification_important_rounded
                    : Icons.event_repeat_rounded,
                label: vm.weighInOverdue
                    ? 'Log due'
                    : vm.daysUntilNextWeighIn != null
                        ? 'Next weigh-in in ${vm.daysUntilNextWeighIn}d'
                        : 'Log a weigh-in',
                color: vm.weighInOverdue
                    ? const Color(0xFFFF9F0A)
                    : Colors.white.withValues(alpha: 0.6),
              ),
              if (vm.todayCalories != null)
                _Chip(
                  icon: Icons.local_fire_department_rounded,
                  label: '${vm.todayCalories!.round()} kcal today',
                  color: Colors.white.withValues(alpha: 0.6),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<WeightChartPoint> points;
  final Color color;
  const _MiniSparkline({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox(width: 70, height: 36);

    final actualSpots = <FlSpot>[];
    final projectedSpots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.actualKg != null) actualSpots.add(FlSpot(i.toDouble(), p.actualKg!));
      projectedSpots.add(FlSpot(i.toDouble(), p.projectedKg));
    }
    final allY = [...actualSpots.map((s) => s.y), ...projectedSpots.map((s) => s.y)];
    if (allY.isEmpty) return const SizedBox(width: 70, height: 36);
    final minY = allY.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 0.5;

    return SizedBox(
      width: 70,
      height: 36,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: projectedSpots,
              color: const Color(0xFF818CF8),
              barWidth: 1.5,
              dashArray: [4, 3],
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: actualSpots,
              color: const Color(0xFF38BDF8),
              barWidth: 2,
              isCurved: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
