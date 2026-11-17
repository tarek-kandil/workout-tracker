import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/exercise_tracking_mode.dart';
import '../../providers/challenges_providers.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';
import 'challenge_attempt_sheet.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  final int challengeId;
  final Color accentColor;

  const ChallengeDetailScreen({
    super.key,
    required this.challengeId,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeList =
        ref.watch(activeChallengesProvider).valueOrNull ?? const [];
    final completedList =
        ref.watch(completedChallengesProvider).valueOrNull ?? const [];

    final data = [...activeList, ...completedList]
        .where((c) => c.challenge.id == challengeId)
        .firstOrNull;

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge')),
        body: const Stack(
          children: [
            Positioned.fill(child: GlassBackground()),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('🏁 ${data.exercise.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Challenge',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Challenge?'),
                  content: Text(
                      'Removes "${data.exercise.name}" challenge and all its attempts.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(ctx).colorScheme.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ref
                    .read(databaseProvider)
                    .challengesDao
                    .deleteChallenge(challengeId);
                ref.invalidate(activeChallengesProvider);
                ref.invalidate(completedChallengesProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            children: [
              // ── Hero Progress Card ─────────────────────────────────────────
              LiquidGlassContainer(
                borderRadius: 20,
                blurSigma: 10,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.challenge.isCompleted
                                ? 'COMPLETED CHALLENGE'
                                : 'CURRENT TARGET',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: accentColor,
                            ),
                          ),
                        ),
                        if (data.conqueredCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0xFFFBBF24)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              data.conqueredCount == 1
                                  ? '🏅 1 Target Conquered'
                                  : '🏅 ×${data.conqueredCount} Conquered',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BEST',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            Text(
                              data.bestLabel,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'GOAL',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              data.targetLabel,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: data.progressFraction,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!data.challenge.isCompleted)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  showChallengeAttemptSheet(context, ref, data),
                              style: FilledButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: const Color(0xFF082F49),
                              ),
                              icon: Icon(
                                data.mode == ExerciseTrackingMode.timed
                                    ? Icons.timer_rounded
                                    : Icons.add_rounded,
                              ),
                              label: const Text(
                                'Log Attempt',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        if (!data.challenge.isCompleted)
                          const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showExtendChallengeDialog(context, ref, data),
                            icon: const Icon(Icons.trending_up_rounded, size: 18),
                            label: Text(
                              data.challenge.isCompleted
                                  ? 'Reopen & Extend'
                                  : 'Extend Target',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Conquered Milestones ───────────────────────────────────────
              if (data.milestones.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'CONQUERED CHECKPOINTS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in data.milestones)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFBBF24).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFBBF24)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          '🏅 ${_fmtMilestone(data.mode, m)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              // ── Attempt Log ────────────────────────────────────────────────
              const SizedBox(height: 20),
              Text(
                'ATTEMPTS (${data.attempts.length})',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 8),
              if (data.attempts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No attempts logged yet — tap Log Attempt to start!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                )
              else
                for (final a in data.attempts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlassContainer(
                      borderRadius: 14,
                      blurSigma: 8,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          if (data.bestAttempt?.id == a.id)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text('🏆', style: TextStyle(fontSize: 15)),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.formatAttempt(a),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _fmtDate(a.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (data.isTargetMetBy(a))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Target ✓',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.35)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () async {
                              await ref
                                  .read(databaseProvider)
                                  .challengesDao
                                  .deleteAttempt(a.id);
                              ref.invalidate(activeChallengesProvider);
                              ref.invalidate(completedChallengesProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtMilestone(ExerciseTrackingMode mode, dynamic m) {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return fmtChallengeSec(m.targetDurationSeconds ?? 0);
      case ExerciseTrackingMode.bodyweightReps:
        return '${m.targetReps ?? 0} reps';
      case ExerciseTrackingMode.weightedReps:
        final w = fmtChallengeKg(m.targetWeightKg ?? 0);
        final r = m.targetReps ?? 1;
        return r == 1 ? '$w kg' : '$w kg × $r';
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
