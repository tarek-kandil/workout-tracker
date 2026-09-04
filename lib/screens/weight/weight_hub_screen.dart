import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../database/app_database.dart';
import '../../models/weight_goal_plan.dart';
import '../../providers/home_providers.dart';
import '../../providers/weight_goal_providers.dart';
import '../../utils/weight_goal_calculations.dart';
import '../../utils/weight_goal_ui.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import 'weight_goal_setup_screen.dart';
import 'widgets/weigh_in_sheet.dart';

/// Weight Hub (User Story 1 & 3): hero plan card, trend chart with
/// actual-vs-projected lines, and a history log — or an empty state
/// prompting the user to set a goal (FR-001 – FR-003, FR-014 – FR-021).
class WeightHubScreen extends ConsumerWidget {
  const WeightHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weightGoalPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Goal'),
        actions: [
          if (plan != null)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Edit goal',
              onPressed: () => Navigator.of(context)
                  .push(glassRoute(const WeightGoalSetupScreen())),
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          if (plan == null)
            _EmptyState(onSetGoal: () => Navigator.of(context)
                .push(glassRoute(const WeightGoalSetupScreen())))
          else
            const _HubContent(),
        ],
      ),
      floatingActionButton: plan == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showWeighInSheet(context, ref),
              icon: const Icon(Icons.monitor_weight_outlined),
              label: const Text('Log weight'),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSetGoal;
  const _EmptyState({required this.onSetGoal});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Set a weight goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Get a personalized calorie target, macro split and a coach '
              'that keeps you on track.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onSetGoal, child: const Text('Set goal')),
          ],
        ),
      ),
    );
  }
}

class _HubContent extends ConsumerWidget {
  const _HubContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weightGoalPlanProvider)!;
    final progress = ref.watch(weightGoalProgressProvider);
    final weighIns = ref.watch(allBodyweightsProvider).valueOrNull ?? const [];
    final sorted = [...weighIns]..sort((a, b) => b.date.compareTo(a.date));
    final latest = sorted.isNotEmpty ? sorted.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _HeroCard(plan: plan, progress: progress, latest: latest),
        const SizedBox(height: 16),
        _TrendChartCard(progress: progress),
        const SizedBox(height: 16),
        _HistorySection(entries: sorted),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final WeightGoalPlan plan;
  final WeightGoalProgress progress;
  final BodyweightEntry? latest;
  const _HeroCard({required this.plan, required this.progress, this.latest});

  @override
  Widget build(BuildContext context) {
    final style = WeightGoalStatusStyle.of(progress.verdict);
    final fraction = (progress.progressFraction ?? 0).clamp(0.0, 1.0);
    final weeksLeft = progress.weeksRemaining;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest != null
                          ? '${latest!.weightKg.toStringAsFixed(1)} kg'
                          : '— kg',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.isMaintenance
                          ? 'Maintaining ${plan.targetWeightKg.toStringAsFixed(1)} kg'
                          : 'Goal: ${plan.targetWeightKg.toStringAsFixed(1)} kg '
                              'by ${DateFormat('d MMM').format(plan.targetDate)}',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              _StatusPill(style: style),
            ],
          ),
          const SizedBox(height: 16),
          if (!plan.isMaintenance) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(style.color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              weeksLeft != null
                  ? '${weeksLeft.ceil()} weeks left · '
                      '${(plan.targetWeightKg - (latest?.weightKg ?? plan.startWeightKg)).abs().toStringAsFixed(1)} kg to go'
                  : 'Log a weigh-in to see your progress',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 10),
          ],
          Text(progress.message, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final WeightGoalStatusStyle style;
  const _StatusPill({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(style.label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: style.color)),
        ],
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  final WeightGoalProgress progress;
  const _TrendChartCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final points = progress.chartPoints;
    if (points.length < 2) {
      return LiquidGlassContainer(
        borderRadius: 24,
        enableBlur: false,
        tintColor: const Color(0x26FFFFFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Log a couple more weigh-ins to see your trend chart.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ),
      );
    }

    // Plot on a date-proportional x-axis (days since the plan's start date)
    // rather than by list index, so points on the same calendar day sit at
    // the same x position and time spacing between weigh-ins is accurate.
    final chartStartDate = points.first.date;
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    double dayOffset(DateTime d) =>
        dateOnly(d).difference(dateOnly(chartStartDate)).inDays.toDouble();

    final actualSpots = <FlSpot>[];
    final projectedSpots = <FlSpot>[];
    for (final p in points) {
      final x = dayOffset(p.date);
      if (p.actualKg != null) actualSpots.add(FlSpot(x, p.actualKg!));
      projectedSpots.add(FlSpot(x, p.projectedKg));
    }

    final maxDayOffset =
        projectedSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    // Guard against a zero-width span (e.g. start date == target date) so
    // the chart always has a visible horizontal range.
    final chartMaxX = maxDayOffset <= 0 ? 1.0 : maxDayOffset;

    final allY = [
      ...actualSpots.map((s) => s.y),
      ...projectedSpots.map((s) => s.y),
    ];
    final rawMinY = allY.reduce((a, b) => a < b ? a : b);
    final rawMaxY = allY.reduce((a, b) => a > b ? a : b);
    var minY = rawMinY.floorToDouble() - 1;
    var maxY = rawMaxY.ceilToDouble() + 1;
    // Degenerate case: all weights equal (e.g. start weight == first
    // weigh-in) collapses the range to almost nothing — widen it to a
    // fixed span so the axis isn't crammed with repeated labels.
    if (maxY - minY < 4) {
      final mid = ((minY + maxY) / 2).roundToDouble();
      minY = mid - 2;
      maxY = mid + 2;
    }
    // Pick an integer gridline interval that yields ~3-5 distinct labels;
    // both bounds are already whole numbers, so labels never repeat.
    var yInterval = ((maxY - minY) / 4).ceil();
    if (yInterval < 1) yInterval = 1;
    final style = WeightGoalStatusStyle.of(progress.verdict);

    return LiquidGlassContainer(
      borderRadius: 24,
      enableBlur: false,
      tintColor: const Color(0x26FFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              const Text('Trend', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              _legendDot(const Color(0xFF38BDF8), 'Actual'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFF818CF8), 'Projected'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: chartMaxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: yInterval.toDouble(),
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      // ~4 labels spread evenly across the span, so the
                      // first (day 0) and last (chartMaxX) dates line up
                      // exactly with generated ticks.
                      interval: (chartMaxX / 3).clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) {
                        if (value < -0.001 || value > chartMaxX + 0.001) {
                          return const SizedBox.shrink();
                        }
                        final date = dateOnly(chartStartDate)
                            .add(Duration(days: value.round()));
                        return Text(
                          DateFormat('MMM d').format(date),
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: projectedSpots,
                    isCurved: false,
                    color: const Color(0xFF818CF8),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: actualSpots,
                    isCurved: true,
                    color: const Color(0xFF38BDF8),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isLast = index == actualSpots.length - 1;
                        return FlDotCirclePainter(
                          radius: isLast ? 4.5 : 2.5,
                          color: isLast ? style.color : const Color(0xFF38BDF8),
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _HistorySection extends ConsumerWidget {
  final List<BodyweightEntry> entries;
  const _HistorySection({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return GlassCard(
        child: Text('No weigh-ins logged yet.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < entries.length; i++)
            _HistoryRow(
              entry: entries[i],
              previous: i + 1 < entries.length ? entries[i + 1] : null,
              onDelete: () =>
                  ref.read(weightGoalActionsProvider).deleteWeighIn(entries[i].id),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final BodyweightEntry entry;
  final BodyweightEntry? previous;
  final VoidCallback onDelete;
  const _HistoryRow({required this.entry, this.previous, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final delta = previous != null ? entry.weightKg - previous!.weightKg : null;
    final deltaColor = delta == null
        ? Colors.white54
        : delta < -0.001
            ? const Color(0xFF38BDF8)
            : delta > 0.001
                ? const Color(0xFFFF9F0A)
                : Colors.white54;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Text(
        entry.weightKg.toStringAsFixed(1),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      title: Text(DateFormat('EEE, d MMM y').format(entry.date),
          style: const TextStyle(fontSize: 13)),
      subtitle: entry.notes != null && entry.notes!.isNotEmpty
          ? Text(entry.notes!, style: const TextStyle(fontSize: 11))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (delta != null)
            Text(
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: deltaColor),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.white.withValues(alpha: 0.4),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
