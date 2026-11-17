import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/daily_tasks_providers.dart';
import '../../../providers/database_provider.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/celebration_overlay.dart';
import '../../../widgets/glass_route.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../tasks/daily_tasks_screen.dart';

class SupplementsHomeCard extends ConsumerWidget {
  final List<DailyTask> tasks;
  const SupplementsHomeCard({super.key, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completions = ref.watch(todayCompletionsProvider).valueOrNull ?? {};
    final takenCount = tasks.where((t) => completions.contains(t.id)).length;
    final total = tasks.length;
    final allDone = total > 0 && takenCount == total;
    final progress = total == 0 ? 0.0 : takenCount / total;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Prominent Section Header ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 7),
              const Text(
                'SUPPLEMENTS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  glassRoute(const DailyTasksScreen()),
                ),
                child: const Text(
                  'Manage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Stack Card ───────────────────────────────────────────────────────
        LiquidGlassContainer(
          borderRadius: 20,
          blurSigma: 10,
          tintColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.80),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '$takenCount / $total taken',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!allDone)
                    GestureDetector(
                      onTap: () async {
                        final dao = ref.read(databaseProvider).dailyTasksDao;
                        for (final t in tasks) {
                          if (!completions.contains(t.id)) {
                            await dao.setCompletion(t.id, true);
                          }
                        }
                        if (context.mounted) showTaskDoneFlash(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          '✓ Take All',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                ),
              ),
              const SizedBox(height: 10),

              // Max 4 visible rows; scrollable beyond 4
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 244),
                child: SingleChildScrollView(
                  physics: tasks.length > 4
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      for (int i = 0; i < tasks.length; i++) ...[
                        if (i > 0) const SizedBox(height: 7),
                        _SupplementRow(
                          task: tasks[i],
                          isDone: completions.contains(tasks[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupplementRow extends ConsumerWidget {
  final DailyTask task;
  final bool isDone;

  const _SupplementRow({required this.task, required this.isDone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(taskConsistencyStatsProvider(task.id)).valueOrNull;
    final subtitleParts = <String>[];
    if (task.dose != null && task.dose!.trim().isNotEmpty) {
      subtitleParts.add(task.dose!.trim());
    }
    if (stats != null) {
      subtitleParts.add('${stats.last7Count}/7 this week');
    } else if (task.reminderHour != null && task.reminderMinute != null) {
      subtitleParts.add(
        NotificationService.formatReminderSchedule(
          task.reminderDays,
          task.reminderHour!,
          task.reminderMinute!,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final dao = ref.read(databaseProvider).dailyTasksDao;
        final next = !isDone;
        await dao.setCompletion(task.id, next);
        if (next && context.mounted) {
          showTaskDoneFlash(context);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDone
              ? const Color(0xFF34D399).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isDone
                ? const Color(0xFF34D399).withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? const Color(0xFF34D399) : Colors.transparent,
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF34D399)
                      : Colors.white.withValues(alpha: 0.30),
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Color(0xFF052E16))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.white,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                ],
              ),
            ),
            if (task.timing != null && task.timing!.trim().isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  task.timing!.trim(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSupplementConsistencySheet(context, task),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSupplementConsistencySheet(BuildContext context, DailyTask task) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF141828),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _SupplementConsistencySheet(task: task),
  );
}

class _SupplementConsistencySheet extends ConsumerWidget {
  final DailyTask task;
  const _SupplementConsistencySheet({required this.task});

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(taskConsistencyStatsProvider(task.id));
    final stats = statsAsync.valueOrNull;

    final streak = stats?.streak ?? 0;
    final last7 = stats?.last7Count ?? 0;
    final last30 = stats?.last30Count ?? 0;
    final pct30 = ((last30 / 30.0) * 100).round().clamp(0, 100);
    final thisWeek = stats?.thisWeekDone ?? List.filled(7, false);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final metaParts = <String>[
      if (task.dose != null && task.dose!.trim().isNotEmpty) task.dose!.trim(),
      if (task.timing != null && task.timing!.trim().isNotEmpty)
        task.timing!.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💊 ${task.name}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (metaParts.isNotEmpty)
                      Text(
                        metaParts.join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    glassRoute(const DailyTasksScreen()),
                  );
                },
                child: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── 3 Stat Tiles ─────────────────────────────────────────────────
          Row(
            children: [
              _StatTile(
                label: 'STREAK',
                value: '$streak day${streak == 1 ? '' : 's'}',
                color: const Color(0xFF34D399),
              ),
              const SizedBox(width: 8),
              _StatTile(
                label: 'LAST 7D',
                value: '$last7 / 7',
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 8),
              _StatTile(
                label: '30-DAY',
                value: '$pct30%',
                color: const Color(0xFFFBBF24),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Interactive THIS WEEK Pills (tap to check missed days) ───────
          Row(
            children: [
              Text(
                'THIS WEEK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                'Tap any day to edit',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Builder(builder: (context) {
                    final dayDate = monday.add(Duration(days: i));
                    final isFuture = dayDate.isAfter(today);
                    final isToday = dayDate == today;
                    final hit = thisWeek[i];

                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () async {
                              await ref
                                  .read(databaseProvider)
                                  .dailyTasksDao
                                  .setCompletionForDate(
                                    task.id,
                                    dayDate,
                                    !hit,
                                  );
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: hit
                              ? const Color(0xFF34D399).withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isToday
                                ? const Color(0xFF38BDF8)
                                : hit
                                    ? const Color(0xFF34D399)
                                        .withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.08),
                            width: isToday ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _dayLetters[i],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isFuture
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : hit
                                        ? const Color(0xFF34D399)
                                        : Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hit ? '✓' : '·',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isFuture
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : hit
                                        ? const Color(0xFF34D399)
                                        : Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ── Style B Ultra-Minimal 30-Day Adherence Bar ───────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '30-Day Adherence',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$last30 / 30 days',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (last30 / 30.0).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF34D399)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
