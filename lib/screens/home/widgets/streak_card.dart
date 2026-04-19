import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../../widgets/vibrant_text.dart';

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(workoutStreakProvider);

    return LiquidGlassContainer(
      borderRadius: 28,
      blurSigma: 12,
      padding: EdgeInsets.zero,
      // Left border replaces IntrinsicHeight + Row pattern — avoids the
      // two-pass layout conflict that fires !parentDataDirty inside BackdropFilter
      child: Container(
        padding: const EdgeInsets.all(16),
        child: streakAsync.when(
          loading: () => const Text('Calculating streak...'),
          error: (e, _) => const SizedBox.shrink(),
          data: (streak) => Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.deepOrange, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    streak == 0
                        ? Text(
                            'No streak yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              VibrantText(
                                '$streak',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium!
                                    .copyWith(fontWeight: FontWeight.w900),
                                gradientColors: const [
                                  Colors.deepOrange,
                                  Color(0xFFFFB347),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'week${streak == 1 ? '' : 's'} streak',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                    const SizedBox(height: 2),
                    Text(
                      streak == 0
                          ? 'Complete all WODs in a week to start your streak.'
                          : 'Keep it up — complete all WODs this week to extend it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
