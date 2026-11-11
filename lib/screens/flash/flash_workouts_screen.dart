import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/flash_workouts_providers.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/reminder_schedule_picker.dart';
import '../log/active_session_screen.dart';
import '../settings/wod_exercise_setup_screen.dart';

class FlashWorkoutsScreen extends ConsumerWidget {
  const FlashWorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flashAsync = ref.watch(flashWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Flash Workouts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFlashWorkoutDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Flash Workout'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          flashAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (workouts) {
              if (workouts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 64, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No flash workouts yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create quick routines like mobility or abs outside your main program.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: workouts.length,
                itemBuilder: (_, i) {
                  final wod = workouts[i];
                  return _FlashWorkoutTile(
                    wod: wod,
                    onEditExercises: () async {
                      await Navigator.of(context).push(
                        glassRoute(WodExerciseSetupScreen(wodTemplateId: wod.id)),
                      );
                      ref.invalidate(flashWorkoutResultProvider(wod.id));
                    },
                    onEditSettings: () =>
                        showFlashWorkoutDialog(context, ref, wod),
                    onTest: () => _sendTest(context, wod),
                    onDelete: () => _confirmDelete(context, ref, wod),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendTest(BuildContext context, WodTemplate wod) async {
    final error = await NotificationService.sendTestNotification(wod.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? 'Test notification sent — check your shade'
          : 'Failed: $error'),
      backgroundColor: error == null ? null : Theme.of(context).colorScheme.error,
      duration: const Duration(seconds: 4),
    ));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WodTemplate wod) async {
    final db = ref.read(databaseProvider);
    final sessions = await db.sessionsDao.getSessionsForWodTemplate(wod.id);
    if (!context.mounted) return;

    final hasHistory = sessions.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Flash Workout'),
        content: Text(
          hasHistory
              ? 'Archive "${wod.name}"? Your ${sessions.length} logged session${sessions.length == 1 ? '' : 's'} will be preserved in History.'
              : 'Delete "${wod.name}"?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(hasHistory ? 'Archive' : 'Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (hasHistory) {
        await db.programsDao.archiveFlashWorkout(wod.id);
      } else {
        await db.programsDao.deleteWodTemplate(wod.id);
      }
      ref.invalidate(flashWorkoutsProvider);
      ref.invalidate(flashWorkoutResultProvider(wod.id));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('workout_progress_${wod.id}');
      } catch (_) {}
      await NotificationService.cancelFlashWorkoutReminder(wod.id);
    }
  }
}

Future<void> showFlashWorkoutDialog(
  BuildContext context,
  WidgetRef ref,
  WodTemplate? existing, {
  bool openExercisesOnCreate = true,
}) async {
  final form = await showDialog<_FlashWorkoutFormData>(
    context: context,
    builder: (_) => _FlashWorkoutDialog(existing: existing),
  );
  if (form == null) return;

  final dao = ref.read(databaseProvider).programsDao;
  int? createdId;

  if (existing == null) {
    final id = await dao.insertWodTemplate(WodTemplatesCompanion.insert(
      phaseId: const Value(null),
      wodNumber: 0,
      name: form.name,
      restSeconds: Value(form.restSeconds),
      reminderDays: Value(form.reminderDays),
      reminderHour: Value(form.reminderHour),
      reminderMinute: Value(form.reminderMinute),
    ));
    createdId = id;
    ref.invalidate(flashWorkoutsProvider);
    if (form.reminderHour != null && form.reminderMinute != null) {
      await NotificationService.scheduleFlashWorkoutReminder(
        wodId: id,
        title: form.name,
        hour: form.reminderHour!,
        minute: form.reminderMinute!,
        daysMask: form.reminderDays,
      );
    }
  } else {
    await dao.updateFlashWorkoutFields(WodTemplatesCompanion(
      id: Value(existing.id),
      name: Value(form.name),
      restSeconds: Value(form.restSeconds),
      reminderDays: Value(form.reminderDays),
      reminderHour: Value(form.reminderHour),
      reminderMinute: Value(form.reminderMinute),
    ));
    ref.invalidate(flashWorkoutsProvider);
    ref.invalidate(flashWorkoutResultProvider(existing.id));
    await NotificationService.cancelFlashWorkoutReminder(existing.id);
    if (form.reminderHour != null && form.reminderMinute != null) {
      await NotificationService.scheduleFlashWorkoutReminder(
        wodId: existing.id,
        title: form.name,
        hour: form.reminderHour!,
        minute: form.reminderMinute!,
        daysMask: form.reminderDays,
      );
    }
  }

  if (createdId != null && openExercisesOnCreate && context.mounted) {
    await Navigator.of(context).push(
      glassRoute(WodExerciseSetupScreen(wodTemplateId: createdId)),
    );
    ref.invalidate(flashWorkoutResultProvider(createdId));
  }
}

class _FlashWorkoutFormData {
  final String name;
  final int restSeconds;
  final int? reminderDays;
  final int? reminderHour;
  final int? reminderMinute;

  const _FlashWorkoutFormData({
    required this.name,
    required this.restSeconds,
    required this.reminderDays,
    required this.reminderHour,
    required this.reminderMinute,
  });
}

class _FlashWorkoutDialog extends ConsumerStatefulWidget {
  final WodTemplate? existing;
  const _FlashWorkoutDialog({required this.existing});

  @override
  ConsumerState<_FlashWorkoutDialog> createState() =>
      _FlashWorkoutDialogState();
}

class _FlashWorkoutDialogState extends ConsumerState<_FlashWorkoutDialog> {
  late final TextEditingController _nameCtrl;
  bool _reminderEnabled = false;
  int _reminderHour = 8;
  int _reminderMinute = 30;
  int _reminderDays = 0x7F;
  int _restSeconds = 60;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final wod = widget.existing;
    _nameCtrl = TextEditingController(text: wod?.name ?? '');
    _reminderHour = wod?.reminderHour ?? 8;
    _reminderMinute = wod?.reminderMinute ?? 30;
    _reminderDays = wod?.reminderDays ?? 0x7F;
    _restSeconds = wod?.restSeconds ?? 60;
    if (wod?.reminderHour != null && wod?.reminderMinute != null) {
      _reminderEnabled = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(
      context,
      _FlashWorkoutFormData(
        name: name,
        restSeconds: _restSeconds,
        reminderDays: _reminderEnabled ? _reminderDays : null,
        reminderHour: _reminderEnabled ? _reminderHour : null,
        reminderMinute: _reminderEnabled ? _reminderMinute : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Flash Workout' : 'Add Flash Workout'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Workout name',
                hintText: 'e.g. Daily Mobility, 8-min Abs',
              ),
            ),
            const SizedBox(height: 18),
            // ── Rest timer stepper ──────────────────────────────────────
            Row(
              children: [
                Icon(Icons.timer_outlined,
                    size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text('Default rest',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _restSeconds > 15
                      ? () => setState(() => _restSeconds -= 15)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                ),
                Text('${_restSeconds}s',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _restSeconds < 300
                      ? () => setState(() => _restSeconds += 15)
                      : null,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReminderSchedulePicker(
              enabled: _reminderEnabled,
              onEnabledChanged: (v) => setState(() => _reminderEnabled = v),
              hour: _reminderHour,
              minute: _reminderMinute,
              onTimeChanged: (h, m) => setState(() {
                _reminderHour = h;
                _reminderMinute = m;
              }),
              daysMask: _reminderDays,
              onDaysChanged: (mask) => setState(() => _reminderDays = mask),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Save' : 'Create & Add Exercises'),
        ),
      ],
    );
  }
}

class _FlashWorkoutTile extends ConsumerWidget {
  final WodTemplate wod;
  final VoidCallback onEditExercises;
  final VoidCallback onEditSettings;
  final VoidCallback onTest;
  final VoidCallback onDelete;

  const _FlashWorkoutTile({
    required this.wod,
    required this.onEditExercises,
    required this.onEditSettings,
    required this.onTest,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = ref.watch(flashWorkoutResultProvider(wod.id)).valueOrNull;
    final consistency =
        ref.watch(flashWorkoutConsistencyProvider(wod.id)).valueOrNull;
    final days =
        ref.watch(flashWorkoutLast7DaysProvider(wod.id)).valueOrNull ??
            List.filled(7, false);
    final doneToday = days.isNotEmpty && days.last;

    final accentColor = doneToday ? Colors.green : const Color(0xFF38BDF8);
    final exerciseCount = result?.allExercises.length ?? 0;

    final parts = <String>[
      '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
    ];
    if (wod.reminderHour != null && wod.reminderMinute != null) {
      parts.add(NotificationService.formatReminderSchedule(
        wod.reminderDays,
        wod.reminderHour!,
        wod.reminderMinute!,
      ));
    }
    if (consistency != null) {
      final (done, outOf) = consistency;
      parts.add('$done/$outOf days');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: GestureDetector(
              onTap: () async {
                if (result == null || result.items.isEmpty) {
                  onEditExercises();
                  return;
                }
                HapticFeedback.mediumImpact();
                await Navigator.of(context).push(
                  glassRoute(ActiveSessionScreen(result: result)),
                );
                ref.invalidate(flashWorkoutResultProvider(wod.id));
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  doneToday ? Icons.check_rounded : Icons.play_arrow_rounded,
                  size: 22,
                  color: accentColor,
                ),
              ),
            ),
            title: Text(wod.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              parts.join('  ·  '),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            onTap: onEditExercises,
            trailing: PopupMenuButton<_FlashAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case _FlashAction.exercises:
                    onEditExercises();
                  case _FlashAction.settings:
                    onEditSettings();
                  case _FlashAction.test:
                    onTest();
                  case _FlashAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _FlashAction.exercises,
                  child: ListTile(
                    leading: Icon(Icons.fitness_center_outlined),
                    title: Text('Edit exercises'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _FlashAction.settings,
                  child: ListTile(
                    leading: Icon(Icons.tune_outlined),
                    title: Text('Name & reminder'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (wod.reminderHour != null)
                  const PopupMenuItem(
                    value: _FlashAction.test,
                    child: ListTile(
                      leading: Icon(Icons.notifications_active_outlined),
                      title: Text('Send test now'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem(
                  value: _FlashAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title:
                        Text('Delete', style: TextStyle(color: cs.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _FlashAction { exercises, settings, test, delete }
