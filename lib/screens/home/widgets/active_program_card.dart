import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/program_providers.dart';

class ActiveProgramCard extends ConsumerWidget {
  const ActiveProgramCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(activeProgramProvider);
    final phasesAsync = ref.watch(activePhasesProvider);
    final weekAsync = ref.watch(currentProgramWeekProvider);

    return programAsync.when(
      loading: () => const _CardSkeleton(),
      error: (e, _) => const SizedBox.shrink(),
      data: (program) {
        if (program == null) return const SizedBox.shrink();

        final phases = phasesAsync.valueOrNull ?? [];
        final totalWeeks = phases.fold(0, (s, p) => s + p.durationWeeks);
        final currentWeek = weekAsync.valueOrNull ?? 1;
        final progress =
            totalWeeks > 0 ? (currentWeek - 1) / totalWeeks : 0.0;

        // Find current phase
        String? phaseName;
        if (phases.length > 1) {
          int acc = 0;
          for (final ph in phases) {
            if (currentWeek <= acc + ph.durationWeeks) {
              phaseName = ph.name;
              break;
            }
            acc += ph.durationWeeks;
          }
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient accent bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.tertiary,
                    ],
                  ),
                ),
              ),
              Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        program.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (phaseName != null) ...[
                  const SizedBox(height: 4),
                  Text(phaseName,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Week $currentWeek of $totalWeeks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      '${totalWeeks - currentWeek} weeks remaining',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        );
      },
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(height: 100, padding: const EdgeInsets.all(16)),
    );
  }
}
