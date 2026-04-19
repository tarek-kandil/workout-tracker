import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../widgets/glass_background.dart';

class WodExerciseSetupScreen extends ConsumerStatefulWidget {
  final int wodTemplateId;
  const WodExerciseSetupScreen({super.key, required this.wodTemplateId});

  @override
  ConsumerState<WodExerciseSetupScreen> createState() =>
      _WodExerciseSetupScreenState();
}

class _WodExerciseSetupScreenState
    extends ConsumerState<WodExerciseSetupScreen> {
  List<WodTemplateExercise> _templateExercises = [];
  String _wodName = 'Exercises';
  int _restSeconds = 90;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final exercises =
        await db.programsDao.getTemplateExercises(widget.wodTemplateId);
    final wodResult = await (db.select(db.wodTemplates)
          ..where((w) => w.id.equals(widget.wodTemplateId)))
        .getSingleOrNull();
    setState(() {
      _templateExercises = exercises;
      _wodName = wodResult?.name ?? 'Exercises';
      _restSeconds = wodResult?.restSeconds ?? 90;
      _loading = false;
    });
  }

  Future<void> _editRestTime() async {
    int restSeconds = _restSeconds;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Rest Time'),
          content: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 8),
              const Text('Rest'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: restSeconds > 15
                    ? () => setDialogState(
                        () => restSeconds = (restSeconds - 15).clamp(15, 600))
                    : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${restSeconds}s',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: restSeconds < 600
                    ? () => setDialogState(
                        () => restSeconds = (restSeconds + 15).clamp(15, 600))
                    : null,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final db = ref.read(databaseProvider);
    final wod = await (db.select(db.wodTemplates)
          ..where((w) => w.id.equals(widget.wodTemplateId)))
        .getSingleOrNull();
    if (wod == null) return;
    await db.programsDao.updateWodTemplate(WodTemplatesCompanion(
      id: Value(wod.id),
      phaseId: Value(wod.phaseId),
      wodNumber: Value(wod.wodNumber),
      name: Value(wod.name),
      restSeconds: Value(restSeconds),
    ));
    setState(() => _restSeconds = restSeconds);
  }

  Future<void> _addExercise() async {
    final allExercises =
        await ref.read(databaseProvider).exercisesDao.getAllExercises();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExercisePickerSheet(
        exercises: allExercises,
        onCreateNew: (name, category, isTimed) =>
            _createAndPickExercise(name, category, isTimed),
      ),
    );
    if (picked == null) return;

    await ref.read(databaseProvider).programsDao.insertWodTemplateExercise(
          WodTemplateExercisesCompanion(
            wodTemplateId: Value(widget.wodTemplateId),
            exerciseId: Value(picked.id),
            sortOrder: Value(_templateExercises.length + 1),
            targetSets: const Value(3),
            // For timed exercises repRangeMin/Max store seconds (default 30–60 s)
            repRangeMin: picked.isTimed ? const Value(30) : const Value(6),
            repRangeMax: picked.isTimed ? const Value(60) : const Value(12),
          ),
        );
    _load();
  }

  /// Creates a new exercise in the library and returns it so it can be added to the WOD.
  Future<Exercise?> _createAndPickExercise(
      String name, String category, bool isTimed) async {
    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(ExercisesCompanion(
      name: Value(name),
      category: Value(category),
      isTimed: Value(isTimed),
    ));
    ref.invalidate(exercisesProvider);
    final allExercises = await db.exercisesDao.getAllExercises();
    return allExercises.where((e) => e.id == id).firstOrNull;
  }

  Future<void> _editEntry(
      WodTemplateExercise entry, Exercise exercise) async {
    final result = await showDialog<_ExerciseConfig>(
      context: context,
      builder: (ctx) => _EditExerciseDialog(entry: entry, exercise: exercise),
    );
    if (result == null) return;

    // Persist isTimed change on the exercise itself if the user toggled it
    if (result.isTimed != exercise.isTimed) {
      await ref.read(databaseProvider).exercisesDao.updateExercise(
        ExercisesCompanion(
          id: Value(exercise.id),
          name: Value(exercise.name),
          category: Value(exercise.category),
          isTimed: Value(result.isTimed),
        ),
      );
      ref.invalidate(exercisesProvider);
    }

    await ref.read(databaseProvider).programsDao.updateWodTemplateExercise(
          WodTemplateExercisesCompanion(
            id: Value(entry.id),
            wodTemplateId: Value(entry.wodTemplateId),
            exerciseId: Value(entry.exerciseId),
            sortOrder: Value(entry.sortOrder),
            targetSets: Value(result.sets),
            repRangeMin: Value(result.repMin),
            repRangeMax: Value(result.repMax),
            notes: Value(result.notes.isEmpty ? null : result.notes),
          ),
        );
    _load();
  }

  Future<void> _deleteEntry(WodTemplateExercise entry) async {
    await ref
        .read(databaseProvider)
        .programsDao
        .deleteWodTemplateExercise(entry.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_wodName),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _editRestTime,
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: Text('${_restSeconds}s rest'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allExercises) {
                final exerciseMap = {for (final e in allExercises) e.id: e};
                if (_templateExercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No exercises yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.5))),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _addExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Exercise'),
                        ),
                      ],
                    ),
                  );
                }
                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _templateExercises.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _templateExercises.removeAt(oldIndex);
                    _templateExercises.insert(newIndex, item);
                    setState(() {});
                    final db = ref.read(databaseProvider);
                    for (int i = 0; i < _templateExercises.length; i++) {
                      final te = _templateExercises[i];
                      await db.programsDao.updateWodTemplateExercise(
                        WodTemplateExercisesCompanion(
                          id: Value(te.id),
                          wodTemplateId: Value(te.wodTemplateId),
                          exerciseId: Value(te.exerciseId),
                          sortOrder: Value(i + 1),
                          targetSets: Value(te.targetSets),
                          repRangeMin: Value(te.repRangeMin),
                          repRangeMax: Value(te.repRangeMax),
                          notes: Value(te.notes),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context, i) {
                    final te = _templateExercises[i];
                    final exercise = exerciseMap[te.exerciseId];
                    if (exercise == null) {
                      return const SizedBox.shrink(key: ValueKey(-1));
                    }
                    final accent = Theme.of(context).colorScheme.primary;
                    return Padding(
                      key: ValueKey(te.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x26000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.09)),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.drag_handle,
                              color: Colors.white.withValues(alpha: 0.3)),
                          title: Text(exercise.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            exercise.isTimed
                                ? '${te.targetSets} sets · ${_fmtSec(te.repRangeMin)}'
                                : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.45)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.tune,
                                    size: 20,
                                    color: accent.withValues(alpha: 0.8)),
                                onPressed: () => _editEntry(te, exercise),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 20),
                                color: Theme.of(context).colorScheme.error,
                                onPressed: () => _deleteEntry(te),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
      ),
    );
  }
}

// ── Exercise picker sheet ─────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final Future<Exercise?> Function(String name, String category, bool isTimed) onCreateNew;

  const _ExercisePickerSheet({
    required this.exercises,
    required this.onCreateNew,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises
        .where(
            (e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final showCreateOption = _query.trim().isNotEmpty &&
        !filtered.any(
            (e) => e.name.toLowerCase() == _query.trim().toLowerCase());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search or type a new exercise name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              children: [
                // "Create new" option shown when no exact match
                if (showCreateOption)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.add),
                    ),
                    title:
                        Text('Create "${_query.trim()}"'),
                    subtitle: const Text('Add as a new exercise'),
                    onTap: () => _promptCreateNew(ctx),
                  ),
                if (showCreateOption && filtered.isNotEmpty)
                  const Divider(),
                ...filtered.map(
                  (e) => ListTile(
                    title: Text(e.name),
                    subtitle: Text(e.category),
                    onTap: () => Navigator.pop(ctx, e),
                  ),
                ),
                if (filtered.isEmpty && !showCreateOption)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No exercises found')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptCreateNew(BuildContext sheetCtx) async {
    final categories = [
      'Push', 'Pull', 'Legs', 'Core', 'Cardio', 'Other'
    ];
    String selectedCategory = 'Other';
    bool isTimed = false;
    final name = _query.trim();

    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Add "$name"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
                items: categories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setDlgState(() => selectedCategory = v!),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Timed exercise'),
                value: isTimed,
                onChanged: (v) => setDlgState(() => isTimed = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create & Add')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final exercise =
        await widget.onCreateNew(name, selectedCategory, isTimed);
    if (exercise != null && sheetCtx.mounted) {
      Navigator.pop(sheetCtx, exercise);
    }
  }
}

// ── Edit exercise dialog ──────────────────────────────────────────────────────

class _ExerciseConfig {
  final int sets;
  final int repMin;
  final int repMax;
  final String notes;
  final bool isTimed;
  const _ExerciseConfig({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.notes,
    required this.isTimed,
  });
}

class _EditExerciseDialog extends StatefulWidget {
  final WodTemplateExercise entry;
  final Exercise exercise;
  const _EditExerciseDialog({required this.entry, required this.exercise});

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<_EditExerciseDialog> {
  static const List<int> _steps = [
    10, 20, 30, 45,
    60, 90, 120, 150, 180, 210, 240, 270, 300,
    360, 420, 480, 540, 600,
  ];

  static int _nearestIdx(int seconds) {
    int best = 0;
    int bestDiff = (seconds - _steps[0]).abs();
    for (int i = 1; i < _steps.length; i++) {
      final diff = (seconds - _steps[i]).abs();
      if (diff < bestDiff) { bestDiff = diff; best = i; }
    }
    return best;
  }

  late int _sets;
  late bool _isTimed;
  late int _repMin;
  late int _repMax;
  late int _durationIdx; // single index into _steps for timed exercises
  late final TextEditingController _notesCtrl;

  static const _accent = Colors.indigoAccent;

  @override
  void initState() {
    super.initState();
    _sets = widget.entry.targetSets;
    _isTimed = widget.exercise.isTimed;
    if (widget.exercise.isTimed) {
      _durationIdx = _nearestIdx(widget.entry.repRangeMin);
      _repMin = 6;
      _repMax = 12;
    } else {
      _repMin = widget.entry.repRangeMin;
      _repMax = widget.entry.repRangeMax;
      _durationIdx = _nearestIdx(30);
    }
    _notesCtrl = TextEditingController(text: widget.entry.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onTimedToggle(bool v) {
    setState(() {
      _isTimed = v;
      if (v) {
        _durationIdx = _nearestIdx(30);
      } else {
        _repMin = 6;
        _repMax = 12;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Timed toggle ─────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18, color: Colors.white54),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Timed exercise',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _isTimed,
                    onChanged: _onTimedToggle,
                    activeThumbColor: _accent,
                  ),
                ],
              ),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 20),

              // ── Sets picker ──────────────────────────────────────────────
              const _Label('SETS'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleBtn(
                    icon: Icons.remove,
                    onTap: () => setState(() => _sets = (_sets - 1).clamp(1, 10)),
                  ),
                  const SizedBox(width: 36),
                  Column(
                    children: [
                      Text(
                        '$_sets',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 56,
                          height: 1,
                        ),
                      ),
                      const Text('sets',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 36),
                  _CircleBtn(
                    icon: Icons.add,
                    onTap: () => setState(() => _sets = (_sets + 1).clamp(1, 10)),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 20),

              // ── Duration OR Reps ─────────────────────────────────────────
              if (_isTimed) ...[
                const _Label('DURATION'),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleBtn(
                      icon: Icons.remove,
                      onTap: () => setState(() =>
                          _durationIdx = (_durationIdx - 1).clamp(0, _steps.length - 1)),
                    ),
                    const SizedBox(width: 36),
                    Column(
                      children: [
                        Text(
                          _fmtSec(_steps[_durationIdx]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 56,
                            height: 1,
                          ),
                        ),
                        const Text('per set',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 36),
                    _CircleBtn(
                      icon: Icons.add,
                      onTap: () => setState(() =>
                          _durationIdx = (_durationIdx + 1).clamp(0, _steps.length - 1)),
                    ),
                  ],
                ),
              ] else ...[
                const _Label('REP RANGE'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StepperRow(
                        label: 'Min Reps',
                        value: _repMin,
                        min: 1,
                        max: _repMax,
                        onChanged: (v) => setState(() => _repMin = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StepperRow(
                        label: 'Max Reps',
                        value: _repMax,
                        min: _repMin,
                        max: 50,
                        onChanged: (v) => setState(() => _repMax = v),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 12),

              // ── Coaching note ────────────────────────────────────────────
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Coaching Note (optional)',
                  hintText: 'e.g. pause at bottom',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 24),

              // ── Save ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(
                    context,
                    _ExerciseConfig(
                      sets: _sets,
                      repMin: _isTimed ? _steps[_durationIdx] : _repMin,
                      repMax: _isTimed ? _steps[_durationIdx] : _repMax,
                      notes: _notesCtrl.text,
                      isTimed: _isTimed,
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > min ? () => onChanged((value - 1).clamp(min, max)) : null,
              iconSize: 20,
            ),
            Text('$value', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max ? () => onChanged((value + 1).clamp(min, max)) : null,
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }
}

/// Formats seconds as "M:SS" (e.g. 90 → "1:30", 30 → "0:30").
String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ── Shared helper widgets ──────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.indigoAccent.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Colors.indigoAccent, size: 22),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}
