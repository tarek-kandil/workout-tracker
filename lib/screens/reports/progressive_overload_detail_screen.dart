import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/home_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';

class ProgressiveOverloadDetailScreen extends ConsumerStatefulWidget {
  final OverloadBucket? initialFilter;
  const ProgressiveOverloadDetailScreen({super.key, this.initialFilter});

  @override
  ConsumerState<ProgressiveOverloadDetailScreen> createState() =>
      _ProgressiveOverloadDetailScreenState();
}

class _ProgressiveOverloadDetailScreenState
    extends ConsumerState<ProgressiveOverloadDetailScreen> {
  late OverloadBucket? _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(progressiveOverloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progressive Overload'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (summary) => _buildContent(context, summary),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ProgressiveOverloadSummary summary) {
    final items = _filter == null
        ? summary.items
        : summary.items.where((i) => i.bucket == _filter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        // ── Summary Header Card ──────────────────────────────────────────
        LiquidGlassContainer(
          borderRadius: 18,
          blurSigma: 10,
          tintColor: Colors.white.withValues(alpha: 0.07),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'LAST 7 DAYS SUMMARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  if (summary.vsWeek1Pct != null)
                    _VsWeek1Badge(pct: summary.vsWeek1Pct!),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${summary.overloadRatePct}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${summary.progressedCount} of ${summary.totalCompared} compared exercises progressed',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Filter Chips ───────────────────────────────────────────
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All (${summary.items.length})',
                    color: Colors.white,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  _FilterChip(
                    label: '↑ Weight Up (${summary.weightUpCount})',
                    color: const Color(0xFF34D399),
                    selected: _filter == OverloadBucket.weightUp,
                    onTap: () =>
                        setState(() => _filter = OverloadBucket.weightUp),
                  ),
                  _FilterChip(
                    label: '↑ Reps/Time Up (${summary.repsOrTimeUpCount})',
                    color: const Color(0xFF38BDF8),
                    selected: _filter == OverloadBucket.repsOrTimeUp,
                    onTap: () =>
                        setState(() => _filter = OverloadBucket.repsOrTimeUp),
                  ),
                  _FilterChip(
                    label: '= Held (${summary.heldCount})',
                    color: const Color(0xFF818CF8),
                    selected: _filter == OverloadBucket.held,
                    onTap: () => setState(() => _filter = OverloadBucket.held),
                  ),
                  _FilterChip(
                    label: '↓ Dropped (${summary.droppedCount})',
                    color: const Color(0xFFFBBF24),
                    selected: _filter == OverloadBucket.dropped,
                    onTap: () =>
                        setState(() => _filter = OverloadBucket.dropped),
                  ),
                  if (summary.firstTimeCount > 0)
                    _FilterChip(
                      label: 'Baseline (${summary.firstTimeCount})',
                      color: const Color(0xFFA78BFA),
                      selected: _filter == OverloadBucket.firstTime,
                      onTap: () =>
                          setState(() => _filter = OverloadBucket.firstTime),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No exercises in this category this week.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ),
          )
        else
          for (final item in items) ...[
            _ExerciseOverloadTile(item: item),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? color : Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

class _ExerciseOverloadTile extends StatelessWidget {
  final ExerciseOverloadItem item;
  const _ExerciseOverloadTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (Color accent, Color bgTint, String tag) = switch (item.bucket) {
      OverloadBucket.weightUp => (
          const Color(0xFF34D399),
          const Color(0xFF064E3B),
          '↑ WEIGHT'
        ),
      OverloadBucket.repsOrTimeUp => (
          const Color(0xFF38BDF8),
          const Color(0xFF0C4A6E),
          item.exercise.isTimed ? '↑ TIME' : '↑ REPS'
        ),
      OverloadBucket.held => (
          const Color(0xFF818CF8),
          const Color(0xFF1E1B4B),
          'HOLD'
        ),
      OverloadBucket.dropped => (
          const Color(0xFFFBBF24),
          const Color(0xFF451A03),
          '↓ DROPPED'
        ),
      OverloadBucket.firstTime => (
          const Color(0xFFA78BFA),
          const Color(0xFF2E1065),
          'NEW'
        ),
    };

    return LiquidGlassContainer(
      borderRadius: 16,
      blurSigma: 8,
      tintColor: Colors.white.withValues(alpha: 0.06),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.exercise.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // Option 3 style status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                decoration: BoxDecoration(
                  color: bgTint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.deltaLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SetComparisonBox(
                label: 'THIS SESSION',
                value: item.currentSummary,
                accentColor: accent,
                highlight: true,
              ),
              const SizedBox(width: 8),
              if (item.previousSummary != null)
                _SetComparisonBox(
                  label: 'PREVIOUS SESSION',
                  value: item.previousSummary!,
                  accentColor: Colors.white54,
                  highlight: false,
                ),
              const Spacer(),
              if (item.vsWeek1Pct != null)
                _VsWeek1Badge(pct: item.vsWeek1Pct!),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetComparisonBox extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final bool highlight;

  const _SetComparisonBox({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? accentColor.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? accentColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlight ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _VsWeek1Badge extends StatelessWidget {
  final double pct;
  const _VsWeek1Badge({required this.pct});

  @override
  Widget build(BuildContext context) {
    final isUp = pct >= 0;
    final color = isUp ? const Color(0xFF34D399) : const Color(0xFFFBBF24);
    final sign = isUp ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        '$sign${pct.toStringAsFixed(1)}% vs W1',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
