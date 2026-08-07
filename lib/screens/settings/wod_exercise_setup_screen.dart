import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/drum_picker.dart';

// ── Local list model ───────────────────────────────────────────────────────────

/// A WOD-level item — either a standalone exercise or a circuit.
sealed class _Item {
  int get wodSortOrder;
}

class _StandaloneItem extends _Item {
  final WodTemplateExercise exercise;
  @override
  int get wodSortOrder => exercise.sortOrder;
  _StandaloneItem(this.exercise);
}

class _CircuitItem extends _Item {
  WodExerciseGroup group;
  List<WodTemplateExercise> exercises;
  @override
  int get wodSortOrder => group.sortOrder;
  _CircuitItem({required this.group, required this.exercises});
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class WodExerciseSetupScreen extends ConsumerStatefulWidget {
  final int wodTemplateId;
  const WodExerciseSetupScreen({super.key, required this.wodTemplateId});

  @override
  ConsumerState<WodExerciseSetupScreen> createState() =>
      _WodExerciseSetupScreenState();
}

class _WodExerciseSetupScreenState
    extends ConsumerState<WodExerciseSetupScreen> {
  List<_Item> _items = [];
  String _wodName = 'Exercises';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final standaloneExercises =
        await db.programsDao.getTemplateExercises(widget.wodTemplateId);
    final groups =
        await db.programsDao.getGroupsForWod(widget.wodTemplateId);
    final wodResult = await (db.select(db.wodTemplates)
          ..where((w) => w.id.equals(widget.wodTemplateId)))
        .getSingleOrNull();

    final items = <_Item>[
      for (final e in standaloneExercises) _StandaloneItem(e),
    ];
    for (final g in groups) {
      final exs = await db.programsDao.getExercisesForGroup(g.id);
      items.add(_CircuitItem(group: g, exercises: exs));
    }
    items.sort((a, b) => a.wodSortOrder.compareTo(b.wodSortOrder));

    setState(() {
      _items = items;
      _wodName = wodResult?.name ?? 'Exercises';
      _loading = false;
    });
  }

  int get _nextSortOrder =>
      _items.isEmpty ? 1 : _items.map((e) => e.wodSortOrder).reduce((a, b) => a > b ? a : b) + 1;

  // ── Add standalone exercise ─────────────────────────────────────────────────

  Future<void> _addExercise({int? groupId}) async {
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

    final db = ref.read(databaseProvider);
    if (groupId != null) {
      // Add to circuit — sortOrder = position within circuit
      final circuitItem =
          _items.whereType<_CircuitItem>().firstWhere((c) => c.group.id == groupId);
      final nextInGroup = circuitItem.exercises.isEmpty
          ? 1
          : circuitItem.exercises.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
      await db.programsDao.insertWodTemplateExercise(
        WodTemplateExercisesCompanion(
          wodTemplateId: Value(widget.wodTemplateId),
          exerciseId: Value(picked.id),
          groupId: Value(groupId),
          sortOrder: Value(nextInGroup),
          targetSets: const Value(1), // circuits: 1 rep per exercise per round
          repRangeMin: picked.isTimed ? const Value(30) : const Value(10),
          repRangeMax: picked.isTimed ? const Value(30) : const Value(12),
        ),
      );
    } else {
      // Standalone
      await db.programsDao.insertWodTemplateExercise(
        WodTemplateExercisesCompanion(
          wodTemplateId: Value(widget.wodTemplateId),
          exerciseId: Value(picked.id),
          sortOrder: Value(_nextSortOrder),
          targetSets: const Value(3),
          repRangeMin: picked.isTimed ? const Value(30) : const Value(10),
          repRangeMax: picked.isTimed ? const Value(60) : const Value(12),
        ),
      );
    }
    _load();
  }

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

  // ── Add circuit ─────────────────────────────────────────────────────────────

  Future<void> _addCircuit() async {
    final config = await _showCircuitDialog();
    if (config == null) return;
    final db = ref.read(databaseProvider);
    await db.programsDao.insertGroup(WodExerciseGroupsCompanion(
      wodTemplateId: Value(widget.wodTemplateId),
      sortOrder: Value(_nextSortOrder),
      name: Value(config.name.isEmpty ? null : config.name),
      rounds: Value(config.rounds),
      restBetweenExercisesSeconds: Value(config.restBetweenExercises),
      restBetweenRoundsSeconds: Value(config.restBetweenRounds),
    ));
    await _load();
    // Auto-open exercise picker for the newly created circuit
    if (mounted) {
      final newCircuit = _items.whereType<_CircuitItem>().lastOrNull;
      if (newCircuit != null) {
        await _addExercise(groupId: newCircuit.group.id);
      }
    }
  }

  Future<void> _editCircuit(_CircuitItem item) async {
    final config = await _showCircuitDialog(existing: item.group);
    if (config == null) return;
    final db = ref.read(databaseProvider);
    await db.programsDao.updateGroup(WodExerciseGroupsCompanion(
      id: Value(item.group.id),
      wodTemplateId: Value(item.group.wodTemplateId),
      sortOrder: Value(item.group.sortOrder),
      name: Value(config.name.isEmpty ? null : config.name),
      rounds: Value(config.rounds),
      restBetweenExercisesSeconds: Value(config.restBetweenExercises),
      restBetweenRoundsSeconds: Value(config.restBetweenRounds),
    ));
    _load();
  }

  Future<void> _deleteCircuit(_CircuitItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Circuit?'),
        content: const Text(
            'All exercises in this circuit will also be removed from the WOD.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Delete exercises in circuit, then the group
    for (final e in item.exercises) {
      await ref.read(databaseProvider).programsDao.deleteWodTemplateExercise(e.id);
    }
    await ref.read(databaseProvider).programsDao.deleteGroup(item.group.id);
    _load();
  }

  // ── Edit standalone exercise ────────────────────────────────────────────────

  Future<void> _editEntry(WodTemplateExercise entry, Exercise exercise,
      {bool inCircuit = false}) async {
    final result = await showDialog<_ExerciseConfig>(
      context: context,
      builder: (ctx) => _EditExerciseDialog(
          entry: entry,
          exercise: exercise,
          inCircuit: inCircuit),
    );
    if (result == null) return;

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
            groupId: Value(entry.groupId),
            sortOrder: Value(entry.sortOrder),
            targetSets: Value(result.sets),
            repRangeMin: Value(result.repMin),
            repRangeMax: Value(result.repMax),
            notes: Value(result.notes.isEmpty ? null : result.notes),
            restSeconds: Value(result.restAfterExerciseSeconds),
            restBetweenSetsSeconds: Value(result.restBetweenSetsSeconds),
            targetRpe: Value(result.targetRpe),
            videoUrl: Value(result.videoUrl),
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

  // ── Circuit config dialog ───────────────────────────────────────────────────

  Future<_CircuitConfig?> _showCircuitDialog({WodExerciseGroup? existing}) async {
    return showDialog<_CircuitConfig>(
      context: context,
      builder: (ctx) => _CircuitConfigDialog(existing: existing),
    );
  }

  // ── FAB action menu ─────────────────────────────────────────────────────────

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Add Exercise'),
              subtitle: const Text('Standalone exercise with sets & reps'),
              onTap: () {
                Navigator.pop(ctx);
                _addExercise();
              },
            ),
            ListTile(
              leading: const Icon(Icons.loop),
              title: const Text('Add Circuit'),
              subtitle: const Text(
                  'Group of exercises done as rounds (superset, circuit…)'),
              onTap: () {
                Navigator.pop(ctx);
                _addCircuit();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Reorder ─────────────────────────────────────────────────────────────────

  Future<void> _onReorderItems(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    setState(() {});
    final db = ref.read(databaseProvider);
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it is _StandaloneItem) {
        await db.programsDao.updateWodTemplateExercise(
          WodTemplateExercisesCompanion(
            id: Value(it.exercise.id),
            wodTemplateId: Value(it.exercise.wodTemplateId),
            exerciseId: Value(it.exercise.exerciseId),
            groupId: const Value(null),
            sortOrder: Value(i + 1),
            targetSets: Value(it.exercise.targetSets),
            repRangeMin: Value(it.exercise.repRangeMin),
            repRangeMax: Value(it.exercise.repRangeMax),
            notes: Value(it.exercise.notes),
            restSeconds: Value(it.exercise.restSeconds),
          ),
        );
      } else if (it is _CircuitItem) {
        await db.programsDao.updateGroup(WodExerciseGroupsCompanion(
          id: Value(it.group.id),
          wodTemplateId: Value(it.group.wodTemplateId),
          sortOrder: Value(i + 1),
          name: Value(it.group.name),
          rounds: Value(it.group.rounds),
          restBetweenExercisesSeconds:
              Value(it.group.restBetweenExercisesSeconds),
          restBetweenRoundsSeconds: Value(it.group.restBetweenRoundsSeconds),
        ));
      }
    }
    // Reload to reflect persisted positions
    _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_wodName),
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
                if (_items.isEmpty) {
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
                                    color: Colors.white
                                        .withValues(alpha: 0.5))),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _showAddMenu,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Exercise'),
                        ),
                      ],
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _items.length,
                  onReorder: _onReorderItems,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    if (item is _StandaloneItem) {
                      final exercise = exerciseMap[item.exercise.exerciseId];
                      if (exercise == null) {
                        return const SizedBox.shrink(
                            key: ValueKey('missing'));
                      }
                      return _StandaloneExerciseTile(
                        key: ValueKey('s-${item.exercise.id}'),
                        templateExercise: item.exercise,
                        exercise: exercise,
                        dragIndex: i,
                        onEdit: () => _editEntry(item.exercise, exercise),
                        onDelete: () => _deleteEntry(item.exercise),
                      );
                    } else if (item is _CircuitItem) {
                      return _CircuitBlock(
                        key: ValueKey('c-${item.group.id}'),
                        item: item,
                        exerciseMap: exerciseMap,
                        onEditCircuit: () => _editCircuit(item),
                        onDeleteCircuit: () => _deleteCircuit(item),
                        onAddExercise: () =>
                            _addExercise(groupId: item.group.id),
                        onEditExercise: (te, ex) =>
                            _editEntry(te, ex, inCircuit: true),
                        onDeleteExercise: _deleteEntry,
                      );
                    }
                    return const SizedBox.shrink(key: ValueKey('?'));
                  },
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMenu,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

// ── Circuit config dialog ──────────────────────────────────────────────────────

class _CircuitConfig {
  final String name;
  final int rounds;
  final int restBetweenExercises;
  final int restBetweenRounds;
  const _CircuitConfig({
    required this.name,
    required this.rounds,
    required this.restBetweenExercises,
    required this.restBetweenRounds,
  });
}

class _CircuitConfigDialog extends StatefulWidget {
  final WodExerciseGroup? existing;
  const _CircuitConfigDialog({this.existing});

  @override
  State<_CircuitConfigDialog> createState() => _CircuitConfigDialogState();
}

class _CircuitConfigDialogState extends State<_CircuitConfigDialog> {
  late int _rounds;
  late int _restBetweenEx;
  late int _restBetweenRounds;
  late final TextEditingController _nameCtrl;

  static const _accent = Colors.indigoAccent;

  @override
  void initState() {
    super.initState();
    _rounds = widget.existing?.rounds ?? 3;
    _restBetweenEx = widget.existing?.restBetweenExercisesSeconds ?? 0;
    _restBetweenRounds = widget.existing?.restBetweenRoundsSeconds ?? 90;
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
            const Text(
              'Circuit Settings',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
            const SizedBox(height: 20),

            // Circuit name
            const _Label('NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              autofocus: widget.existing == null,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Warm-up Circuit, Finisher…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),

            // Rounds picker
            const _Label('ROUNDS'),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CircleBtn(
                  icon: Icons.remove,
                  onTap: () =>
                      setState(() => _rounds = (_rounds - 1).clamp(1, 20)),
                ),
                const SizedBox(width: 36),
                Column(
                  children: [
                    Text(
                      '$_rounds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 56,
                        height: 1,
                      ),
                    ),
                    const Text('rounds',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 36),
                _CircleBtn(
                  icon: Icons.add,
                  onTap: () =>
                      setState(() => _rounds = (_rounds + 1).clamp(1, 20)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 16),

            // Rest between exercises
            const _Label('REST BETWEEN EXERCISES'),
            const SizedBox(height: 8),
            _RestStepper(
              label: 'Between exercises',
              value: _restBetweenEx,
              allowZero: true,
              onChanged: (v) => setState(() => _restBetweenEx = v),
            ),
            const SizedBox(height: 16),

            // Rest between rounds
            const _Label('REST BETWEEN ROUNDS'),
            const SizedBox(height: 8),
            _RestStepper(
              label: 'Between rounds',
              value: _restBetweenRounds,
              onChanged: (v) => setState(() => _restBetweenRounds = v),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  _CircuitConfig(
                    name: _nameCtrl.text.trim(),
                    rounds: _rounds,
                    restBetweenExercises: _restBetweenEx,
                    restBetweenRounds: _restBetweenRounds,
                  ),
                ),
                child: const Text('Save',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── Standalone exercise tile ───────────────────────────────────────────────────

class _StandaloneExerciseTile extends StatelessWidget {
  final WodTemplateExercise templateExercise;
  final Exercise exercise;
  final int dragIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StandaloneExerciseTile({
    super.key,
    required this.templateExercise,
    required this.exercise,
    required this.dragIndex,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final te = templateExercise;
    final errorColor = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      size: 20,
                      color: const Color(0xFF6366F1).withValues(alpha: 0.75),
                    ),
                    onPressed: onEdit,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      size: 20,
                      color: errorColor.withValues(alpha: 0.65),
                    ),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            // Meta row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${te.targetSets} sets',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const Spacer(),
                      _RepsPill(te: te, isTimed: exercise.isTimed),
                      if (te.targetRpe != null) ...[
                        const SizedBox(width: 5),
                        _RpePill(rpe: te.targetRpe!),
                      ],
                    ],
                  ),
                  if (te.restBetweenSetsSeconds != null ||
                      te.restSeconds != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (te.restBetweenSetsSeconds != null) ...[
                          _RestPill(
                            label:
                                '${_fmtSec(te.restBetweenSetsSeconds!)} sets',
                          ),
                        ],
                        if (te.restBetweenSetsSeconds != null &&
                            te.restSeconds != null)
                          const SizedBox(width: 5),
                        if (te.restSeconds != null)
                          _RestPill(
                            label: te.restSeconds == 0
                                ? 'no rest after'
                                : '${_fmtSec(te.restSeconds!)} after',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circuit block ──────────────────────────────────────────────────────────────

class _CircuitBlock extends StatelessWidget {
  final _CircuitItem item;
  final Map<int, Exercise> exerciseMap;
  final VoidCallback onEditCircuit;
  final VoidCallback onDeleteCircuit;
  final VoidCallback onAddExercise;
  final void Function(WodTemplateExercise, Exercise) onEditExercise;
  final void Function(WodTemplateExercise) onDeleteExercise;

  const _CircuitBlock({
    super.key,
    required this.item,
    required this.exerciseMap,
    required this.onEditCircuit,
    required this.onDeleteCircuit,
    required this.onAddExercise,
    required this.onEditExercise,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final group = item.group;
    final restBetweenExLabel = group.restBetweenExercisesSeconds > 0
        ? '${group.restBetweenExercisesSeconds}s between exercises'
        : 'No rest between exercises';
    final restBetweenRoundsLabel =
        '${group.restBetweenRoundsSeconds}s between rounds';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Circuit header ────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.drag_handle,
                      color: Colors.white.withValues(alpha: 0.3), size: 20),
                  const SizedBox(width: 8),
                  Icon(Icons.loop, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name != null && group.name!.isNotEmpty
                              ? group.name!
                              : 'Circuit',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: accent),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.rounds} rounds  ·  $restBetweenExLabel  ·  $restBetweenRoundsLabel',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.4)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune,
                        size: 18,
                        color: accent.withValues(alpha: 0.8)),
                    onPressed: onEditCircuit,
                    tooltip: 'Edit circuit',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.7)),
                    onPressed: onDeleteCircuit,
                    tooltip: 'Delete circuit',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: accent.withValues(alpha: 0.15)),
            // ── Exercises inside circuit ──────────────────────────────────
            ...item.exercises.map((te) {
              final exercise = exerciseMap[te.exerciseId];
              if (exercise == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.25)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(fontSize: 14, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RepsPill(te: te, isTimed: exercise.isTimed),
                    if (te.targetRpe != null) ...[
                      const SizedBox(width: 5),
                      _RpePill(rpe: te.targetRpe!),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.tune,
                          size: 18,
                          color: accent.withValues(alpha: 0.7)),
                      onPressed: () => onEditExercise(te, exercise),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.6)),
                      onPressed: () => onDeleteExercise(te),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
            // ── Add exercise to circuit ───────────────────────────────────
            TextButton.icon(
              onPressed: onAddExercise,
              icon: Icon(Icons.add, size: 16, color: accent),
              label: Text('Add exercise to circuit',
                  style: TextStyle(color: accent, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rest stepper widget ────────────────────────────────────────────────────────

class _RestStepper extends StatefulWidget {
  final String label;
  final int value;
  final bool allowZero;
  final ValueChanged<int> onChanged;

  const _RestStepper({
    required this.label,
    required this.value,
    this.allowZero = false,
    required this.onChanged,
  });

  @override
  State<_RestStepper> createState() => _RestStepperState();
}

class _RestStepperState extends State<_RestStepper> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.allowZero ? 0 : 15;
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 18),
        const SizedBox(width: 8),
        Text(widget.label),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove, size: 16),
          onPressed: _value > min
              ? () {
                  setState(() =>
                      _value = (_value - 15).clamp(min, 600));
                  widget.onChanged(_value);
                }
              : null,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _value == 0 ? 'None' : '${_value}s',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 16),
          onPressed: _value < 600
              ? () {
                  setState(() =>
                      _value = (_value + 15).clamp(min, 600));
                  widget.onChanged(_value);
                }
              : null,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

// ── Exercise picker sheet ──────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final Future<Exercise?> Function(String name, String category, bool isTimed)
      onCreateNew;

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
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    final showCreateOption = _query.trim().isNotEmpty &&
        !filtered
            .any((e) => e.name.toLowerCase() == _query.trim().toLowerCase());

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
                if (showCreateOption)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text('Create "${_query.trim()}"'),
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
    final categories = ['Push', 'Pull', 'Legs', 'Core', 'Cardio', 'Other'];
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

// ── Edit exercise dialog ───────────────────────────────────────────────────────

class _ExerciseConfig {
  final int sets;
  final int repMin;
  final int repMax;
  final String notes;
  final bool isTimed;
  final int? restBetweenSetsSeconds;
  final int? restAfterExerciseSeconds;
  final double? targetRpe;
  final String? videoUrl;
  const _ExerciseConfig({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.notes,
    required this.isTimed,
    this.restBetweenSetsSeconds,
    this.restAfterExerciseSeconds,
    this.targetRpe,
    this.videoUrl,
  });
}

class _EditExerciseDialog extends ConsumerStatefulWidget {
  final WodTemplateExercise entry;
  final Exercise exercise;
  final bool inCircuit;
  const _EditExerciseDialog({
    required this.entry,
    required this.exercise,
    this.inCircuit = false,
  });

  @override
  ConsumerState<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends ConsumerState<_EditExerciseDialog> {
  static const List<int> _steps = [
    10, 20, 30, 45,
    60, 90, 120, 150, 180, 210, 240, 270, 300,
    360, 420, 480, 540, 600,
  ];

  static const List<String> _repItems = [
    '1','2','3','4','5','6','7','8','9','10',
    '11','12','13','14','15','16','17','18','19','20',
    '21','22','23','24','25','26','27','28','29','30',
    '35','40','45','50',
  ];
  static const List<int> _repValues = [
    1,2,3,4,5,6,7,8,9,10,
    11,12,13,14,15,16,17,18,19,20,
    21,22,23,24,25,26,27,28,29,30,
    35,40,45,50,
  ];
  static const List<String> _rpeItems = [
    'NONE','6','6.5','7','7.5','8','8.5','9','9.5','10',
  ];
  static const List<double?> _rpeValues = [
    null,6,6.5,7,7.5,8,8.5,9,9.5,10,
  ];

  static int _nearestIdx(int seconds) {
    int best = 0;
    int bestDiff = (seconds - _steps[0]).abs();
    for (int i = 1; i < _steps.length; i++) {
      final diff = (seconds - _steps[i]).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  late int _sets;
  late int _durationIdx;
  late int _restBetweenSets;
  late int _restAfterExercise;
  late int _repMaxIndex;
  late int _rpeIndex;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _videoUrlCtrl;

  @override
  void initState() {
    super.initState();
    _sets = widget.entry.targetSets;
    _restBetweenSets = widget.entry.restBetweenSetsSeconds ?? 90;
    _restAfterExercise = widget.entry.restSeconds ?? 90;

    if (widget.exercise.isTimed) {
      _durationIdx = _nearestIdx(widget.entry.repRangeMin);
    } else {
      _durationIdx = _nearestIdx(30);
    }

    // Find closest repMax in _repValues
    final repMax = widget.entry.repRangeMax.clamp(1, 50);
    _repMaxIndex = _repValues.indexWhere((v) => v >= repMax);
    if (_repMaxIndex < 0) _repMaxIndex = _repValues.length - 1;

    // Find RPE index
    final rpe = widget.entry.targetRpe;
    if (rpe == null) {
      _rpeIndex = 0;
    } else {
      _rpeIndex = _rpeValues.indexWhere((v) => v == rpe);
      if (_rpeIndex < 0) _rpeIndex = 0;
    }

    _notesCtrl = TextEditingController(text: widget.entry.notes ?? '');
    _videoUrlCtrl = TextEditingController(text: widget.entry.videoUrl ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final repMax = widget.exercise.isTimed ? _steps[_durationIdx] : _repValues[_repMaxIndex];
    final repMin = widget.exercise.isTimed ? repMax : (repMax * 0.8).round();
    Navigator.pop(context, _ExerciseConfig(
      sets: _sets,
      repMin: repMin,
      repMax: repMax,
      notes: _notesCtrl.text,
      isTimed: widget.exercise.isTimed,
      restBetweenSetsSeconds: _restBetweenSets == 90 ? null : _restBetweenSets,
      restAfterExerciseSeconds: _restAfterExercise == 90 ? null : _restAfterExercise,
      targetRpe: _rpeValues[_rpeIndex],
      videoUrl: _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
    ));
  }

  Future<Exercise?> _createAndPickVariationExercise(
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

  Future<void> _showAddVariationPicker(
      List<Exercise> allExercises, List<Exercise> variations) async {
    final variationIds = variations.map((s) => s.id).toSet();
    final choices = allExercises
        .where((e) => e.id != widget.exercise.id && !variationIds.contains(e.id))
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ExercisePickerSheet(
        exercises: choices,
        onCreateNew: _createAndPickVariationExercise,
      ),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(databaseProvider)
        .exerciseVariationsDao
        .addVariation(widget.exercise.id, picked.id);
    if (!mounted) return;
    ref.invalidate(variationsForExerciseProvider(widget.exercise.id));
    messenger.showSnackBar(
      SnackBar(content: Text('${picked.name} added as a variation')),
    );
  }

  Future<void> _removeVariation(Exercise variation) async {
    await ref
        .read(databaseProvider)
        .exerciseVariationsDao
        .removeVariation(widget.exercise.id, variation.id);
    if (!mounted) return;
    ref.invalidate(variationsForExerciseProvider(widget.exercise.id));
  }

  Widget _buildVariationsSection() {
    final allExercisesAsync = ref.watch(exercisesProvider);
    final variationsAsync =
        ref.watch(variationsForExerciseProvider(widget.exercise.id));
    final allExercises = allExercisesAsync.valueOrNull ?? const <Exercise>[];

    return variationsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Could not load variations: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (variations) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Label('VARIATIONS'),
              const Spacer(),
              TextButton.icon(
                onPressed: allExercisesAsync.hasValue
                    ? () => _showAddVariationPicker(allExercises, variations)
                    : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (variations.isEmpty)
            Text(
              'No variations yet.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            )
          else
            ...variations.map(
              (variation) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                  title: Text(
                    variation.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    variation.category,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.75),
                    ),
                    onPressed: () => _removeVariation(variation),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141428),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 20),
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                exercise.category,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 22),

              _buildVariationsSection(),
              const SizedBox(height: 18),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 20),

              // SETS (hidden for circuit exercises)
              if (!widget.inCircuit) ...[
                const _Label('SETS'),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleBtn(
                      icon: Icons.remove,
                      onTap: () =>
                          setState(() => _sets = (_sets - 1).clamp(1, 10)),
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
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 36),
                    _CircleBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _sets = (_sets + 1).clamp(1, 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 20),
              ],

              // DURATION or REPS + RPE
              if (exercise.isTimed) ...[
                const _Label('DURATION'),
                const SizedBox(height: 12),
                DrumPicker(
                  items: _steps.map(_fmtSec).toList(),
                  selectedIndex: _durationIdx,
                  onChanged: (i) => setState(() => _durationIdx = i),
                  accentColor: const Color(0xFF818CF8),
                  backgroundColor: const Color(0xFF141428),
                  height: 160,
                  itemExtent: 48,
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('TARGET REPS'),
                          const SizedBox(height: 12),
                          DrumPicker(
                            items: _repItems,
                            selectedIndex: _repMaxIndex,
                            onChanged: (i) => setState(() => _repMaxIndex = i),
                            accentColor: const Color(0xFF818CF8),
                            backgroundColor: const Color(0xFF141428),
                            height: 160,
                            itemExtent: 48,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              _Label('RPE'),
                              SizedBox(width: 4),
                              _OptPill(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DrumPicker(
                            items: _rpeItems,
                            selectedIndex: _rpeIndex,
                            onChanged: (i) => setState(() => _rpeIndex = i),
                            accentColor: const Color(0xFFFBBF24),
                            backgroundColor: const Color(0xFF141428),
                            height: 160,
                            itemExtent: 48,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              Divider(color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 12),

              if (!widget.inCircuit) ...[
                const _Label('REST BETWEEN SETS'),
                const SizedBox(height: 8),
                _RestStepper(
                  label: 'Between sets',
                  value: _restBetweenSets,
                  allowZero: false,
                  onChanged: (v) => setState(() => _restBetweenSets = v),
                ),
                const SizedBox(height: 16),
                const _Label('REST AFTER EXERCISE'),
                const SizedBox(height: 8),
                _RestStepper(
                  label: 'After exercise',
                  value: _restAfterExercise,
                  allowZero: true,
                  onChanged: (v) => setState(() => _restAfterExercise = v),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 12),
              ],

              // REFERENCE VIDEO
              const _Label('REFERENCE VIDEO'),
              const SizedBox(height: 4),
              const _OptPill(),
              const SizedBox(height: 8),
              _VideoUrlField(controller: _videoUrlCtrl),

              const SizedBox(height: 16),

              // COACHING NOTE
              const _Label('COACHING NOTE'),
              const SizedBox(height: 4),
              const _OptPill(),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. pause 1s at chest…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.09)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),

              const SizedBox(height: 22),

              // SAVE button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _onSave,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
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

class _OptPill extends StatelessWidget {
  const _OptPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'optional',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
        ),
      ),
    );
  }
}

// ── Reps/duration pill ─────────────────────────────────────────────────────────

class _RepsPill extends StatelessWidget {
  final WodTemplateExercise te;
  final bool isTimed;
  const _RepsPill({required this.te, required this.isTimed});

  @override
  Widget build(BuildContext context) {
    final label = isTimed
        ? _fmtSec(te.repRangeMin)
        : '${te.repRangeMax} reps';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white38,
        ),
      ),
    );
  }
}

// ── RPE pill ───────────────────────────────────────────────────────────────────

class _RpePill extends StatelessWidget {
  final double rpe;
  const _RpePill({required this.rpe});

  @override
  Widget build(BuildContext context) {
    final label = '@${rpe == rpe.roundToDouble() ? rpe.toInt() : rpe}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFBBF24),
        ),
      ),
    );
  }
}

// ── Rest pill ──────────────────────────────────────────────────────────────────

class _RestPill extends StatelessWidget {
  final String label;
  const _RestPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color.fromRGBO(52, 211, 153, 0.7),
        ),
      ),
    );
  }
}

// ── Video URL field ────────────────────────────────────────────────────────────

class _VideoUrlField extends StatelessWidget {
  final TextEditingController controller;
  const _VideoUrlField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.url,
      style: TextStyle(
        fontSize: 13,
        color: Colors.white.withValues(alpha: 0.65),
      ),
      decoration: InputDecoration(
        hintText: 'Paste a YouTube URL…',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.all(12),
          child: _YouTubeIcon(),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        isDense: true,
      ),
    );
  }
}

class _YouTubeIcon extends StatelessWidget {
  const _YouTubeIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 14,
      child: CustomPaint(painter: _YTPainter()),
    );
  }
}

class _YTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFFF0000);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(3),
    );
    canvas.drawRRect(rrect, bgPaint);
    final triPaint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width * 0.38, size.height * 0.22)
      ..lineTo(size.width * 0.72, size.height * 0.5)
      ..lineTo(size.width * 0.38, size.height * 0.78)
      ..close();
    canvas.drawPath(path, triPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
