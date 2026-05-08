// lib/screens/home/widgets/weekly_pr_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';

class WeeklyPRCard extends ConsumerWidget {
  const WeeklyPRCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyPRsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.30)),
                ),
                child: Text(
                  '🏆 ${prs.length} PR${prs.length == 1 ? '' : 's'} this week',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9F0A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // PR rows
              ...prs.asMap().entries.map((entry) {
                final i = entry.key;
                final pr = entry.value;
                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF9F0A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pr.exerciseName,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${pr.weightKg.truncateToDouble() == pr.weightKg ? pr.weightKg.toInt() : pr.weightKg} kg × ${pr.reps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F0A)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PR',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9F0A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < prs.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 7),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
