import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/daily_tasks_providers.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../../widgets/celebration_overlay.dart';

class DailyTaskHomeCard extends ConsumerWidget {
  final DailyTask task;
  const DailyTaskHomeCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final completions = completionsAsync.valueOrNull ?? {};
    final isDone = completions.contains(task.id);

    final cs = Theme.of(context).colorScheme;
    final textColor = cs.onSurface.withValues(alpha: isDone ? 0.38 : 0.9);

    return LiquidGlassContainer(
      borderRadius: 22,
      blurSigma: 10,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: cs.onSurface.withValues(alpha: 0.3),
                        ),
                  ),
                  if (task.reminderHour != null &&
                      task.reminderMinute != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${task.reminderHour.toString().padLeft(2, '0')}:${task.reminderMinute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.35),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final dao = ref.read(databaseProvider).dailyTasksDao;
                if (isDone) {
                  await dao.setCompletion(task.id, false);
                } else {
                  await dao.setCompletion(task.id, true);
                  if (context.mounted) showTaskDoneFlash(context);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Colors.green.withValues(alpha: 0.2)
                      : cs.onSurface.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isDone
                        ? Colors.green.withValues(alpha: 0.7)
                        : cs.onSurface.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.green)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
