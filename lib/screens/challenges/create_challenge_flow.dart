import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../models/exercise_muscle_seed.dart';
import '../../models/exercise_tracking_mode.dart';
import '../../providers/challenges_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../utils/constants.dart';
import '../../utils/exercise_deduplicator.dart';
import '../settings/widgets/muscle_assignment_sheet.dart';

Future<void> showCreateChallengeFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final exercises =
      (await ref.read(exercisesProvider.future)).where((e) => !e.archived).toList();
  if (!context.mounted) return;

  final picked = await showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF141826),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _ChallengeExercisePickerSheet(
      exercises: exercises,
      onCreateNew: (name, muscles, mode) async {
        final db = ref.read(databaseProvider);
        final primary = muscles
            .where((m) => m.role == ExerciseMuscleRole.primary)
            .map((m) => m.muscle)
            .firstOrNull;
        final category =
            (primary != null ? regionForMuscle(primary) : null) ??
                primary ??
                'Other';
        final id = await db.exercisesDao.insertExercise(ExercisesCompanion(
          name: Value(name),
          category: Value(category),
          isTimed: Value(mode == ExerciseTrackingMode.timed),
          trackingMode: Value(mode.dbValue),
        ));
        await db.exercisesDao.setMusclesForExercise(id, muscles);
        ref.invalidate(exercisesProvider);
        ref.invalidate(exerciseMuscleMapProvider);
        final all = await db.exercisesDao.getAllExercises();
        return all.where((e) => e.id == id).firstOrNull;
      },
    ),
  );

  if (picked == null || !context.mounted) return;
  await _promptTargetAndSave(context, ref, picked);
}

Future<void> _promptTargetAndSave(
  BuildContext context,
  WidgetRef ref,
  Exercise exercise,
) async {
  final mode = exercise.mode;
  final durCtrl = TextEditingController(text: '90');
  final repsCtrl = TextEditingController(
      text: mode == ExerciseTrackingMode.bodyweightReps ? '20' : '5');
  final weightCtrl = TextEditingController(text: '100');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: Text('🏁 ${exercise.name} Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mode == ExerciseTrackingMode.timed) ...[
              TextField(
                controller: durCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Duration (seconds)',
                  suffixText: 's',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in const [60, 90, 120, 180])
                    ActionChip(
                      label: Text(fmtChallengeSec(s),
                          style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => setDlg(() => durCtrl.text = '$s'),
                    ),
                ],
              ),
            ] else if (mode == ExerciseTrackingMode.bodyweightReps) ...[
              TextField(
                controller: repsCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Reps',
                  suffixText: 'reps',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final r in const [10, 15, 20, 30, 50])
                    ActionChip(
                      label:
                          Text('$r', style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => setDlg(() => repsCtrl.text = '$r'),
                    ),
                ],
              ),
            ] else ...[
              TextField(
                controller: weightCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Target Weight',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target Reps',
                  suffixText: 'reps',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create Challenge')),
        ],
      ),
    ),
  );

  if (ok != true) return;
  final db = ref.read(databaseProvider);
  await db.challengesDao.insertChallenge(ChallengesCompanion.insert(
    exerciseId: exercise.id,
    targetDurationSeconds: mode == ExerciseTrackingMode.timed
        ? Value((int.tryParse(durCtrl.text.trim()) ?? 90).clamp(5, 7200))
        : const Value.absent(),
    targetReps: mode != ExerciseTrackingMode.timed
        ? Value((int.tryParse(repsCtrl.text.trim()) ?? 10).clamp(1, 500))
        : const Value.absent(),
    targetWeightKg: mode == ExerciseTrackingMode.weightedReps
        ? Value((double.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? 60)
            .clamp(0.5, 1000))
        : const Value.absent(),
  ));
  ref.invalidate(activeChallengesProvider);
}

class _ChallengeExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final Future<Exercise?> Function(
      String name, List<ExerciseMuscleSeed> muscles, ExerciseTrackingMode mode) onCreateNew;

  const _ChallengeExercisePickerSheet({
    required this.exercises,
    required this.onCreateNew,
  });

  @override
  State<_ChallengeExercisePickerSheet> createState() =>
      _ChallengeExercisePickerSheetState();
}

class _ChallengeExercisePickerSheetState
    extends State<_ChallengeExercisePickerSheet> {
  String _query = '';

  List<Exercise> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.exercises;
    final starts = widget.exercises
        .where((e) => e.name.toLowerCase().startsWith(q))
        .toList();
    final contains = widget.exercises
        .where((e) =>
            !e.name.toLowerCase().startsWith(q) &&
            matchesExerciseSearch(e.name, q))
        .toList();
    return [...starts, ...contains];
  }

  Future<void> _promptCreateNew(BuildContext sheetCtx) async {
    List<ExerciseMuscleSeed> assignments = [];
    ExerciseTrackingMode trackingMode = ExerciseTrackingMode.bodyweightReps;
    final name = _query.trim();

    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final primarySeed = assignments
              .where((a) => a.role == ExerciseMuscleRole.primary)
              .firstOrNull;
          final secondarySeeds = assignments
              .where((a) => a.role == ExerciseMuscleRole.secondary)
              .toList();
          return AlertDialog(
            title: Text('Add "$name"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MUSCLES WORKED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 8),
                if (primarySeed == null)
                  Text(
                    'Pick 1 primary muscle (required) and optional secondary muscles.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('${primarySeed.muscle} · Primary',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        visualDensity: VisualDensity.compact,
                      ),
                      for (final s in secondarySeeds)
                        Chip(
                          label: Text(s.muscle,
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await showMuscleAssignmentSheet(
                      ctx,
                      initial: assignments,
                    );
                    if (result != null) {
                      setDlgState(() => assignments = result);
                    }
                  },
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(
                      assignments.isEmpty ? 'Assign muscles' : 'Edit muscles'),
                ),
                const SizedBox(height: 12),
                Text(
                  'TRACKING MODE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ExerciseTrackingMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ExerciseTrackingMode.weightedReps,
                        label:
                            Text('Weighted', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: ExerciseTrackingMode.bodyweightReps,
                        label:
                            Text('Bodyweight', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: ExerciseTrackingMode.timed,
                        label: Text('Timed', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {trackingMode},
                    onSelectionChanged: (sel) =>
                        setDlgState(() => trackingMode = sel.first),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: primarySeed == null
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Create & Add')),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;
    final exercise = await widget.onCreateNew(name, assignments, trackingMode);
    if (exercise != null && sheetCtx.mounted) {
      Navigator.pop(sheetCtx, exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final showCreate = _query.trim().isNotEmpty &&
        !widget.exercises
            .any((e) => e.name.toLowerCase() == _query.trim().toLowerCase());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.48,
      builder: (sheetCtx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
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
            const Text(
              'Choose Challenge Exercise',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search or type new (e.g. Dead Hang, Pull-ups)...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (showCreate)
              ListTile(
                leading: const Icon(Icons.add_circle_rounded,
                    color: Color(0xFF34D399)),
                title: Text('Create "${_query.trim()}"',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: Color(0xFF34D399))),
                subtitle: const Text('Assign muscles & tracking mode',
                    style: TextStyle(fontSize: 12)),
                onTap: () => _promptCreateNew(sheetCtx),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final ex = list[i];
                  return ListTile(
                    title: Text(ex.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(ex.mode.shortLabel,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white.withValues(alpha: 0.55))),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () => Navigator.pop(sheetCtx, ex),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
