// lib/screens/home/widgets/weekly_progress_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/weekly_progress_data.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';

String _formatTonnageStatic(double kg) {
  if (kg >= 1000) {
    return '${(kg / 1000).toStringAsFixed(1)}k'.replaceAll('.0k', 'k');
  }
  return kg.toStringAsFixed(0);
}

class WeeklyProgressCard extends ConsumerWidget {
  const WeeklyProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(weeklyProgressProvider);

    return async.when(
      loading: () => _skeleton(isDark),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) => _card(context, isDark, data),
    );
  }

  Widget _skeleton(bool isDark) => LiquidGlassContainer(
        borderRadius: 18,
        blurSigma: 10,
        tintColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.80),
        padding: const EdgeInsets.all(14),
        child: const SizedBox(height: 160),
      );

  Widget _card(BuildContext context, bool isDark, WeeklyProgressData data) {
    return LiquidGlassContainer(
      borderRadius: 18,
      blurSigma: 10,
      tintColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.80),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WEEKLY PROGRESS'),
          const SizedBox(height: 10),
          _volumeHero(data),
          const SizedBox(height: 12),
          _sparkline(data.sparkline),
          const SizedBox(height: 14),
          _statsStrip(context, data),
          const _Divider(),
          const SizedBox(height: 12),
          _sectionLabel('MUSCLE BALANCE'),
          const SizedBox(height: 10),
          _muscleBalance(data),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0x4DFFFFFF),
        ),
      );

  Widget _volumeHero(WeeklyProgressData data) {
    final delta = data.tonnageDeltaPct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatTonnage(data.tonnageKg),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'vs ${_formatTonnage(data.lastWeekTonnageKg)} kg last week',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (delta != null) _trendPill(delta),
      ],
    );
  }

  Widget _trendPill(double pct) {
    final isUp = pct >= 0;
    final color = isUp ? const Color(0xFF34C759) : const Color(0xFFFF453A);
    final label = '${isUp ? '↑' : '↓'} ${pct.abs().toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatTonnage(double kg) => _formatTonnageStatic(kg);

  Widget _sparkline(List<double> weeks) {
    final maxVal = weeks.fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weeks.length, (i) {
          final isCurrent = i == weeks.length - 1;
          final frac = maxVal > 0 ? weeks[i] / maxVal : 0.0;
          final alpha = isCurrent ? 1.0 : (0.20 + (i / (weeks.length - 2)) * 0.20).clamp(0.20, 0.40);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: FractionallySizedBox(
                heightFactor: frac.clamp(0.05, 1.0),
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: alpha),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _statsStrip(BuildContext context, WeeklyProgressData data) {
    final tiles = <Widget>[
      _StripTile(
        value: '${data.sessionCount}',
        label: 'Sessions',
        delta: 'of ${data.plannedSessions} planned',
        deltaColor: Colors.white.withValues(alpha: 0.25),
      ),
    ];

    if (data.avgRpe != null) {
      final rpeDelta = data.lastWeekAvgRpe != null
          ? data.avgRpe! - data.lastWeekAvgRpe!
          : null;
      tiles.add(_StripTile(
        value: data.avgRpe!.toStringAsFixed(1),
        label: 'Avg RPE',
        delta: rpeDelta == null
            ? null
            : '${rpeDelta >= 0 ? '↑' : '↓'} from ${data.lastWeekAvgRpe!.toStringAsFixed(1)}',
        deltaColor: rpeDelta == null
            ? null
            : rpeDelta > 0
                ? const Color(0xFFFF9F0A)
                : const Color(0xFF34C759),
      ));
    }

    final setsDelta = data.totalSets - data.lastWeekTotalSets;
    tiles.add(_StripTile(
      value: '${data.totalSets}',
      label: 'Total Sets',
      delta: setsDelta == 0
          ? null
          : '${setsDelta > 0 ? '↑' : '↓'} ${setsDelta.abs()} sets',
      deltaColor: setsDelta >= 0
          ? const Color(0xFF34C759)
          : const Color(0xFFFF453A),
    ));

    return Row(
      children: tiles
          .expand((t) => [Expanded(child: t), const SizedBox(width: 6)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _muscleBalance(WeeklyProgressData data) {
    final max = data.maxGroupTonnage;
    return Column(
      children: [
        _MuscleBar(
          label: 'Push',
          tonnageKg: data.pushTonnageKg,
          sets: data.pushSets,
          color: const Color(0xFF6366F1),
          fraction: max > 0 ? data.pushTonnageKg / max : 0,
        ),
        const SizedBox(height: 7),
        _MuscleBar(
          label: 'Pull',
          tonnageKg: data.pullTonnageKg,
          sets: data.pullSets,
          color: const Color(0xFF32ADE6),
          fraction: max > 0 ? data.pullTonnageKg / max : 0,
        ),
        const SizedBox(height: 7),
        _MuscleBar(
          label: 'Legs',
          tonnageKg: data.legsTonnageKg,
          sets: data.legsSets,
          color: const Color(0xFF34C759),
          fraction: max > 0 ? data.legsTonnageKg / max : 0,
        ),
      ],
    );
  }
}

class _StripTile extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final Color? deltaColor;

  const _StripTile({
    required this.value,
    required this.label,
    this.delta,
    this.deltaColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              color: Colors.white.withValues(alpha: 0.30),
              letterSpacing: 0.4,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 3),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: deltaColor ?? Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleBar extends StatelessWidget {
  final String label;
  final double tonnageKg;
  final int sets;
  final Color color;
  final double fraction;

  const _MuscleBar({
    required this.label,
    required this.tonnageKg,
    required this.sets,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const SizedBox.expand(),
                  ),
                  if (fraction > 0)
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 72,
          child: Text(
            '${tonnageKg.toStringAsFixed(0)} kg',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 38,
          child: Text(
            '$sets sets',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.30),
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 14),
        color: Colors.white.withValues(alpha: 0.06),
      );
}
