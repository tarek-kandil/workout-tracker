import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/daily_tasks_providers.dart';
import '../../../utils/task_icons.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../../widgets/celebration_overlay.dart';

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class DailyTaskHomeCard extends ConsumerWidget {
  final DailyTask task;
  const DailyTaskHomeCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionsAsync = ref.watch(todayCompletionsProvider);
    final completions = completionsAsync.valueOrNull ?? {};
    final isDone = completions.contains(task.id);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = cs.onSurface.withValues(alpha: isDone ? 0.38 : 0.9);
    final tint = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);

    return LiquidGlassContainer(
      borderRadius: 22,
      blurSigma: 10,
      tintColor: tint,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            // ── Icon badge ──────────────────────────────────────────────
            _buildIconBadge(context, cs, isDone),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 8),
                  _SevenDayDots(taskId: task.id),
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

  Widget _buildIconBadge(BuildContext context, ColorScheme cs, bool isDone) {
    final def = resolveTaskIcon(task.iconName);
    final color = isDone ? Colors.green : def.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDone ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        isDone ? Icons.check_rounded : def.icon,
        size: 22,
        color: color,
      ),
    );
  }
}

// ─── 7-day dot strip ──────────────────────────────────────────────────────────

class _SevenDayDots extends ConsumerWidget {
  final int taskId;
  const _SevenDayDots({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final daysAsync = ref.watch(taskLast7DaysProvider(taskId));
    final days = daysAsync.valueOrNull ?? List.filled(7, false);

    // Which index is today (rightmost)? Align day labels to the current weekday.
    // weekday: Mon=1 … Sun=7. Index 6 = today.
    final todayWeekday = DateTime.now().weekday; // 1=Mon, 7=Sun
    // Add 70 (multiple of 7) before % to guarantee a non-negative result.
    final labels = List.generate(
        7, (i) => _dayLabels[(todayWeekday - 1 - (6 - i) + 70) % 7]);

    return Row(
      children: List.generate(7, (i) {
        final done = days[i];
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
