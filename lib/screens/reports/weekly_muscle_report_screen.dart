import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/weekly_muscle_volume.dart';
import '../../providers/muscle_volume_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/volume_status_pill.dart';
import '../settings/exercise_library_screen.dart';

/// FR-007/FR-012/FR-014, design.md §4: the athlete-facing Weekly Muscle
/// Volume report. Shows a summary hero, an unmapped-exercises banner, a
/// needs-attention shortlist, then all 21 muscles grouped by body region.
/// Never shows MV/MEV/MAV/MRV jargon in the main list — only via the
/// optional "What does this mean?" info affordance / detail sheet.
class WeeklyMuscleReportScreen extends ConsumerWidget {
  const WeeklyMuscleReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(weeklyMuscleVolumeProvider);
    final unmappedAsync = ref.watch(unmappedExerciseCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Volume'),
        actions: [
          IconButton(
            tooltip: 'What does this mean?',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfoSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          reportAsync.when(
            loading: () => const _LoadingBody(),
            error: (e, _) => _ErrorBody(
              onRetry: () => ref.invalidate(weeklyMuscleVolumeProvider),
            ),
            data: (report) => _ReportBody(
              report: report,
              unmappedCount: unmappedAsync.valueOrNull ?? 0,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('What does this mean?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'This report estimates useful weekly work for each muscle. '
              'Primary muscles count as 1 set. Secondary muscles count as '
              '0.5. Very easy sets count less. Each muscle is then marked '
              'Undertrained, Optimal, or Overtrained based on the app\'s '
              'built-in weekly ranges.',
              style: TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              'These are coaching signals, not medical diagnoses. If this '
              'is an intentional deload, seeing more Undertrained muscles '
              'can be expected.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        SizedBox(
          height: 150,
          child: GlassCard(
              child: Container(color: Colors.white.withValues(alpha: 0.03))),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          SizedBox(
            height: 90,
            child: GlassCard(
                child:
                    Container(color: Colors.white.withValues(alpha: 0.03))),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load muscle volume',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Try again. Your workout history is unchanged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final List<WeeklyMuscleVolume> report;
  final int unmappedCount;
  const _ReportBody({required this.report, required this.unmappedCount});

  @override
  Widget build(BuildContext context) {
    final under =
        report.where((m) => m.status == MuscleVolumeStatus.undertrained).toList();
    final over =
        report.where((m) => m.status == MuscleVolumeStatus.overtrained).toList();
    final hasAnyVolume = report.any((m) => m.effectiveSets > 0);

    // Needs-attention: overtrained first (most-above-range first), then
    // undertrained (farthest-below-range first) — design.md §4.5.
    final attention = [
      ...over..sort((a, b) =>
          (b.effectiveSets - b.landmark.mrv).compareTo(a.effectiveSets - a.landmark.mrv)),
      ...under..sort((a, b) =>
          (a.effectiveSets - a.landmark.mev).compareTo(b.effectiveSets - b.landmark.mev)),
    ].take(5).toList();

    final byRegion = <String, List<WeeklyMuscleVolume>>{};
    for (final region in kMusclesByRegion.keys) {
      byRegion[region] =
          report.where((m) => m.region == region).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _SummaryHero(
          under: under.length,
          optimal: report.length - under.length - over.length,
          over: over.length,
          hasAnyVolume: hasAnyVolume,
        ),
        if (unmappedCount > 0) ...[
          const SizedBox(height: 16),
          _UnmappedBanner(count: unmappedCount),
        ],
        if (attention.isNotEmpty) ...[
          const SizedBox(height: 16),
          _NeedsAttentionCard(items: attention),
        ],
        const SizedBox(height: 20),
        for (final entry in byRegion.entries) ...[
          _RegionSectionHeader(region: entry.key, muscles: entry.value),
          const SizedBox(height: 8),
          for (final m in entry.value) ...[
            _MuscleRow(volume: m),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => _showInfoRow(context),
            icon: const Icon(Icons.info_outline_rounded, size: 16),
            label: const Text('What does this mean?'),
          ),
        ),
      ],
    );
  }

  void _showInfoRow(BuildContext context) {
    // Reuses the same info sheet as the AppBar action.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('What does this mean?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            Text(
              'This report estimates useful weekly work for each muscle. '
              'Primary muscles count as 1 set. Secondary muscles count as '
              '0.5. Very easy sets count less. Circuit rounds count each '
              'completed exercise inside the circuit.',
              style: TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHero extends StatelessWidget {
  final int under;
  final int optimal;
  final int over;
  final bool hasAnyVolume;
  const _SummaryHero({
    required this.under,
    required this.optimal,
    required this.over,
    required this.hasAnyVolume,
  });

  @override
  Widget build(BuildContext context) {
    final String summary;
    final String supporting;
    if (!hasAnyVolume) {
      summary = 'No workouts in the last 7 days';
      supporting =
          'Every muscle starts at zero. Use this as a deload check or plan your next session.';
    } else if (under == 0 && over == 0) {
      summary = 'All optimal';
      supporting = 'Your muscle volume is balanced this week.';
    } else {
      summary = '$under undertrained · $over overtrained · rest optimal';
      supporting =
          'Start with the muscles flagged below before changing the whole plan.';
    }

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 DAYS',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text(summary,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text(supporting,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                  label: 'Undertrained',
                  count: under,
                  status: MuscleVolumeStatus.undertrained),
              const SizedBox(width: 10),
              _StatTile(
                  label: 'Optimal',
                  count: optimal,
                  status: MuscleVolumeStatus.optimal),
              const SizedBox(width: 10),
              _StatTile(
                  label: 'Overtrained',
                  count: over,
                  status: MuscleVolumeStatus.overtrained),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final MuscleVolumeStatus status;
  const _StatTile(
      {required this.label, required this.count, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = VolumeStatusStyle.of(status, Theme.of(context).brightness);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(style.icon, size: 16, color: style.color),
            const SizedBox(height: 4),
            Text('$count',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: style.color)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: style.color.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }
}

class _UnmappedBanner extends StatelessWidget {
  final int count;
  const _UnmappedBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    final plural = count == 1 ? '' : 's';
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(glassRoute(const ExerciseLibraryScreen())),
      child: GlassCard(
        borderRadius: 20,
        tintColor: amber.withValues(alpha: 0.10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_late_rounded, color: amber, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count exercise$plural need muscle assignment',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('They are not counted in muscle volume until reviewed.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  const Text('Review assignments',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: amber)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedsAttentionCard extends StatelessWidget {
  final List<WeeklyMuscleVolume> items;
  const _NeedsAttentionCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEEDS ATTENTION',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withValues(alpha: 0.4))),
          const SizedBox(height: 10),
          for (final m in items) ...[
            _AttentionRow(volume: m),
            if (m != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final WeeklyMuscleVolume volume;
  const _AttentionRow({required this.volume});

  String get _nextStep {
    switch (volume.status) {
      case MuscleVolumeStatus.undertrained:
        return 'Add a few sets next time this area appears.';
      case MuscleVolumeStatus.overtrained:
        return 'Reduce sets or keep the next session easier.';
      case MuscleVolumeStatus.optimal:
        return 'Keep this area about where it is.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = volume.effectiveSets == volume.effectiveSets.roundToDouble()
        ? volume.effectiveSets.toInt().toString()
        : volume.effectiveSets.toStringAsFixed(1);
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(volume.muscle,
                    style:
                        const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('$count sets',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                const SizedBox(height: 4),
                Text(_nextStep,
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          VolumeStatusPill(status: volume.status),
        ],
      ),
    );
  }
}

class _RegionSectionHeader extends StatelessWidget {
  final String region;
  final List<WeeklyMuscleVolume> muscles;
  const _RegionSectionHeader({required this.region, required this.muscles});

  @override
  Widget build(BuildContext context) {
    final under = muscles
        .where((m) => m.status == MuscleVolumeStatus.undertrained)
        .length;
    final over =
        muscles.where((m) => m.status == MuscleVolumeStatus.overtrained).length;
    final optimal = muscles.length - under - over;

    final parts = <String>[];
    if (over > 0) parts.add('$over OVERTRAINED');
    if (under > 0) parts.add('$under UNDERTRAINED');
    parts.add('$optimal OPTIMAL');

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Text(
        '${region.toUpperCase()} · ${parts.join(' · ')}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final WeeklyMuscleVolume volume;
  const _MuscleRow({required this.volume});

  @override
  Widget build(BuildContext context) {
    final count = volume.effectiveSets == volume.effectiveSets.roundToDouble()
        ? volume.effectiveSets.toInt().toString()
        : volume.effectiveSets.toStringAsFixed(1);
    return Semantics(
      label: '${volume.muscle}, $count sets this week, '
          '${VolumeStatusStyle.of(volume.status, Theme.of(context).brightness).label}.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailSheet(context, volume),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(volume.muscle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('This week · $count sets',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                VolumeStatusPill(status: volume.status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, WeeklyMuscleVolume volume) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          final style =
              VolumeStatusStyle.of(volume.status, Theme.of(ctx).brightness);
          final count =
              volume.effectiveSets == volume.effectiveSets.roundToDouble()
                  ? volume.effectiveSets.toInt().toString()
                  : volume.effectiveSets.toStringAsFixed(1);
          final String guidance;
          switch (volume.status) {
            case MuscleVolumeStatus.undertrained:
              guidance =
                  'Add a few effective sets if this muscle is a priority this week.';
              break;
            case MuscleVolumeStatus.optimal:
              guidance = 'Keep this area about where it is.';
              break;
            case MuscleVolumeStatus.overtrained:
              guidance = 'Pull back or give this area more recovery.';
              break;
          }
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(volume.muscle,
                  style:
                      const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(style.icon, size: 16, color: style.color),
                  const SizedBox(width: 6),
                  Text('$count sets this week · ${style.label}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: style.color)),
                ],
              ),
              const SizedBox(height: 12),
              Text(guidance, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 20),
              Text('YOUR WEEK VS HEALTHY RANGE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(height: 10),
              _RangeBar(volume: volume),
              const SizedBox(height: 20),
              Text(
                'Primary muscles count more than secondary muscles.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 6),
              Text(
                'Very easy sets count less.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 6),
              Text(
                'Circuit rounds count each completed exercise inside the circuit.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Simple three-zone "Low / Good / High" range bar (design.md §4.8). Never
/// labels the underlying MV/MEV/MAV/MRV thresholds.
class _RangeBar extends StatelessWidget {
  final WeeklyMuscleVolume volume;
  const _RangeBar({required this.volume});

  @override
  Widget build(BuildContext context) {
    final style = VolumeStatusStyle.of(volume.status, Theme.of(context).brightness);
    final landmark = volume.landmark;
    final maxScale = (landmark.mrv * 1.3).clamp(landmark.mrv + 1, double.infinity);
    final lowFraction = (landmark.mev / maxScale).clamp(0.0, 1.0);
    final goodFraction = ((landmark.mrv - landmark.mev) / maxScale).clamp(0.0, 1.0);
    final markerFraction = (volume.effectiveSets / maxScale).clamp(0.0, 1.0);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Expanded(
                    flex: (lowFraction * 1000).round().clamp(1, 100000),
                    child: Container(
                        height: 14,
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.35)),
                  ),
                  Expanded(
                    flex: (goodFraction * 1000).round().clamp(1, 100000),
                    child: Container(
                        height: 14,
                        color: const Color(0xFF34D399).withValues(alpha: 0.35)),
                  ),
                  Expanded(
                    flex: ((1 - lowFraction - goodFraction) * 1000)
                        .round()
                        .clamp(1, 100000),
                    child: Container(
                        height: 14,
                        color: const Color(0xFFE11D48).withValues(alpha: 0.35)),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              child: LayoutBuilder(
                builder: (ctx, constraints) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (constraints.maxWidth * markerFraction - 6)
                          .clamp(0.0, constraints.maxWidth - 12),
                      top: -3,
                      child: Icon(style.markerIcon, size: 20, color: style.color),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Low',
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
            Text('Good',
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
            Text('High',
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 4),
        Text('You are here',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: style.color)),
      ],
    );
  }
}
