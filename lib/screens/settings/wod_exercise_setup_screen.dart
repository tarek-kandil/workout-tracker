import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';

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
    // Get WOD name for the title by querying directly
    final wodResult = await (db.select(db.wodTemplates)
          ..where((w) => w.id.equals(widget.wodTemplateId)))
        .getSingleOrNull();
    setState(() {
      _templateExercises = exercises;
      _wodName = wodResult?.name ?? 'Exercises';
      _loading = false;
    });
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
        onCreateNew: (name, category) => _createAndPickExercise(name, category),
      ),
    );
    if (picked == null) return;

    await ref.read(databaseProvider).programsDao.insertWodTemplateExercise(
          WodTemplateExercisesCompanion(
            wodTemplateId: Value(widget.wodTemplateId),
            exerciseId: Value(picked.id),
            sortOrder: Value(_templateExercises.length + 1),
            targetSets: const Value(3),
            repRangeMin: const Value(6),
            repRangeMax: const Value(12),
          ),
        );
    _load();
  }

  /// Creates a new exercise in the library and returns it so it can be added to the WOD.
  Future<Exercise?> _createAndPickExercise(
      String name, String category) async {
    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(ExercisesCompanion(
      name: Value(name),
      category: Value(category),
    ));
    ref.invalidate(exercisesProvider);
    final allExercises = await db.exercisesDao.getAllExercises();
    return allExercises.where((e) => e.id == id).firstOrNull;
  }

  Future<void> _editEntry(
      WodTemplateExercise entry, Exercise exercise) async {
    final result = await showDialog<_ExerciseConfig>(
      context: context,
      builder: (ctx) =>
          _EditExerciseDialog(entry: entry, exercise: exercise),
    );
    if (result == null) return;

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
      appBar: AppBar(title: Text(_wodName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : exercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allExercises) {
                final exerciseMap = {
                  for (final e in allExercises) e.id: e
                };
                if (_templateExercises.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No exercises yet'),
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
                  padding: const EdgeInsets.only(bottom: 80),
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
                    return ListTile(
                      key: ValueKey(te.id),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(exercise.name),
                      subtitle: Text(
                          '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune, size: 20),
                            onPressed: () => _editEntry(te, exercise),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 20),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _deleteEntry(te),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
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
  final Future<Exercise?> Function(String name, String category) onCreateNew;

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
        await widget.onCreateNew(name, selectedCategory);
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
  const _ExerciseConfig({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.notes,
  });
}

class _EditExerciseDialog extends StatefulWidget {
  final WodTemplateExercise entry;
  final Exercise exercise;
  const _EditExerciseDialog(
      {required this.entry, required this.exercise});

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<_EditExerciseDialog> {
  late int _sets;
  late int _repMin;
  late int _repMax;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _sets = widget.entry.targetSets;
    _repMin = widget.entry.repRangeMin;
    _repMax = widget.entry.repRangeMax;
    _notesCtrl = TextEditingController(text: widget.entry.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperRow(
            label: 'Target Sets',
            value: _sets,
            min: 1,
            max: 10,
            onChanged: (v) => setState(() => _sets = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StepperRow(
                  label: 'Min Reps',
                  value: _repMin,
                  min: 1,
                  max: _repMax - 1,
                  onChanged: (v) => setState(() => _repMin = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StepperRow(
                  label: 'Max Reps',
                  value: _repMax,
                  min: _repMin + 1,
                  max: 50,
                  onChanged: (v) => setState(() => _repMax = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Coaching Note (optional)',
              hintText: 'e.g. pause at bottom',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(
                context,
                _ExerciseConfig(
                  sets: _sets,
                  repMin: _repMin,
                  repMax: _repMax,
                  notes: _notesCtrl.text,
                )),
            child: const Text('Save')),
      ],
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
              onPressed: value > min ? () => onChanged(value - 1) : null,
              iconSize: 20,
            ),
            Text('$value', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max ? () => onChanged(value + 1) : null,
              iconSize: 20,
            ),
          ],
        ),
      ],
    );
  }
}
