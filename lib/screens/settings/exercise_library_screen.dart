import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_background.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Groups exercises by primary muscle (first entry in muscleMap).
  // Exercises with no muscles go into 'Other'.
  Map<String, List<Exercise>> _group(
    List<Exercise> exercises,
    Map<int, List<String>> muscleMap,
  ) {
    final filtered = _query.isEmpty
        ? exercises
        : exercises
            .where((e) => e.name.toLowerCase().contains(_query))
            .toList();

    final Map<String, List<Exercise>> grouped = {};
    for (final e in filtered) {
      final primary = muscleMap[e.id]?.isNotEmpty == true
          ? muscleMap[e.id]!.first
          : 'Other';
      (grouped[primary] ??= []).add(e);
    }
    return grouped;
  }

  Future<void> _showExerciseDialog({
    Exercise? existing,
    required List<Exercise> all,
    required Map<int, List<String>> muscleMap,
  }) async {
    List<String> initialMuscles = existing != null
        ? (muscleMap[existing.id] ?? [])
        : [];

    final nameController =
        TextEditingController(text: existing?.name ?? '')
          ..selection = TextSelection.collapsed(
              offset: existing?.name.length ?? 0);
    bool isTimed = existing?.isTimed ?? false;
    List<String> selectedMuscles = List.from(initialMuscles);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141428),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                existing == null ? 'New Exercise' : 'Edit Exercise',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.3,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    TextFormField(
                      controller: nameController,
                      autofocus: existing == null,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Muscle groups
                    Text(
                      'MUSCLE GROUPS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to add. First = primary. Tap again to remove.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kMuscleGroups.map((muscle) {
                        final idx = selectedMuscles.indexOf(muscle);
                        final isPrimary = idx == 0;
                        final isSelected = idx >= 0;
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            if (isSelected) {
                              selectedMuscles.remove(muscle);
                            } else {
                              selectedMuscles.add(muscle);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPrimary
                                  ? const Color(0xFF6366F1)
                                      .withValues(alpha: 0.2)
                                  : isSelected
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isPrimary
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.5)
                                    : isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              muscle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isPrimary
                                    ? const Color(0xFFA5B4FC)
                                    : isSelected
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Selection summary
                    if (selectedMuscles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        children: [
                          for (int i = 0; i < selectedMuscles.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: i == 0
                                      ? const Color(0xFF6366F1)
                                          .withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.09),
                                ),
                              ),
                              child: Text(
                                i == 0
                                    ? '● ${selectedMuscles[i]}'
                                    : selectedMuscles[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: i == 0
                                      ? const Color(0xFF818CF8)
                                      : Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Timed toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Timed exercise'),
                      value: isTimed,
                      onChanged: (v) => setDialogState(() => isTimed = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder(
                  valueListenable: nameController,
                  builder: (_, __, ___) => FilledButton(
                    onPressed: nameController.text.trim().isEmpty
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final dao =
                                ref.read(databaseProvider).exercisesDao;
                            int exerciseId;
                            if (existing == null) {
                              exerciseId =
                                  await dao.insertExercise(ExercisesCompanion(
                                name: Value(name),
                                isTimed: Value(isTimed),
                              ));
                            } else {
                              await dao.updateExercise(ExercisesCompanion(
                                id: Value(existing.id),
                                name: Value(name),
                                isTimed: Value(isTimed),
                              ));
                              exerciseId = existing.id;
                            }
                            await dao.setMusclesForExercise(
                                exerciseId, selectedMuscles);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('Save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Remove "${exercise.name}" from the library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(databaseProvider)
          .exercisesDao
          .deleteExercise(exercise.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final muscleMapAsync = ref.watch(exerciseMuscleMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: exercisesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (exercises) {
                    final muscleMap =
                        muscleMapAsync.valueOrNull ?? {};
                    final grouped = _group(exercises, muscleMap);
                    if (grouped.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No exercises yet. Tap + to add one.'
                              : 'No results for "$_query"',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      );
                    }
                    // Sort groups: kMuscleGroups order first, then 'Other'
                    final groupOrder = [...kMuscleGroups, 'Other'];
                    final categories = grouped.keys.toList()
                      ..sort((a, b) {
                        final ai = groupOrder.indexOf(a);
                        final bi = groupOrder.indexOf(b);
                        final ai2 = ai < 0 ? groupOrder.length : ai;
                        final bi2 = bi < 0 ? groupOrder.length : bi;
                        return ai2.compareTo(bi2);
                      });

                    return ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: categories.fold<int>(
                        0,
                        (sum, cat) => sum + 1 + grouped[cat]!.length,
                      ),
                      itemBuilder: (_, index) {
                        var remaining = index;
                        for (final cat in categories) {
                          if (remaining == 0) {
                            return _MuscleGroupHeader(
                              label: cat,
                              count: grouped[cat]!.length,
                            );
                          }
                          remaining--;
                          final items = grouped[cat]!;
                          if (remaining < items.length) {
                            final exercise = items[remaining];
                            final muscles = muscleMap[exercise.id] ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _showExerciseDialog(
                                    existing: exercise,
                                    all: exercises,
                                    muscleMap: muscleMap,
                                  ),
                                  onLongPress: () =>
                                      _confirmDelete(exercise),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.09),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding:
                                        const EdgeInsets.fromLTRB(
                                            14, 13, 14, 11),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Name row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                exercise.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                            if (exercise.isTimed) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                          0xFF6366F1)
                                                      .withValues(
                                                          alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(6),
                                                  border: Border.all(
                                                    color: const Color(
                                                            0xFF6366F1)
                                                        .withValues(
                                                            alpha: 0.2),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'TIMED',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        Color(0xFF818CF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        // Muscle chips
                                        if (muscles.isNotEmpty) ...[
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 5,
                                            runSpacing: 4,
                                            children: [
                                              for (int i = 0;
                                                  i < muscles.length;
                                                  i++)
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: i == 0
                                                        ? const Color(
                                                                0xFF6366F1)
                                                            .withValues(
                                                                alpha:
                                                                    0.15)
                                                        : Colors.white
                                                            .withValues(
                                                                alpha:
                                                                    0.05),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(7),
                                                    border: Border.all(
                                                      color: i == 0
                                                          ? const Color(
                                                                  0xFF6366F1)
                                                              .withValues(
                                                                  alpha:
                                                                      0.28)
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha:
                                                                      0.09),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    muscles[i],
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: i == 0
                                                          ? FontWeight.w700
                                                          : FontWeight.w600,
                                                      color: i == 0
                                                          ? const Color(
                                                              0xFF818CF8)
                                                          : Colors.white
                                                              .withValues(
                                                                  alpha:
                                                                      0.38),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          remaining -= items.length;
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: exercisesAsync.whenOrNull(
        data: (exercises) => FloatingActionButton(
          onPressed: () => _showExerciseDialog(
            all: exercises,
            muscleMap: muscleMapAsync.valueOrNull ?? {},
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _MuscleGroupHeader extends StatelessWidget {
  const _MuscleGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}
