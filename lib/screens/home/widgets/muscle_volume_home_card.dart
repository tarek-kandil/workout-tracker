import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/weekly_muscle_volume.dart';
import '../../../providers/muscle_volume_provider.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/glass_route.dart';
import '../../../widgets/volume_status_pill.dart';
import '../../reports/weekly_muscle_report_screen.dart';

/// Home-screen tile (design.md §4.1): full-width "Muscle Volume" entry
/// point, placed after the stat row and before [WeightGoalCard]. Tapping
/// opens [WeeklyMuscleReportScreen].
class MuscleVolumeHomeCard extends ConsumerWidget {
  const MuscleVolumeHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(weeklyMuscleVolumeProvider);
    final unmappedAsync = ref.watch(unmappedExerciseCountProvider);

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(glassRoute(const WeeklyMuscleReportScreen())),
      child: SizedBox(
        height: 140,
        child: GlassCard(
          child: reportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const _TileError(),
            data: (report) => _TileBody(
              report: report,
              unmappedCount: unmappedAsync.valueOrNull ?? 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _TileError extends StatelessWidget {
  const _TileError();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.radar_rounded, size: 32, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 14),
        Expanded(
          child: Text('Could not load muscle volume',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        ),
      ],
    );
  }
}

class _TileBody extends StatelessWidget {
  final List<WeeklyMuscleVolume> report;
  final int unmappedCount;
  const _TileBody({required this.report, required this.unmappedCount});

  @override
  Widget build(BuildContext context) {
    final under =
        report.where((m) => m.status == MuscleVolumeStatus.undertrained).length;
    final over =
        report.where((m) => m.status == MuscleVolumeStatus.overtrained).length;
    final optimal = report.length - under - over;
    final hasAnyVolume = report.any((m) => m.effectiveSets > 0);

    final String title;
    final String subtitle;
    if (!hasAnyVolume) {
      title = 'No volume this week';
      subtitle = 'Open the report to plan your next week';
    } else if (under == 0 && over == 0) {
      title = 'All optimal';
      subtitle = 'Last 7 days · keep the plan rolling';
    } else {
      title = '$under undertrained · $over overtrained';
      subtitle = 'Rest optimal · last 7 days';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text('WEEKLY MUSCLE VOLUME',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
        const Spacer(),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (under > 0) _MiniStatChip(count: under, status: MuscleVolumeStatus.undertrained),
            if (over > 0) _MiniStatChip(count: over, status: MuscleVolumeStatus.overtrained),
            if (optimal > 0) _MiniStatChip(count: optimal, status: MuscleVolumeStatus.optimal),
            if (unmappedCount > 0) _UnmappedChip(count: unmappedCount),
          ],
        ),
      ],
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  final int count;
  final MuscleVolumeStatus status;
  const _MiniStatChip({required this.count, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = VolumeStatusStyle.of(status, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: style.color),
          const SizedBox(width: 4),
          Text('$count ${style.label}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: style.color)),
        ],
      ),
    );
  }
}

class _UnmappedChip extends StatelessWidget {
  final int count;
  const _UnmappedChip({required this.count});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count unmapped',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: amber)),
    );
  }
}
