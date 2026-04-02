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

    final accentColor = isDone ? Colors.green : Theme.of(context).colorScheme.primary;

    return LiquidGlassContainer(
      borderRadius: 20,
      blurSigma: 12,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: isDone ? 0.5 : 0.9),
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white.withValues(alpha: 0.4),
                        ),
                  ),
                  if (task.reminderHour != null &&
                      task.reminderMinute != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${task.reminderHour.toString().padLeft(2, '0')}:${task.reminderMinute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.35),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Colors.green.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isDone
                        ? Colors.green.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.green)
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
