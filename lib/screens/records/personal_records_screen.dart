import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../database/daos/sessions_dao.dart';
import '../../database/daos/sets_dao.dart';
import '../../models/personal_record_entry.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../providers/home_providers.dart';
import '../../providers/muscle_volume_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../providers/session_providers.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import '../history/session_detail_screen.dart';
import 'exercise_history_screen.dart';

class PersonalRecordsScreen extends ConsumerStatefulWidget {
  const PersonalRecordsScreen({super.key});

  @override
  ConsumerState<PersonalRecordsScreen> createState() =>
      _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends ConsumerState<PersonalRecordsScreen> {
  // 0 = Goals, 1 = Milestones, 2 = All Lifts, 3 = Log
  int _selectedSegment = 0;
  String _selectedRegion = 'All';
  String _searchQuery = '';

  static const _regions = [
    'All',
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
  ];

  String _primaryMuscleFor(
    int exerciseId,
    String exerciseName,
    String category,
    Map<int, List<ExerciseMuscle>> muscleMap,
  ) {
    final rows = muscleMap[exerciseId] ?? const [];
    final primaryRow =
        rows.where((r) => r.role == kMuscleRolePrimary).firstOrNull;
    if (primaryRow != null) return primaryRow.muscle;

    final inferred = inferMusclesForExercise(
      Exercise(
        id: exerciseId,
        name: exerciseName,
        category: category,
        isTimed: false,
        archived: false,
        muscleNeedsReview: false,
      ),
    );
    if (inferred.isNotEmpty) return inferred.first.muscle;
    return category.isEmpty ? 'Other' : category;
  }

  String _regionFor(
    int exerciseId,
    String exerciseName,
    String category,
    Map<int, List<ExerciseMuscle>> muscleMap,
  ) {
    final primary =
        _primaryMuscleFor(exerciseId, exerciseName, category, muscleMap);
    final region = regionForMuscle(primary);
    if (region != null) return region;
    if (category.toLowerCase() == 'cardio' ||
        kDefaultCardioExerciseNames
            .any((c) => c.toLowerCase() == exerciseName.toLowerCase())) {
      return 'Conditioning';
    }
    return 'Other';
  }

  /// Smart search ranking:
  ///  - Tier 0: Exact match or singular/plural match ("squat" / "squats")
  ///  - Tier 1: Name starts with query ("squa" -> "Squats" before "Bulgarian Split Squat")
  ///  - Tier 2: A word in the name starts with query, shorter names & logged PRs first
  ///  - Tier 3: Multi-token / substring match in name or primary muscle
  List<Exercise> _smartFilterAndRankExercises({
    required List<Exercise> exercises,
    required String query,
    required Map<int, PersonalRecordEntry> prMap,
    required Map<int, List<ExerciseMuscle>> muscleMap,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      final copy = List<Exercise>.from(exercises);
      copy.sort((a, b) {
        final aHasPr = prMap.containsKey(a.id) ? 0 : 1;
        final bHasPr = prMap.containsKey(b.id) ? 0 : 1;
        if (aHasPr != bHasPr) return aHasPr.compareTo(bHasPr);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return copy;
    }

    final qTokens =
        q.split(RegExp(r'[\s\-_]+')).where((t) => t.isNotEmpty).toList();
    final qSingular = q.endsWith('s') && q.length > 3
        ? q.substring(0, q.length - 1)
        : q;

    int? scoreFor(Exercise ex) {
      final name = ex.name.trim().toLowerCase();
      final nameSingular = name.endsWith('s') && name.length > 3
          ? name.substring(0, name.length - 1)
          : name;
      final words =
          name.split(RegExp(r'[\s\-_()]+')).where((w) => w.isNotEmpty).toList();
      final muscle = _primaryMuscleFor(ex.id, ex.name, ex.category, muscleMap)
          .toLowerCase();

      // Exact or singular/plural match
      if (name == q || nameSingular == qSingular) return 0;

      // Full name starts with query (e.g. "squa" -> "Squats")
      if (name.startsWith(q) || nameSingular.startsWith(qSingular)) {
        // Prefer single-word / shorter names first ("Squats" before "Squat Jump")
        return 10 + words.length;
      }

      // First word equals query
      if (words.isNotEmpty &&
          (words.first == q || words.first == qSingular)) {
        return 25 + words.length;
      }

      // Any word starts with query, and all tokens match
      final allTokensMatch = qTokens.every(
        (t) => name.contains(t) || muscle.contains(t),
      );
      if (!allTokensMatch) return null;

      final wordStartsIdx = words.indexWhere(
        (w) => w.startsWith(q) || w.startsWith(qSingular),
      );
      if (wordStartsIdx != -1) {
        // Fewer words & earlier word position rank higher
        return 50 + words.length * 3 + wordStartsIdx;
      }

      // Substring / multi-token match
      return 200 + name.length;
    }

    final scored = <({Exercise ex, int score})>[];
    for (final ex in exercises) {
      final s = scoreFor(ex);
      if (s != null) {
        scored.add((ex: ex, score: s));
      }
    }

    scored.sort((a, b) {
      final cmp = a.score.compareTo(b.score);
      if (cmp != 0) return cmp;
      final aHasPr = prMap.containsKey(a.ex.id) ? 0 : 1;
      final bHasPr = prMap.containsKey(b.ex.id) ? 0 : 1;
      if (aHasPr != bHasPr) return aHasPr.compareTo(bHasPr);
      final lenCmp = a.ex.name.length.compareTo(b.ex.name.length);
      if (lenCmp != 0) return lenCmp;
      return a.ex.name.toLowerCase().compareTo(b.ex.name.toLowerCase());
    });

    return [for (final item in scored) item.ex];
  }

  Future<void> _promptGoalForExercise(
    BuildContext context, {
    required int exerciseId,
    required String exerciseName,
    PersonalRecordEntry? existingPr,
    ExerciseLiftGoal? existingGoal,
  }) async {
    final defaultWeight = existingGoal?.targetWeightKg ??
        (existingPr != null && existingPr.maxWeightKg > 0
            ? ((existingPr.maxWeightKg + 5.0) * 2).round() / 2.0
            : 60.0);
    final defaultReps = existingGoal?.targetReps ?? 5;

    final weightCtrl = TextEditingController(text: _fmtW(defaultWeight));
    final repsCtrl = TextEditingController(text: '$defaultReps');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Target Goal · $exerciseName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (existingPr != null && existingPr.maxWeightKg > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 16,
                        color: Theme.of(ctx).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Current PR: ${_fmtW(existingPr.maxWeightKg)} kg  (Est. 1RM ~${_fmtW(existingPr.estimatedOneRm)} kg)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        ),
        actions: [
          if (existingGoal != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: Text(
                'Remove Goal',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );

    if (result == 'clear') {
      await removeExerciseLiftGoal(exerciseId);
      ref.invalidate(exerciseGoalsProvider);
    } else if (result == 'save') {
      final w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
      final r = (int.tryParse(repsCtrl.text.trim()) ?? 5).clamp(1, 50);
      if (w != null && w > 0) {
        await saveExerciseLiftGoal(
          exerciseId: exerciseId,
          targetWeightKg: w,
          targetReps: r,
        );
        ref.invalidate(exerciseGoalsProvider);
      }
    }
  }

  Future<void> _showPickExerciseSheet(
    BuildContext context, {
    required String title,
    required List<Exercise> allExercises,
    required Map<int, PersonalRecordEntry> prMap,
    required Map<int, ExerciseLiftGoal> goalsMap,
    required Map<int, List<ExerciseMuscle>> muscleMap,
    required Future<void> Function(Exercise chosen) onChosen,
  }) async {
    // Only non-archived, non-timed, non-cardio exercises
    final weighted = allExercises
        .where((e) =>
            !e.archived &&
            !e.isTimed &&
            !kDefaultCardioExerciseNames
                .any((c) => c.toLowerCase() == e.name.toLowerCase()))
        .toList();

    final chosen = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _smartFilterAndRankExercises(
              exercises: weighted,
              query: filter,
              prMap: prMap,
              muscleMap: muscleMap,
            );
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.92,
              minChildSize: 0.5,
              builder: (_, scrollCtrl) => Padding(
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setSheetState(() => filter = v),
                      decoration: InputDecoration(
                        hintText: 'Search exercise (e.g. Squat, Bench)...',
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
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No exercises matching "$filter".',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final ex = filtered[i];
                                final pr = prMap[ex.id];
                                final existingGoal = goalsMap[ex.id];
                                final primary = _primaryMuscleFor(
                                  ex.id,
                                  ex.name,
                                  ex.category,
                                  muscleMap,
                                );
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  title: Text(
                                    ex.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(
                                    pr != null
                                        ? '$primary · PR ${_fmtW(pr.maxWeightKg)} kg (Est. 1RM ~${_fmtW(pr.estimatedOneRm)} kg)'
                                        : primary,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  trailing: existingGoal != null
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF34D399)
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Goal: ${_fmtW(existingGoal.targetWeightKg)} × ${existingGoal.targetReps}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF34D399),
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.add_circle_outline,
                                          size: 20),
                                  onTap: () => Navigator.pop(ctx, ex),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen != null && context.mounted) {
      await onChosen(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prAsync = ref.watch(personalRecordsProvider);
    final goalsAsync = ref.watch(exerciseGoalsProvider);
    final milestonePrefsAsync = ref.watch(milestonePrefsProvider);
    final allExercisesAsync = ref.watch(exercisesProvider);
    final muscleMapAsync = ref.watch(exerciseMuscleMapProvider);
    final latestBw = ref.watch(latestBodyweightProvider).valueOrNull?.weightKg;
    final profileBw = ref.watch(userProfileProvider).valueOrNull?.weightKg;
    final bodyweightKg = latestBw ?? profileBw ?? 80.0;

    // Active (non-archived) exercises from exercisesProvider
    final allExercises = (allExercisesAsync.valueOrNull ?? const [])
        .where((e) => !e.archived)
        .toList();
    final exerciseById = {for (final e in allExercises) e.id: e};

    // Only keep records for non-archived exercises
    final rawRecords = prAsync.valueOrNull ?? const [];
    final records = rawRecords
        .where((r) =>
            exerciseById.isEmpty || exerciseById.containsKey(r.exerciseId))
        .toList();
    final prMap = {for (final r in records) r.exerciseId: r};

    final goalsMap = goalsAsync.valueOrNull ?? const {};
    final milestonePrefs =
        milestonePrefsAsync.valueOrNull ?? const MilestonePrefs();
    final muscleMap = muscleMapAsync.valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Goals'),
        actions: [
          if (_selectedSegment == 0 || _selectedSegment == 2)
            IconButton(
              icon: const Icon(Icons.flag_rounded),
              tooltip: 'Add Lift Goal',
              onPressed: () => _showPickExerciseSheet(
                context,
                title: 'Choose Lift to Set a Goal',
                allExercises: allExercises,
                prMap: prMap,
                goalsMap: goalsMap,
                muscleMap: muscleMap,
                onChosen: (chosen) => _promptGoalForExercise(
                  context,
                  exerciseId: chosen.id,
                  exerciseName: chosen.name,
                  existingPr: prMap[chosen.id],
                  existingGoal: goalsMap[chosen.id],
                ),
              ),
            )
          else if (_selectedSegment == 1)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Lift to Milestones',
              onPressed: () => _showPickExerciseSheet(
                context,
                title: 'Add Lift to Bodyweight Milestones',
                allExercises: allExercises,
                prMap: prMap,
                goalsMap: goalsMap,
                muscleMap: muscleMap,
                onChosen: (chosen) async {
                  await addOrRestoreMilestoneLift(chosen.id);
                  ref.invalidate(milestonePrefsProvider);
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Column(
            children: [
              // ── 4-Segment Switcher ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _SegmentedBar(
                  selectedIndex: _selectedSegment,
                  onChanged: (i) => setState(() => _selectedSegment = i),
                ),
              ),

              Expanded(
                child: switch (_selectedSegment) {
                  0 => _buildGoalsTab(
                      context,
                      records: records,
                      prMap: prMap,
                      goalsMap: goalsMap,
                      allExercises: allExercises,
                      exerciseById: exerciseById,
                      muscleMap: muscleMap,
                    ),
                  1 => _buildMilestonesTab(
                      context,
                      records: records,
                      prMap: prMap,
                      allExercises: allExercises,
                      exerciseById: exerciseById,
                      goalsMap: goalsMap,
                      muscleMap: muscleMap,
                      milestonePrefs: milestonePrefs,
                      bodyweightKg: bodyweightKg,
                    ),
                  2 => _buildAllLiftsTab(
                      context,
                      records: records,
                      prMap: prMap,
                      goalsMap: goalsMap,
                      muscleMap: muscleMap,
                      bodyweightKg: bodyweightKg,
                    ),
                  _ => const _EmbeddedSessionHistoryTab(),
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Segment 0: Pinned Lift Goals ────────────────────────────────────────────

  Widget _buildGoalsTab(
    BuildContext context, {
    required List<PersonalRecordEntry> records,
    required Map<int, PersonalRecordEntry> prMap,
    required Map<int, ExerciseLiftGoal> goalsMap,
    required List<Exercise> allExercises,
    required Map<int, Exercise> exerciseById,
    required Map<int, List<ExerciseMuscle>> muscleMap,
  }) {
    // Filter out goals belonging to archived/deleted exercises
    final goalEntries = goalsMap.values
        .where(
            (g) => exerciseById.isEmpty || exerciseById.containsKey(g.exerciseId))
        .toList()
      ..sort((a, b) => a.exerciseId.compareTo(b.exerciseId));

    final suggestedLifts = records
        .where((r) => !r.isTimed && !goalsMap.containsKey(r.exerciseId))
        .take(5)
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        MediaQuery.of(context).padding.bottom + 64,
      ),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'PINNED LIFT GOALS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: Colors.white54,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showPickExerciseSheet(
                context,
                title: 'Choose Lift to Set a Goal',
                allExercises: allExercises,
                prMap: prMap,
                goalsMap: goalsMap,
                muscleMap: muscleMap,
                onChosen: (chosen) => _promptGoalForExercise(
                  context,
                  exerciseId: chosen.id,
                  exerciseName: chosen.name,
                  existingPr: prMap[chosen.id],
                  existingGoal: goalsMap[chosen.id],
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Goal',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (goalEntries.isEmpty)
          LiquidGlassContainer(
            borderRadius: 20,
            blurSigma: 10,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag_rounded,
                        color: Color(0xFF34D399), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Set target weights for your key lifts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pin your main lifts (e.g. Bench Press, Squats, RDL, Incline Press) to track your progress toward your target weight & reps.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                if (suggestedLifts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'QUICK-SET FROM YOUR LOGGED LIFTS:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final pr in suggestedLifts)
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            '${pr.exerciseName} (${_fmtW(pr.maxWeightKg)} kg)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () => _promptGoalForExercise(
                            context,
                            exerciseId: pr.exerciseId,
                            exerciseName: pr.exerciseName,
                            existingPr: pr,
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _showPickExerciseSheet(
                      context,
                      title: 'Choose Lift to Set a Goal',
                      allExercises: allExercises,
                      prMap: prMap,
                      goalsMap: goalsMap,
                      muscleMap: muscleMap,
                      onChosen: (chosen) => _promptGoalForExercise(
                        context,
                        exerciseId: chosen.id,
                        exerciseName: chosen.name,
                        existingPr: prMap[chosen.id],
                        existingGoal: goalsMap[chosen.id],
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Choose Exercise'),
                  ),
                ],
              ],
            ),
          )
        else
          for (final goal in goalEntries) ...[
            Builder(builder: (context) {
              final ex = exerciseById[goal.exerciseId];
              final pr = prMap[goal.exerciseId];
              final name = pr?.exerciseName ??
                  ex?.name ??
                  'Exercise #${goal.exerciseId}';
              final category = pr?.exerciseCategory ?? ex?.category ?? '';
              final primaryMuscle = _primaryMuscleFor(
                goal.exerciseId,
                name,
                category,
                muscleMap,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PinnedGoalCard(
                  exerciseId: goal.exerciseId,
                  exerciseName: name,
                  primaryMuscle: primaryMuscle,
                  goal: goal,
                  pr: pr,
                  onEditGoal: () => _promptGoalForExercise(
                    context,
                    exerciseId: goal.exerciseId,
                    exerciseName: name,
                    existingPr: pr,
                    existingGoal: goal,
                  ),
                  onOpenHistory: () {
                    final record = pr ??
                        PersonalRecordEntry(
                          exerciseId: goal.exerciseId,
                          exerciseName: name,
                          exerciseCategory: category,
                          isTimed: false,
                          maxWeightKg: 0,
                          estimatedOneRm: 0,
                        );
                    Navigator.of(context).push(
                      glassRoute(ExerciseHistoryScreen(record: record)),
                    );
                  },
                ),
              );
            }),
          ],
      ],
    );
  }

  // ── Segment 1: Bodyweight Strength Milestones (Reorderable & Deletable) ────

  bool _isCompoundMilestoneLift(String name) {
    final n = name.toLowerCase();
    return n.contains('bench') ||
        n.contains('squat') ||
        n.contains('deadlift') ||
        n.contains('romanian') ||
        n.contains('rdl') ||
        n.contains('overhead press') ||
        n.contains('shoulder press') ||
        n.contains('barbell row') ||
        n.contains('pull-up') ||
        n.contains('lat pulldown');
  }

  Widget _buildMilestonesTab(
    BuildContext context, {
    required List<PersonalRecordEntry> records,
    required Map<int, PersonalRecordEntry> prMap,
    required List<Exercise> allExercises,
    required Map<int, Exercise> exerciseById,
    required Map<int, ExerciseLiftGoal> goalsMap,
    required Map<int, List<ExerciseMuscle>> muscleMap,
    required MilestonePrefs milestonePrefs,
    required double bodyweightKg,
  }) {
    // Candidate exercises: default compound lifts with logged sets + any explicitly included
    final defaultCandidates = records
        .where((r) => !r.isTimed && _isCompoundMilestoneLift(r.exerciseName))
        .toList();
    final baseList = defaultCandidates.isNotEmpty
        ? defaultCandidates
        : records.where((r) => !r.isTimed).take(5).toList();

    final byId = <int, PersonalRecordEntry>{
      for (final r in baseList)
        if (!milestonePrefs.hiddenIds.contains(r.exerciseId)) r.exerciseId: r,
    };

    // Add any explicitly included exercises
    for (final id in milestonePrefs.includedIds) {
      if (milestonePrefs.hiddenIds.contains(id)) continue;
      if (byId.containsKey(id)) continue;
      final pr = prMap[id];
      if (pr != null && !pr.isTimed) {
        byId[id] = pr;
      } else {
        final ex = exerciseById[id];
        if (ex != null && !ex.isTimed && !ex.archived) {
          byId[id] = PersonalRecordEntry(
            exerciseId: ex.id,
            exerciseName: ex.name,
            exerciseCategory: ex.category,
            isTimed: false,
            maxWeightKg: 0,
            estimatedOneRm: 0,
          );
        }
      }
    }

    // Apply user's custom order
    final ordered = <PersonalRecordEntry>[];
    for (final id in milestonePrefs.orderedIds) {
      final item = byId.remove(id);
      if (item != null) ordered.add(item);
    }
    ordered.addAll(byId.values);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Ref BW: ${_fmtW(bodyweightKg)} kg',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFA78BFA),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drag to reorder · Swipe or tap × to remove',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showPickExerciseSheet(
                  context,
                  title: 'Add Lift to Milestones',
                  allExercises: allExercises,
                  prMap: prMap,
                  goalsMap: goalsMap,
                  muscleMap: muscleMap,
                  onChosen: (chosen) async {
                    await addOrRestoreMilestoneLift(chosen.id);
                    ref.invalidate(milestonePrefsProvider);
                  },
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add Lift',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ordered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No bodyweight milestones pinned.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => _showPickExerciseSheet(
                            context,
                            title: 'Add Lift to Milestones',
                            allExercises: allExercises,
                            prMap: prMap,
                            goalsMap: goalsMap,
                            muscleMap: muscleMap,
                            onChosen: (chosen) async {
                              await addOrRestoreMilestoneLift(chosen.id);
                              ref.invalidate(milestonePrefsProvider);
                            },
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Lift'),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    MediaQuery.of(context).padding.bottom + 64,
                  ),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final list = List<PersonalRecordEntry>.from(ordered);
                    final moved = list.removeAt(oldIndex);
                    list.insert(newIndex, moved);
                    await saveMilestoneOrder(
                      list.map((e) => e.exerciseId).toList(),
                    );
                    ref.invalidate(milestonePrefsProvider);
                  },
                  itemCount: ordered.length,
                  itemBuilder: (ctx, index) {
                    final pr = ordered[index];
                    return _MilestoneCard(
                      key: ValueKey('milestone_${pr.exerciseId}'),
                      index: index,
                      pr: pr,
                      bodyweightKg: bodyweightKg,
                      onRemove: () async {
                        await removeMilestoneLift(pr.exerciseId);
                        ref.invalidate(milestonePrefsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Removed ${pr.exerciseName} from milestones'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  await addOrRestoreMilestoneLift(
                                      pr.exerciseId);
                                  ref.invalidate(milestonePrefsProvider);
                                },
                              ),
                            ),
                          );
                        }
                      },
                      onTap: () => Navigator.of(context).push(
                        glassRoute(ExerciseHistoryScreen(record: pr)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Segment 2: All Lifts Filtered by Muscle Region ─────────────────────────

  Widget _buildAllLiftsTab(
    BuildContext context, {
    required List<PersonalRecordEntry> records,
    required Map<int, PersonalRecordEntry> prMap,
    required Map<int, ExerciseLiftGoal> goalsMap,
    required Map<int, List<ExerciseMuscle>> muscleMap,
    required double bodyweightKg,
  }) {
    // Filter by muscle region first
    var filtered = records.where((r) {
      if (_selectedRegion == 'All') return true;
      final region = _regionFor(
        r.exerciseId,
        r.exerciseName,
        r.exerciseCategory,
        muscleMap,
      );
      return region == _selectedRegion;
    }).toList();

    // Apply smart search ranking when searching
    if (_searchQuery.trim().isNotEmpty) {
      final dummyExercises = [
        for (final r in filtered)
          Exercise(
            id: r.exerciseId,
            name: r.exerciseName,
            category: r.exerciseCategory,
            isTimed: r.isTimed,
            archived: false,
            muscleNeedsReview: false,
          ),
      ];
      final ranked = _smartFilterAndRankExercises(
        exercises: dummyExercises,
        query: _searchQuery,
        prMap: prMap,
        muscleMap: muscleMap,
      );
      final recById = {for (final r in filtered) r.exerciseId: r};
      filtered = [
        for (final ex in ranked)
          if (recById[ex.id] != null) recById[ex.id]!,
      ];
    }

    const regionOrder = [
      'Chest',
      'Back',
      'Legs',
      'Shoulders',
      'Arms',
      'Core',
      'Neck',
      'Other',
      'Conditioning',
    ];

    final byRegion = <String, List<PersonalRecordEntry>>{};
    for (final r in filtered) {
      final reg = _regionFor(
        r.exerciseId,
        r.exerciseName,
        r.exerciseCategory,
        muscleMap,
      );
      (byRegion[reg] ??= []).add(r);
    }

    final orderedRegions = byRegion.keys.toList()
      ..sort((a, b) {
        final ia = regionOrder.indexOf(a);
        final ib = regionOrder.indexOf(b);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search logged lifts...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final reg = _regions[i];
              final selected = _selectedRegion == reg;
              final accent = Theme.of(context).colorScheme.primary;
              return GestureDetector(
                onTap: () => setState(() => _selectedRegion = reg),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? accent.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    reg,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? accent
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    records.isEmpty
                        ? 'No logged lifts yet — complete a workout to see your PRs & rep maxes.'
                        : 'No matching lifts found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    MediaQuery.of(context).padding.bottom + 64,
                  ),
                  children: [
                    if (_searchQuery.trim().isNotEmpty)
                      for (final record in filtered)
                        _LiftRecordTile(
                          record: record,
                          primaryMuscle: _primaryMuscleFor(
                            record.exerciseId,
                            record.exerciseName,
                            record.exerciseCategory,
                            muscleMap,
                          ),
                          goal: goalsMap[record.exerciseId],
                          bodyweightKg: bodyweightKg,
                          onSetGoal: () => _promptGoalForExercise(
                            context,
                            exerciseId: record.exerciseId,
                            exerciseName: record.exerciseName,
                            existingPr: record,
                            existingGoal: goalsMap[record.exerciseId],
                          ),
                        )
                    else
                      for (final region in orderedRegions) ...[
                        _RegionHeader(label: region),
                        for (final record in byRegion[region]!)
                          _LiftRecordTile(
                            record: record,
                            primaryMuscle: _primaryMuscleFor(
                              record.exerciseId,
                              record.exerciseName,
                              record.exerciseCategory,
                              muscleMap,
                            ),
                            goal: goalsMap[record.exerciseId],
                            bodyweightKg: bodyweightKg,
                            onSetGoal: () => _promptGoalForExercise(
                              context,
                              exerciseId: record.exerciseId,
                              exerciseName: record.exerciseName,
                              existingPr: record,
                              existingGoal: goalsMap[record.exerciseId],
                            ),
                          ),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── 4-Segment Switcher ──────────────────────────────────────────────────────

class _SegmentedBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentedBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  static const _labels = [
    (Icons.flag_rounded, 'Goals'),
    (Icons.workspace_premium_rounded, 'Milestones'),
    (Icons.fitness_center_rounded, 'All Lifts'),
    (Icons.history_rounded, 'Log'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? accent.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: selectedIndex == i
                        ? Border.all(color: accent.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _labels[i].$1,
                        size: 13.5,
                        color: selectedIndex == i
                            ? accent
                            : Colors.white.withValues(alpha: 0.55),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _labels[i].$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selectedIndex == i
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selectedIndex == i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Spacious Pinned Lift Goal Card (#4 & #5) ────────────────────────────────

class _PinnedGoalCard extends StatelessWidget {
  final int exerciseId;
  final String exerciseName;
  final String primaryMuscle;
  final ExerciseLiftGoal goal;
  final PersonalRecordEntry? pr;
  final VoidCallback onEditGoal;
  final VoidCallback onOpenHistory;

  const _PinnedGoalCard({
    required this.exerciseId,
    required this.exerciseName,
    required this.primaryMuscle,
    required this.goal,
    required this.pr,
    required this.onEditGoal,
    required this.onOpenHistory,
  });

  double _estForReps(double oneRm, int reps) {
    if (reps <= 1) return (oneRm * 2).round() / 2.0;
    return ((oneRm / (1.0 + reps / 30.0)) * 2).round() / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    final currentOneRm = pr?.estimatedOneRm ?? 0.0;
    final currentCapAtTargetReps =
        currentOneRm > 0 ? _estForReps(currentOneRm, goal.targetReps) : 0.0;
    final rawPct = goal.targetWeightKg > 0
        ? (currentCapAtTargetReps / goal.targetWeightKg)
        : 0.0;
    final pct = (rawPct * 100).round().clamp(0, 100);
    final achieved = currentCapAtTargetReps >= goal.targetWeightKg ||
        (pr != null &&
            pr!.maxWeightKg >= goal.targetWeightKg &&
            goal.targetReps == 1);
    final remainingKg =
        (goal.targetWeightKg - currentCapAtTargetReps).clamp(0.0, 999.0);

    final statusColor =
        achieved ? const Color(0xFF34D399) : const Color(0xFF38BDF8);

    return GestureDetector(
      onTap: onOpenHistory,
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title + Muscle Tag + Progress % + Edit button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          primaryMuscle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    achieved ? 'REACHED ✓' : '$pct%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit Goal',
                  onPressed: onEditGoal,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 2: Two spacious stat boxes (Current vs Target)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT (${goal.targetReps}RM EST.)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pr != null
                              ? '~${_fmtW(currentCapAtTargetReps)} kg × ${goal.targetReps}'
                              : 'Not logged yet',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (pr != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Heaviest PR: ${_fmtW(pr!.maxWeightKg)} kg',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TARGET GOAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: statusColor.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_fmtW(goal.targetWeightKg)} kg × ${goal.targetReps}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Est. 1RM ~${_fmtW(goal.targetOneRm)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Row 3: Progress Bar + Clean Status Text
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: rawPct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achieved
                  ? 'Goal achieved! Tap edit to set your next target.'
                  : '${_fmtW(remainingKg)} kg to go at ${goal.targetReps} reps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reorderable & Deletable Bodyweight Milestone Card (#2) ──────────────────

class _MilestoneCard extends StatelessWidget {
  final int index;
  final PersonalRecordEntry pr;
  final double bodyweightKg;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _MilestoneCard({
    super.key,
    required this.index,
    required this.pr,
    required this.bodyweightKg,
    required this.onRemove,
    required this.onTap,
  });

  List<double> _tiersForLift(String name) {
    final n = name.toLowerCase();
    if (n.contains('deadlift') || n.contains('rdl') || n.contains('romanian')) {
      return const [1.0, 1.25, 1.5, 2.0, 2.5];
    }
    if (n.contains('squat') || n.contains('leg press')) {
      return const [0.75, 1.0, 1.25, 1.75, 2.25];
    }
    if (n.contains('overhead') || n.contains('shoulder press')) {
      return const [0.4, 0.55, 0.75, 0.95, 1.15];
    }
    return const [0.5, 0.75, 1.0, 1.25, 1.5];
  }

  static const _tierNames = [
    'Starter',
    'Novice',
    'Intermediate',
    'Advanced',
    'Elite',
  ];

  @override
  Widget build(BuildContext context) {
    final tiers = _tiersForLift(pr.exerciseName);
    final ratio =
        bodyweightKg > 0 ? pr.estimatedOneRm / bodyweightKg : 0.0;
    int achievedIdx = -1;
    for (int i = 0; i < tiers.length; i++) {
      if (ratio >= tiers[i]) achievedIdx = i;
    }
    final tierLabel =
        achievedIdx >= 0 ? _tierNames[achievedIdx] : 'Building Base';
    final nextTierMultiplier = achievedIdx + 1 < tiers.length
        ? tiers[achievedIdx + 1]
        : tiers.last * 1.15;
    final nextTargetKg =
        ((nextTierMultiplier * bodyweightKg) * 2).round() / 2.0;
    final prevTargetKg =
        achievedIdx >= 0 ? tiers[achievedIdx] * bodyweightKg : 0.0;
    final span = (nextTargetKg - prevTargetKg).clamp(1.0, 999.0);
    final tierProgress =
        ((pr.estimatedOneRm - prevTargetKg) / span).clamp(0.05, 1.0);
    final awayKg = (nextTargetKg - pr.estimatedOneRm).clamp(0.0, 999.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('dismiss_milestone_${pr.exerciseId}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: LiquidGlassContainer(
            borderRadius: 18,
            blurSigma: 8,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        pr.exerciseName,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$tierLabel · ${ratio.toStringAsFixed(2)}× BW',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      tooltip: 'Remove from Milestones',
                      onPressed: onRemove,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Est. 1RM: ~${_fmtW(pr.estimatedOneRm)} kg',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      'Next: ${nextTierMultiplier.toStringAsFixed(2)}× BW (${_fmtW(nextTargetKg)} kg)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: tierProgress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFA78BFA)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_fmtW(awayKg)} kg 1RM to reach next bodyweight milestone',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.5),
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

// ─── Region Header & Spacious Lift Tile for "All Lifts" Tab (#6) ─────────────

class _RegionHeader extends StatelessWidget {
  final String label;
  const _RegionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _LiftRecordTile extends ConsumerWidget {
  final PersonalRecordEntry record;
  final String primaryMuscle;
  final ExerciseLiftGoal? goal;
  final double bodyweightKg;
  final VoidCallback onSetGoal;

  const _LiftRecordTile({
    required this.record,
    required this.primaryMuscle,
    required this.goal,
    required this.bodyweightKg,
    required this.onSetGoal,
  });

  double _estForReps(int reps) {
    final raw = record.estimatedOneRm / (1.0 + reps / 30.0);
    return (raw * 2).round() / 2.0;
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PR?'),
        content: Text(
            'This will permanently delete all logged sets for '
            '"${record.exerciseName}". The exercise itself is kept.'),
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
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(databaseProvider)
        .setsDao
        .deleteSetsByExercise(record.exerciseId);
    ref.invalidate(personalRecordsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            glassRoute(ExerciseHistoryScreen(record: record)),
          ),
          onLongPress: () => _confirmDelete(context, ref),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: goal != null
                    ? const Color(0xFF34D399).withValues(alpha: 0.35)
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.12),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  record.exerciseName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  primaryMuscle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (!record.isTimed)
                            Text(
                              'Est. 1RM ~${_fmtW(record.estimatedOneRm)} kg'
                              '${goal != null ? '  ·  Goal: ${_fmtW(goal!.targetWeightKg)} kg × ${goal!.targetReps}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: goal != null
                                    ? const Color(0xFF34D399)
                                    : Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          record.isTimed
                              ? _fmtSec(record.maxDurationSeconds ?? 0)
                              : '${_fmtW(record.maxWeightKg)} kg',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'PR',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    if (!record.isTimed) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          goal != null ? Icons.flag : Icons.flag_outlined,
                          size: 19,
                          color: goal != null
                              ? const Color(0xFF34D399)
                              : Colors.white38,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Set Target Goal',
                        onPressed: onSetGoal,
                      ),
                    ],
                  ],
                ),
                // Spacious 3-column Working Weight Strip (5RM · 8RM · 10RM)
                if (!record.isTimed && record.estimatedOneRm > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (int idx = 0; idx < 3; idx++) ...[
                        if (idx > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Builder(builder: (context) {
                            final r = const [5, 8, 10][idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.07),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${r}RM',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  Text(
                                    '~${_fmtW(_estForReps(r))} kg',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
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
}

// ─── Segment 3: Embedded Session Logbook ─────────────────────────────────────

class _EmbeddedSessionHistoryTab extends ConsumerWidget {
  const _EmbeddedSessionHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final statsAsync = ref.watch(allSessionStatsProvider);

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No workout sessions logged yet.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            ),
          );
        }

        final stats = statsAsync.asData?.value ?? {};
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final sessionsThisWeek =
            entries.where((e) => !e.session.date.isBefore(weekAgo)).length;
        final totalPrs =
            stats.values.fold<int>(0, (sum, s) => sum + s.prCount);

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            MediaQuery.of(context).padding.bottom + 64,
          ),
          itemCount: entries.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LiquidGlassContainer(
                  borderRadius: 16,
                  blurSigma: 8,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MiniStat(
                        label: 'TOTAL SESSIONS',
                        value: '${entries.length}',
                      ),
                      _MiniStat(
                        label: 'LAST 7 DAYS',
                        value: '$sessionsThisWeek',
                      ),
                      _MiniStat(
                        label: 'TOTAL PRs',
                        value: '$totalPrs',
                      ),
                    ],
                  ),
                ),
              );
            }
            final entry = entries[i - 1];
            final sessionStats = stats[entry.session.id];
            return _CompactSessionLogTile(
              entry: entry,
              stats: sessionStats,
              onDelete: () async {
                final db = ref.read(databaseProvider);
                await db.setsDao.deleteSetsForSession(entry.session.id);
                await db.sessionsDao.deleteSession(entry.session.id);
                ref.invalidate(allSessionStatsProvider);
                ref.invalidate(personalRecordsProvider);
                ref.invalidate(nextWodProvider);
                ref.invalidate(activeProgramProvider);
                ref.invalidate(pointsScoreProvider);
              },
            );
          },
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Colors.white.withValues(alpha: 0.48),
          ),
        ),
      ],
    );
  }
}

class _CompactSessionLogTile extends StatelessWidget {
  final SessionWithProgram entry;
  final SessionSetStats? stats;
  final VoidCallback onDelete;

  const _CompactSessionLogTile({
    required this.entry,
    required this.stats,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = entry.session;
    final d = s.date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          glassRoute(SessionDetailScreen(session: s)),
        ),
        child: LiquidGlassContainer(
          borderRadius: 16,
          blurSigma: 8,
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            s.workoutName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (entry.programName != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.programName!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats != null
                          ? '$dateStr  ·  ${stats!.setCount} sets  ·  ${stats!.totalVolume.toInt()} kg vol'
                              '${stats!.avgRir != null ? '  ·  RIR ${stats!.avgRir!.toStringAsFixed(1)}' : ''}'
                          : dateStr,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (stats != null && stats!.prCount > 0)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🏆 ${stats!.prCount} PR',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
