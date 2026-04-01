import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/daily_tasks_providers.dart';
import '../../../providers/shell_providers.dart';

class DailyTasksCard extends ConsumerWidget {
  const DailyTasksCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(dailyTasksProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final streakAsync = ref.watch(dailyTaskStreakProvider);

    final tasks = tasksAsync.valueOrNull ?? [];
    final completions = completionsAsync.valueOrNull ?? {};
    final streak = streakAsync.valueOrNull ?? 0;

    final enabledTasks = tasks.where((t) => t.isEnabled).toList();
    final total = enabledTasks.length;
    final done = enabledTasks.where((t) => completions.contains(t.id)).length;
    final allDone = total > 0 && done == total;

    final scheme = Theme.of(context).colorScheme;
    final accentColor = allDone ? Colors.green : scheme.primary;

    return GestureDetector(
      onTap: () => ref.read(shellIndexProvider.notifier).state = 3,
      child: Card(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            allDone
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 18,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Daily Tasks',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const Spacer(),
                          if (streak > 0)
                            _StreakBadge(streak: streak, allDone: allDone),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (total == 0)
                        Text(
                          'No active tasks',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                        )
                      else ...[
                        Row(
                          children: [
                            Text(
                              allDone ? 'All done!' : '$done of $total done',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: allDone
                                        ? Colors.green
                                        : Colors.white
                                            .withValues(alpha: 0.9),
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              '${((done / total) * 100).round()}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? done / total : 0,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  final bool allDone;

  const _StreakBadge({required this.streak, required this.allDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepOrange.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
