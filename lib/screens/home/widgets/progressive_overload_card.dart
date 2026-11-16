import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';

class ProgressiveOverloadCard extends ConsumerWidget {
  const ProgressiveOverloadCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressiveOverloadProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return async.when(
      loading: () => LiquidGlassContainer(
        borderRadius: 18,
        blurSigma: 10,
        tintColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.80),
        padding: const EdgeInsets.all(14),
        child: const SizedBox(height: 120),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) => _OverloadBody(summary: summary, isDark: isDark),
    );
  }
}

class _OverloadBody extends StatelessWidget {
  final ProgressiveOverloadSummary summary;
  final bool isDark;
  const _OverloadBody({required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = summary.totalCompared;
    final hasComparisons = total > 0;
    final vsW1 = summary.vsWeek1Pct;

    return LiquidGlassContainer(
      borderRadius: 18,
      blurSigma: 10,
      tintColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.80),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + vs Week 1 Pill ──────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PROGRESSIVE OVERLOAD · THIS WEEK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white54,
                  ),
                ),
              ),
              if (vsW1 != null)
                _VsWeek1Pill(pct: vsW1)
              else if (summary.firstTimeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Baseline Week',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Hero Score + Mini Week Bars ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: hasComparisons
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${summary.overloadRatePct}%',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${summary.progressedCount} of $total exercises progressed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Compared to each exercise's previous session",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.38),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.firstTimeCount > 0
                                ? '${summary.firstTimeCount} baseline exercise${summary.firstTimeCount == 1 ? '' : 's'} logged'
                                : 'No workouts logged this week',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.firstTimeCount > 0
                                ? 'Next rotation will score your progression against these sets'
                                : 'Complete a session to track weight & rep overload',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
              ),
              if (summary.weekBars.length >= 2) ...[
                const SizedBox(width: 12),
                _MiniWeekBars(bars: summary.weekBars),
              ],
            ],
          ),

          if (hasComparisons) ...[
            const SizedBox(height: 14),
            // ── 4-Color Segmented Progress Bar ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (summary.weightUpCount > 0)
                      Expanded(
                        flex: summary.weightUpCount,
                        child: Container(color: const Color(0xFF34D399)),
                      ),
                    if (summary.repsOrTimeUpCount > 0)
                      Expanded(
                        flex: summary.repsOrTimeUpCount,
                        child: Container(
                          margin: const EdgeInsets.only(left: 2),
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    if (summary.heldCount > 0)
                      Expanded(
                        flex: summary.heldCount,
                        child: Container(
                          margin: const EdgeInsets.only(left: 2),
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    if (summary.droppedCount > 0)
                      Expanded(
                        flex: summary.droppedCount,
                        child: Container(
                          margin: const EdgeInsets.only(left: 2),
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Breakdown Pills ────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _BucketPill(
                  label: '↑ ${summary.weightUpCount} Weight Up',
                  color: const Color(0xFF34D399),
                ),
                _BucketPill(
                  label: '↑ ${summary.repsOrTimeUpCount} Reps/Time Up',
                  color: const Color(0xFF38BDF8),
                ),
                _BucketPill(
                  label: '= ${summary.heldCount} Held',
                  color: const Color(0xFF818CF8),
                ),
                if (summary.droppedCount > 0)
                  _BucketPill(
                    label: '↓ ${summary.droppedCount} Dropped',
                    color: const Color(0xFFFBBF24),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VsWeek1Pill extends StatelessWidget {
  final double pct;
  const _VsWeek1Pill({required this.pct});

  @override
  Widget build(BuildContext context) {
    final isUp = pct >= 0;
    final color = isUp ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final sign = isUp ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '${isUp ? '↑' : '↓'} $sign${pct.toStringAsFixed(1)}% vs Week 1',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _BucketPill extends StatelessWidget {
  final String label;
  final Color color;
  const _BucketPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MiniWeekBars extends StatelessWidget {
  final List<({int week, double pctGain})> bars;
  const _MiniWeekBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    final maxGain =
        bars.map((b) => b.pctGain.abs()).fold(1.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Builder(builder: (context) {
              final b = bars[i];
              final isLast = i == bars.length - 1;
              final normalized =
                  ((b.pctGain.clamp(0.0, maxGain)) / maxGain).clamp(0.0, 1.0);
              final barH = 10.0 + normalized * 18.0;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 12,
                    height: barH,
                    decoration: BoxDecoration(
                      color: isLast
                          ? const Color(0xFF34D399)
                          : const Color(0xFF818CF8)
                              .withValues(alpha: 0.35 + 0.15 * i),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'W${b.week}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                      color: isLast
                          ? const Color(0xFF34D399)
                          : Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}
