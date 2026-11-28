import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../database/daos/exercises_dao.dart' show ExerciseDeleteOutcome;
import '../../models/exercise_muscle_seed.dart';
import '../../models/exercise_tracking_mode.dart';
import '../../providers/challenges_providers.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../providers/home_providers.dart';
import '../../providers/muscle_volume_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_background.dart';
import 'widgets/muscle_assignment_sheet.dart';

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
  bool _customOnly = false;
  bool _showArchived = false;

  static const _needsReviewGroup = 'Needs review';
  static const _untrackedGroup = 'Cardio / Untracked';

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

  // Groups exercises: "Needs review" first (design.md §5.4), then by
  // primary muscle (region order, per kMusclesByRegion), then exercises
  // with no active primary assignment ("Cardio / Untracked") last.
  Map<String, List<Exercise>> _group(
    List<Exercise> exercises,
    Map<int, List<ExerciseMuscle>> muscleMap,
  ) {
    final filtered = _query.isEmpty
        ? exercises
        : exercises
            .where((e) => e.name.toLowerCase().contains(_query))
            .toList();

    final Map<String, List<Exercise>> grouped = {};
    for (final e in filtered) {
      String key;
      if (e.muscleNeedsReview) {
        key = _needsReviewGroup;
      } else {
        final rows = muscleMap[e.id] ?? const <ExerciseMuscle>[];
        final primary = rows
            .where((m) => m.role == kMuscleRolePrimary)
            .map((m) => m.muscle)
            .firstOrNull;
        key = primary ?? _untrackedGroup;
      }
      (grouped[key] ??= []).add(e);
    }
    return grouped;
  }

  Future<void> _showExerciseDialog({
    Exercise? existing,
    required List<Exercise> all,
    required Map<int, List<ExerciseMuscle>> muscleMap,
  }) async {
    final initialAssignments = existing != null
        ? (muscleMap[existing.id] ?? const <ExerciseMuscle>[])
            .map((m) => ExerciseMuscleSeed(
                  m.muscle,
                  m.role == kMuscleRolePrimary
                      ? ExerciseMuscleRole.primary
                      : ExerciseMuscleRole.secondary,
                ))
            .toList()
        : <ExerciseMuscleSeed>[];

    final nameController = TextEditingController(text: existing?.name ?? '')
      ..selection =
          TextSelection.collapsed(offset: existing?.name.length ?? 0);
    ExerciseTrackingMode trackingMode =
        existing?.mode ?? ExerciseTrackingMode.weightedReps;
    List<ExerciseMuscleSeed> assignments = List.from(initialAssignments);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final primarySeed = assignments
              .where((a) => a.role == ExerciseMuscleRole.primary)
              .firstOrNull;
          final secondarySeeds = assignments
              .where((a) => a.role == ExerciseMuscleRole.secondary)
              .toList();

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text(
                    existing == null ? 'New Exercise' : 'Edit Exercise',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),

                // Scrollable content
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextFormField(
                        controller: nameController,
                        autofocus: existing == null,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 24),

                      // Muscles label
                      Text(
                        'MUSCLES WORKED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        existing != null && existing.muscleNeedsReview
                            ? 'This exercise needs review — confirm the muscles it works.'
                            : 'Pick 1 primary muscle and any secondary muscles.',
                        style: TextStyle(
                          fontSize: 11,
                          color: existing != null && existing.muscleNeedsReview
                              ? const Color(0xFFFBBF24)
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Selection summary + edit button
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (primarySeed == null)
                            Text(
                              'No muscles assigned yet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            )
                          else ...[
                            _AssignmentPill(
                              label: primarySeed.muscle,
                              isPrimary: true,
                            ),
                            for (final s in secondarySeeds)
                              _AssignmentPill(
                                label: s.muscle,
                                isPrimary: false,
                              ),
                          ],
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
                            setSheetState(() => assignments = result);
                          }
                        },
                        icon: const Icon(Icons.tune, size: 16),
                        label: Text(assignments.isEmpty
                            ? 'Assign muscles'
                            : 'Edit muscles'),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'TRACKING MODE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ExerciseTrackingMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ExerciseTrackingMode.weightedReps,
                              label: Text('Weighted', style: TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: ExerciseTrackingMode.bodyweightReps,
                              label: Text('Bodyweight', style: TextStyle(fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: ExerciseTrackingMode.timed,
                              label: Text('Timed', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          selected: {trackingMode},
                          onSelectionChanged: (sel) => setSheetState(
                              () => trackingMode = sel.first),
                        ),
                      ),
                    ],
                  ),
                ),

                // Full-width Save button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: ValueListenableBuilder(
                    valueListenable: nameController,
                    builder: (_, value, child) => FilledButton(
                      onPressed: (nameController.text.trim().isEmpty ||
                              primarySeed == null)
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final derivedCategory =
                                  regionForMuscle(primarySeed.muscle) ??
                                      primarySeed.muscle;
                              final dao =
                                  ref.read(databaseProvider).exercisesDao;
                              int exerciseId;
                              if (existing == null) {
                                exerciseId =
                                    await dao.insertExercise(ExercisesCompanion(
                                  name: Value(name),
                                  category: Value(derivedCategory),
                                  isTimed: Value(
                                      trackingMode == ExerciseTrackingMode.timed),
                                  trackingMode: Value(trackingMode.dbValue),
                                ));
                              } else {
                                await dao.updateExercise(ExercisesCompanion(
                                  id: Value(existing.id),
                                  name: Value(name),
                                  category: Value(derivedCategory),
                                  isTimed: Value(
                                      trackingMode == ExerciseTrackingMode.timed),
                                  trackingMode: Value(trackingMode.dbValue),
                                ));
                                exerciseId = existing.id;
                              }
                              await dao.setMusclesForExercise(
                                  exerciseId, assignments);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(primarySeed == null
                          ? 'Assign a Primary Muscle to Save'
                          : 'Save'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text(
          'Remove "${exercise.name}" from the library? '
          'If it has logged workout history, it will be archived instead '
          'and your logs will be kept.',
        ),
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
    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await ref
          .read(databaseProvider)
          .exercisesDao
          .deleteOrArchiveExercise(exercise.id);
      final message = outcome == ExerciseDeleteOutcome.hardDeleted
          ? 'Deleted "${exercise.name}"'
          : '"${exercise.name}" archived — it has workout history, so '
              'your logs are kept.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete "${exercise.name}": $e')),
      );
    }
  }

  Future<void> _startMergeFlow(
    Exercise source,
    List<Exercise> allIncludingArchived,
  ) async {
    final candidates = allIncludingArchived
        .where((e) => e.id != source.id && !e.archived)
        .toList();

    final target = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141428),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MergeTargetPickerSheet(
        source: source,
        candidates: candidates,
      ),
    );
    if (target == null || !mounted) return;

    final dao = ref.read(databaseProvider).exercisesDao;
    final impact = await dao.previewMergeImpact(source.id);
    if (!mounted) return;

    final details = <String>[
      '• ${impact.setCount} logged workout set${impact.setCount == 1 ? '' : 's'}',
      if (impact.templateCount > 0)
        '• ${impact.templateCount} program / flash WOD entr${impact.templateCount == 1 ? 'y' : 'ies'}',
      if (impact.challengeCount > 0)
        '• ${impact.challengeCount} challenge${impact.challengeCount == 1 ? '' : 's'}',
      if (impact.noteCount > 0)
        '• ${impact.noteCount} note${impact.noteCount == 1 ? '' : 's'}',
    ].join('\n');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Merge Exercise'),
        content: Text(
          'Merge "${source.name}" into "${target.name}"?\n\n'
          '$details\n\n'
          'All history and references will move to "${target.name}", and "${source.name}" will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await dao.mergeExerciseInto(
        sourceId: source.id,
        targetId: target.id,
      );
      ref.invalidate(nextWodProvider);
      ref.invalidate(progressiveOverloadProvider);
      ref.invalidate(weeklyMuscleVolumeProvider);
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(completedChallengesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Merged "${source.name}" into "${target.name}" (${summary.setCount} sets moved)',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Merge failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allExercisesAsync = ref.watch(allExercisesIncludingArchivedProvider);
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
              if (allExercisesAsync.valueOrNull != null)
                Builder(
                  builder: (context) {
                    final all = allExercisesAsync.valueOrNull!;
                    final customCount =
                        all.where((e) => !e.archived && e.canonicalKey == null).length;
                    final archivedCount = all.where((e) => e.archived).length;
                    if (customCount == 0 && archivedCount == 0 && !_customOnly && !_showArchived) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(
                              'Custom ($customCount)',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _customOnly,
                            onSelected: (v) => setState(() => _customOnly = v),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (archivedCount > 0 || _showArchived) ...[
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(
                                'Archived ($archivedCount)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _showArchived,
                              onSelected: (v) =>
                                  setState(() => _showArchived = v),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              Expanded(
                child: allExercisesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (allExercises) {
                    final exercises = allExercises.where((e) {
                      if (!_showArchived && e.archived) return false;
                      if (_customOnly && e.canonicalKey != null) return false;
                      return true;
                    }).toList();
                    final muscleMap = muscleMapAsync.valueOrNull ?? {};
                    final grouped = _group(exercises, muscleMap);
                    if (grouped.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? 'No matching exercises.'
                              : 'No results for "$_query"',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      );
                    }
                    // Sort groups: Needs review first, then region/muscle
                    // order (kMuscleGroups), then Cardio / Untracked last.
                    final groupOrder = [
                      _needsReviewGroup,
                      ...kMuscleGroups,
                      _untrackedGroup,
                    ];
                    final categories = grouped.keys.toList()
                      ..sort((a, b) {
                        final ai = groupOrder.indexOf(a);
                        final bi = groupOrder.indexOf(b);
                        final ai2 = ai < 0 ? groupOrder.length : ai;
                        final bi2 = bi < 0 ? groupOrder.length : bi;
                        return ai2.compareTo(bi2);
                      });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
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
                              isNeedsReview: cat == _needsReviewGroup,
                            );
                          }
                          remaining--;
                          final items = grouped[cat]!;
                          if (remaining < items.length) {
                            final exercise = items[remaining];
                            final muscles =
                                muscleMap[exercise.id] ?? const <ExerciseMuscle>[];
                            return _ExerciseRow(
                              exercise: exercise,
                              muscles: muscles,
                              onTap: () => _showExerciseDialog(
                                existing: exercise,
                                all: allExercises,
                                muscleMap: muscleMap,
                              ),
                              onMerge: () =>
                                  _startMergeFlow(exercise, allExercises),
                              onLongPress: () => _confirmDelete(exercise),
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
      floatingActionButton: allExercisesAsync.whenOrNull(
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

class _AssignmentPill extends StatelessWidget {
  final String label;
  final bool isPrimary;
  const _AssignmentPill({required this.label, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final color =
        isPrimary ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isPrimary ? '● $label' : label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final List<ExerciseMuscle> muscles;
  final VoidCallback onTap;
  final VoidCallback onMerge;
  final VoidCallback onLongPress;
  const _ExerciseRow({
    required this.exercise,
    required this.muscles,
    required this.onTap,
    required this.onMerge,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: exercise.muscleNeedsReview
                    ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.09),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: exercise.archived
                              ? Colors.white.withValues(alpha: 0.55)
                              : null,
                        ),
                      ),
                    ),
                    if (exercise.archived) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'ARCHIVED',
                        color: Color(0xFFF97316),
                      ),
                    ] else if (exercise.canonicalKey == null) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'CUSTOM',
                        color: Color(0xFF38BDF8),
                      ),
                    ],
                    if (exercise.muscleNeedsReview) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'NEEDS REVIEW',
                        color: Color(0xFFFBBF24),
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
                    if (exercise.isTimedMode) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'TIMED',
                        color: Color(0xFF6366F1),
                      ),
                    ] else if (exercise.isBodyweightReps) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'BODYWEIGHT',
                        color: Color(0xFF34D399),
                      ),
                    ],
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onMerge,
                      icon: Icon(
                        Icons.merge_type_rounded,
                        size: 19,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      tooltip: 'Merge into another exercise',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                // Muscle chips
                if (muscles.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final m in muscles)
                        _AssignmentPill(
                          label: m.muscle,
                          isPrimary: m.role == kMuscleRolePrimary,
                        ),
                    ],
                  ),
                ] else if (!exercise.muscleNeedsReview) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Not tracked for muscle volume',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleGroupHeader extends StatelessWidget {
  const _MuscleGroupHeader({
    required this.label,
    required this.count,
    this.isNeedsReview = false,
  });

  final String label;
  final int count;
  final bool isNeedsReview;

  @override
  Widget build(BuildContext context) {
    final color = isNeedsReview
        ? const Color(0xFFFBBF24)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
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

class _MergeTargetPickerSheet extends StatefulWidget {
  final Exercise source;
  final List<Exercise> candidates;

  const _MergeTargetPickerSheet({
    required this.source,
    required this.candidates,
  });

  @override
  State<_MergeTargetPickerSheet> createState() =>
      _MergeTargetPickerSheetState();
}

class _MergeTargetPickerSheetState extends State<_MergeTargetPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.candidates
        : widget.candidates
            .where((e) => e.name.toLowerCase().contains(_query))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
            child: Text(
              'Merge "${widget.source.name}" into…',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Pick the exercise that should receive all logged sets, WOD entries, challenges, and notes.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search target exercise…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching target exercises',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final item = filtered[i];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: item.canonicalKey != null
                            ? const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF34D399),
                              )
                            : null,
                        onTap: () => Navigator.pop(ctx, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
