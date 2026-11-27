import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../models/exercise_tracking_mode.dart';
import '../../../models/exercise_muscle_seed.dart';
import '../../../providers/database_provider.dart';
import '../../../providers/exercise_providers.dart';
import '../../../utils/constants.dart';
import '../../settings/widgets/muscle_assignment_sheet.dart';

class ExerciseLibrarySheet extends ConsumerStatefulWidget {
  final String title;
  final void Function(Exercise) onSelected;
  const ExerciseLibrarySheet({super.key, required this.title, required this.onSelected});

  @override
  ConsumerState<ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends ConsumerState<ExerciseLibrarySheet> {
  String _query = '';
  List<Exercise> _all = [];
  Map<int, List<ExerciseMuscle>> _muscleMap = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // One-shot fetches (not a reactive `.watch()`/StreamProvider): this
    // sheet is short-lived, so there's no need to keep a live Drift stream
    // subscription open for the athlete's whole exercise-picking flow.
    final dao = ref.read(databaseProvider).exercisesDao;
    Future.wait([dao.getAllExercises(), dao.getAllMuscleAssignmentMap()])
        .then((results) {
      if (mounted) {
        setState(() {
          _all = results[0] as List<Exercise>;
          _muscleMap = results[1] as Map<int, List<ExerciseMuscle>>;
          _loading = false;
        });
      }
    });
  }

  List<Exercise> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final assignments = await showMuscleAssignmentSheet(
      context,
      initial: const [],
    );
    if (assignments == null || !mounted) return;

    final primary = assignments
        .where((m) => m.role == ExerciseMuscleRole.primary)
        .map((m) => m.muscle)
        .firstOrNull;
    final category =
        (primary != null ? regionForMuscle(primary) : null) ?? primary ?? 'Other';

    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(ExercisesCompanion(
      name: Value(name),
      category: Value(category),
    ));
    if (assignments.isNotEmpty) {
      await db.exercisesDao.setMusclesForExercise(id, assignments);
    }
    ref.invalidate(exercisesProvider);
    ref.invalidate(exerciseMuscleMapProvider);
    final created = (await db.exercisesDao.getAllExercises())
        .firstWhere((e) => e.id == id);
    if (mounted) widget.onSelected(created);
  }

  bool _isUnmapped(Exercise ex, Map<int, List<ExerciseMuscle>> muscleMap) {
    if (kDefaultCardioExerciseNames.contains(ex.name)) return false;
    if (ex.muscleNeedsReview) return true;
    final assignments = muscleMap[ex.id] ?? const [];
    return !assignments.any((m) => m.role == kMuscleRolePrimary);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showCreate = _query.isNotEmpty &&
        filtered.every((e) => e.name.toLowerCase() != _query.toLowerCase());
    final muscleMap = _muscleMap;

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(controller: scroll, children: [
                    if (showCreate)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                        title: Text('Create "$_query"', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Add to exercise library'),
                        onTap: () => _createAndSelect(_query),
                      ),
                    for (final ex in filtered)
                      ListTile(
                        title: Row(
                          children: [
                            Flexible(child: Text(ex.name)),
                            if (_isUnmapped(ex, muscleMap)) ...[
                              const SizedBox(width: 8),
                              const _UnmappedPill(),
                            ],
                          ],
                        ),
                        subtitle: Text(ex.mode.shortLabel, style: const TextStyle(fontSize: 11)),
                        onTap: () => widget.onSelected(ex),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _UnmappedPill extends StatelessWidget {
  const _UnmappedPill();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF59E0B);
    return Semantics(
      label: 'This exercise will not count toward muscle volume until assigned.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: amber.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Unmapped',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: amber),
        ),
      ),
    );
  }
}
