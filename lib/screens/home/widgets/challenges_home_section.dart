import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/exercise_tracking_mode.dart';
import '../../../providers/challenges_providers.dart';
import '../../../widgets/glass_route.dart';
import '../../challenges/challenge_attempt_sheet.dart';
import '../../challenges/challenge_detail_screen.dart';
import '../../challenges/create_challenge_flow.dart';

class ChallengesHomeSection extends ConsumerWidget {
  const ChallengesHomeSection({super.key});

  static const _cardColors = [
    Color(0xFF38BDF8), // Electric Cyan
    Color(0xFF34D399), // Emerald Green
    Color(0xFFA78BFA), // Vibrant Violet
    Color(0xFFFB923C), // Warm Amber/Orange
    Color(0xFFFB7185), // Coral Rose
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeChallengesProvider);
    final completedAsync = ref.watch(completedChallengesProvider);

    final active = activeAsync.valueOrNull ?? const <ChallengeViewData>[];
    final completed =
        completedAsync.valueOrNull ?? const <ChallengeViewData>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '🏁 CHALLENGES',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            if (completed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _showCompletedSheet(context, completed),
                  child: Text(
                    'Done (${completed.length})',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            // Crisp Frosted White "+ New" pill (distinct from tile colors)
            GestureDetector(
              onTap: () => showCreateChallengeFlow(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'New',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (active.isEmpty)
          GestureDetector(
            onTap: () => showCreateChallengeFlow(context, ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  const Text('🏁', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start a Personal Challenge',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Track ad-hoc goals like Dead Hang 2:00 or 20 Pull-ups',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ),
            ),
          )
        else if (active.length <= 2)
          Row(
            children: [
              for (int i = 0; i < active.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _NeonRingChallengeCard(
                    data: active[i],
                    accentColor: _cardColors[i % _cardColors.length],
                  ),
                ),
              ],
            ],
          )
        else
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: active.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(
                width: 168,
                child: _NeonRingChallengeCard(
                  data: active[i],
                  accentColor: _cardColors[i % _cardColors.length],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showCompletedSheet(
    BuildContext context,
    List<ChallengeViewData> completed,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '🏅 Completed Challenges',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final c in completed)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                leading: const Text('🏅', style: TextStyle(fontSize: 22)),
                title: Text(c.exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Goal hit: ${c.targetLabel} · Best: ${c.bestLabel}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6))),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    glassRoute(ChallengeDetailScreen(
                      challengeId: c.challenge.id,
                      accentColor: const Color(0xFF34D399),
                    )),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _NeonRingChallengeCard extends ConsumerWidget {
  final ChallengeViewData data;
  final Color accentColor;

  const _NeonRingChallengeCard({
    required this.data,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTimed = data.mode == ExerciseTrackingMode.timed;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        glassRoute(ChallengeDetailScreen(
          challengeId: data.challenge.id,
          accentColor: accentColor,
        )),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.22),
              accentColor.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.44),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Corner Medal Badge when targets have been conquered
            if (data.conqueredCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    data.conqueredCount == 1
                        ? '🏅'
                        : '🏅×${data.conqueredCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: data.progressFraction,
                          strokeWidth: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${data.progressPct}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.compactProgressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => showChallengeAttemptSheet(context, ref, data),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      isTimed ? '⏱ Attempt' : '+ Attempt',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF082F49),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
