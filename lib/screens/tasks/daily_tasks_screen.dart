import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/daily_tasks_providers.dart';
import '../../providers/database_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class DailyTasksScreen extends ConsumerWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(dailyTasksProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Add Task" to create a daily reminder.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                  ),
                ],
              ),
            );
          }

          final completions = completionsAsync.valueOrNull ?? {};
          final activeTasks = tasks.where((t) => t.isEnabled).toList();
          final pausedTasks = tasks.where((t) => !t.isEnabled).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (activeTasks.isNotEmpty) ...[
                const _SectionHeader(label: 'TODAY'),
                ...activeTasks.map((task) => _TaskTile(
                      task: task,
                      isCompleted: completions.contains(task.id),
                      onToggle: (val) async {
                        await ref
                            .read(databaseProvider)
                            .dailyTasksDao
                            .setCompletion(task.id, val);
                        if (val && context.mounted) {
                          showTaskDoneFlash(context);
                        }
                      },
                      onEdit: () => _showTaskDialog(context, ref, task),
                      onToggleEnabled: () => _toggleEnabled(ref, task),
                      onTest: () => _sendTest(context, task),
                      onDelete: () => _confirmDelete(context, ref, task),
                    )),
              ],
              if (pausedTasks.isNotEmpty) ...[
                const _SectionHeader(label: 'PAUSED'),
                ...pausedTasks.map((task) => _TaskTile(
                      task: task,
                      isCompleted: false,
                      onToggle: (_) {},
                      onEdit: () => _showTaskDialog(context, ref, task),
                      onToggleEnabled: () => _toggleEnabled(ref, task),
                      onTest: () => _sendTest(context, task),
                      onDelete: () => _confirmDelete(context, ref, task),
                    )),
              ],
            ],
          );
        },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEnabled(WidgetRef ref, DailyTask task) async {
    final dao = ref.read(databaseProvider).dailyTasksDao;
    final nowEnabled = !task.isEnabled;
    await dao.updateTask(DailyTasksCompanion(
      id: Value(task.id),
      isEnabled: Value(nowEnabled),
    ));
    if (!nowEnabled) {
      await NotificationService.cancelReminder(task.id);
    } else if (task.reminderHour != null && task.reminderMinute != null) {
      await NotificationService.scheduleDailyReminder(
        id: task.id,
        title: task.name,
        hour: task.reminderHour!,
        minute: task.reminderMinute!,
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DailyTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.name}"?'),
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
    if (confirmed == true) {
      await ref.read(databaseProvider).dailyTasksDao.deleteTask(task.id);
      await NotificationService.cancelReminder(task.id);
    }
  }

  Future<void> _sendTest(BuildContext context, DailyTask task) async {
    final error = await NotificationService.sendTestNotification(task.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? 'Test notification sent — check your shade'
          : 'Failed: $error'),
      backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _showTaskDialog(
      BuildContext context, WidgetRef ref, DailyTask? task) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TaskDialog(existingTask: task, ref: ref),
    );
  }
}

// ─── Task dialog (own StatefulWidget — avoids stale-context crashes) ──────────

class _TaskDialog extends StatefulWidget {
  final DailyTask? existingTask;
  final WidgetRef ref;
  const _TaskDialog({required this.existingTask, required this.ref});

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  bool _reminderEnabled = false;
  String? _timeError;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _nameCtrl = TextEditingController(text: task?.name ?? '');
    _hourCtrl = TextEditingController(
      text: task?.reminderHour != null
          ? task!.reminderHour!.toString().padLeft(2, '0')
          : '',
    );
    _minuteCtrl = TextEditingController(
      text: task?.reminderMinute != null
          ? task!.reminderMinute!.toString().padLeft(2, '0')
          : '',
    );
    if (task?.reminderHour != null && task?.reminderMinute != null) {
      _reminderEnabled = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    int? hour, minute;
    if (_reminderEnabled) {
      hour = int.tryParse(_hourCtrl.text.trim());
      minute = int.tryParse(_minuteCtrl.text.trim());
      if (hour == null || minute == null ||
          hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        setState(() => _timeError = 'Enter a valid hour (0–23) and minute (0–59)');
        return;
      }
    }

    final dao = widget.ref.read(databaseProvider).dailyTasksDao;

    String? scheduleError;

    if (!_isEditing) {
      final id = await dao.insertTask(DailyTasksCompanion.insert(
        name: name,
        reminderHour: Value(hour),
        reminderMinute: Value(minute),
      ));
      if (hour != null && minute != null) {
        scheduleError = await NotificationService.scheduleDailyReminder(
          id: id, title: name, hour: hour, minute: minute,
        );
      }
    } else {
      final task = widget.existingTask!;
      await dao.updateTask(DailyTasksCompanion(
        id: Value(task.id),
        name: Value(name),
        reminderHour: Value(hour),
        reminderMinute: Value(minute),
      ));
      await NotificationService.cancelReminder(task.id);
      if (hour != null && minute != null) {
        scheduleError = await NotificationService.scheduleDailyReminder(
          id: task.id, title: name, hour: hour, minute: minute,
        );
      }
    }

    if (!mounted) return;

    if (scheduleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not schedule notification: $scheduleError'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 6),
      ));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Task' : 'Add Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Task name',
              hintText: 'e.g. Morning vitamins',
            ),
          ),
          const SizedBox(height: 20),
          // ── Reminder toggle row ───────────────────────────────────────
          Row(
            children: [
              Icon(Icons.notifications_outlined,
                  size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text('Daily reminder',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Switch(
                value: _reminderEnabled,
                onChanged: (v) => setState(() => _reminderEnabled = v),
              ),
            ],
          ),
          // ── Time fields (shown when reminder is on) ───────────────────
          if (_reminderEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hourCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'HH',
                      hintText: '08',
                      counterText: '',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(':',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w300)),
                ),
                Expanded(
                  child: TextField(
                    controller: _minuteCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'MM',
                      hintText: '30',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            if (_timeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_timeError!,
                    style: TextStyle(
                        color: scheme.error, fontSize: 12)),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}


// ─── Task tile ─────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final DailyTask task;
  final bool isCompleted;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onToggleEnabled;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onToggleEnabled,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = theme.colorScheme.onSurface.withValues(alpha: 0.38);

    final accentColor = isCompleted ? Colors.green : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: task.isEnabled ? accentColor : Colors.amber,
                width: 4,
              ),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Checkbox(
              value: isCompleted,
              onChanged:
                  task.isEnabled ? (val) => onToggle(val ?? false) : null,
            ),
            title: Text(
              task.name,
              style: isCompleted && task.isEnabled
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough, color: dimmed)
                  : null,
            ),
            subtitle: _buildSubtitle(context, theme),
            trailing: PopupMenuButton<_Action>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case _Action.edit:
                    onEdit();
                  case _Action.toggleEnabled:
                    onToggleEnabled();
                  case _Action.test:
                    onTest();
                  case _Action.delete:
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _Action.edit,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _Action.toggleEnabled,
                  child: ListTile(
                    leading: Icon(task.isEnabled
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline),
                    title: Text(task.isEnabled ? 'Pause' : 'Resume'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (task.reminderHour != null)
                  const PopupMenuItem(
                    value: _Action.test,
                    child: ListTile(
                      leading: Icon(Icons.notifications_active_outlined),
                      title: Text('Send test now'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: _Action.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    title: Text('Delete',
                        style: TextStyle(color: theme.colorScheme.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onTap: task.isEnabled ? () => onToggle(!isCompleted) : null,
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, ThemeData theme) {
    if (!task.isEnabled) {
      return Text('Paused',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber));
    }
    if (task.reminderHour != null && task.reminderMinute != null) {
      final h = task.reminderHour!.toString().padLeft(2, '0');
      final m = task.reminderMinute!.toString().padLeft(2, '0');
      return Text(
        'Repeats daily at $h:$m',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: Colors.white.withValues(alpha: 0.55)),
      );
    }
    return null;
  }
}

// ─── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

enum _Action { edit, toggleEnabled, test, delete }
