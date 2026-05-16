import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/next_wod_result.dart';
import '../models/weight_suggestion.dart';
import '../models/wod_item.dart';
import 'database_provider.dart';
import 'program_providers.dart';

// ── Shared helper ─────────────────────────────────────────────────────────────

/// Builds the ordered [List<WodItem>] for a WOD template.
/// Merges standalone exercises and circuits sorted by their WOD-level sortOrder.
Future<List<WodItem>> _buildWodItems(
  AppDatabase db,
  int wodTemplateId,
  Map<int, Exercise> exerciseMap,
) async {
  // Standalone exercises (groupId IS NULL)
  final standaloneExercises =
      await db.programsDao.getTemplateExercises(wodTemplateId);

  // Circuits
  final groups = await db.programsDao.getGroupsForWod(wodTemplateId);

  // Build a merged list sorted by WOD-level position.
  // Standalone → use exercise.sortOrder; Circuit → use group.sortOrder.
  final items = <({int sortOrder, WodItem item})>[];

  for (final te in standaloneExercises) {
    final exercise = exerciseMap[te.exerciseId];
    if (exercise == null) continue;
    final lastSets =
        await db.setsDao.getLastSetsForExerciseInWod(te.exerciseId, wodTemplateId);
    items.add((
      sortOrder: te.sortOrder,
      item: StandaloneWodExercise(
        entry: WodExerciseEntry(
          templateExercise: te,
          exercise: exercise,
          suggestion: _computeSuggestion(
            lastSets: lastSets,
            repRangeMin: te.repRangeMin,
            repRangeMax: te.repRangeMax,
          ),
        ),
        restSeconds: te.restSeconds,
      ),
    ));
  }

  for (final group in groups) {
    final groupExercises =
        await db.programsDao.getExercisesForGroup(group.id);
    final entries = <WodExerciseEntry>[];
    for (final te in groupExercises) {
      final exercise = exerciseMap[te.exerciseId];
      if (exercise == null) continue;
      final lastSets =
          await db.setsDao.getLastSetsForExerciseInWod(te.exerciseId, wodTemplateId);
      entries.add(WodExerciseEntry(
        templateExercise: te,
        exercise: exercise,
        suggestion: _computeSuggestion(
          lastSets: lastSets,
          repRangeMin: te.repRangeMin,
          repRangeMax: te.repRangeMax,
        ),
      ));
    }
    items.add((
      sortOrder: group.sortOrder,
      item: WodCircuit(
        groupId: group.id,
        name: group.name,
        rounds: group.rounds,
        restBetweenExercisesSeconds: group.restBetweenExercisesSeconds,
        restBetweenRoundsSeconds: group.restBetweenRoundsSeconds,
        exercises: entries,
      ),
    ));
  }

  items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return items.map((e) => e.item).toList();
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// All WODs for the current phase, each with full exercise data and suggestions.
/// Used by the WOD selection screen so the user can pick any WOD, not just the next one.
final allCurrentPhaseWodsProvider =
    FutureProvider<List<NextWodResult>>((ref) async {
  final recommended = await ref.watch(nextWodProvider.future);
  if (recommended == null) return [];

  final db = ref.watch(databaseProvider);
  final phaseWods =
      await db.programsDao.getWodTemplatesForPhase(recommended.phase.id);
  final allExercises = await db.exercisesDao.getAllExercises();
  final exerciseMap = {for (final e in allExercises) e.id: e};

  final results = <NextWodResult>[];
  for (final wod in phaseWods) {
    final wodItems = await _buildWodItems(db, wod.id, exerciseMap);
    final wodSessions =
        await db.sessionsDao.getSessionsForWodTemplate(wod.id);
    results.add(NextWodResult(
      program: recommended.program,
      phase: recommended.phase,
      phaseIndex: recommended.phaseIndex,
      totalPhases: recommended.totalPhases,
      wodTemplate: wod,
      weekNumberInProgram: recommended.weekNumberInProgram,
      totalProgramWeeks: recommended.totalProgramWeeks,
      items: wodItems,
      lastSessionDate: wodSessions.firstOrNull?.date,
    ));
  }
  return results;
});

/// Computes the next WOD to perform and weight suggestions for each exercise.
/// Returns null when there is no active program.
final nextWodProvider = FutureProvider<NextWodResult?>((ref) async {
  final program = await ref.watch(activeProgramProvider.future);
  if (program == null) return null;

  final db = ref.watch(databaseProvider);
  final phases = await db.programsDao.getPhasesForProgram(program.id);
  if (phases.isEmpty) return null;

  final totalProgramWeeks =
      phases.fold(0, (sum, p) => sum + p.durationWeeks);

  // ── Session-count-based week + phase determination ───────────────────────
  int weekOffset = 0;
  ProgramPhase? currentPhase;
  int phaseIndex = 0;
  int currentWeek = 1;

  for (int i = 0; i < phases.length; i++) {
    final phase = phases[i];
    final phaseWodCount =
        (await db.programsDao.getWodTemplatesForPhase(phase.id)).length;
    final rotation = phaseWodCount > 0 ? phaseWodCount : 1;
    final phaseSessions =
        await db.sessionsDao.getSessionCountForPhase(phase.id);
    final weeksUsed = phaseSessions ~/ rotation;

    if (weeksUsed < phase.durationWeeks) {
      currentPhase = phase;
      phaseIndex = i + 1;
      currentWeek = weekOffset + weeksUsed + 1;
      break;
    } else {
      weekOffset += phase.durationWeeks;
    }
  }

  if (currentPhase == null) return null;

  final phaseWods =
      await db.programsDao.getWodTemplatesForPhase(currentPhase.id);
  if (phaseWods.isEmpty) return null;

  // ── Determine next WOD ───────────────────────────────────────────────────
  final lastPhaseSession =
      await db.sessionsDao.getLastSessionForPhase(currentPhase.id);
  WodTemplate nextWod;

  if (lastPhaseSession == null || lastPhaseSession.wodTemplateId == null) {
    nextWod = phaseWods.first;
  } else {
    final lastWodIndex =
        phaseWods.indexWhere((w) => w.id == lastPhaseSession.wodTemplateId);
    nextWod = lastWodIndex == -1
        ? phaseWods.first
        : phaseWods[(lastWodIndex + 1) % phaseWods.length];
  }

  // ── Derive lastSessionDate ────────────────────────────────────────────────
  final wodSessions =
      await db.sessionsDao.getSessionsForWodTemplate(nextWod.id);
  final lastSession = wodSessions.firstOrNull;

  // ── Load items ────────────────────────────────────────────────────────────
  final allExercises = await db.exercisesDao.getAllExercises();
  final exerciseMap = {for (final e in allExercises) e.id: e};
  final wodItems = await _buildWodItems(db, nextWod.id, exerciseMap);

  return NextWodResult(
    program: program,
    phase: currentPhase,
    phaseIndex: phaseIndex,
    totalPhases: phases.length,
    wodTemplate: nextWod,
    weekNumberInProgram: currentWeek,
    totalProgramWeeks: totalProgramWeeks,
    items: wodItems,
    lastSessionDate: lastSession?.date,
  );
});

WeightSuggestion _computeSuggestion({
  required List<WorkoutSet> lastSets,
  required int repRangeMin,
  required int repRangeMax,
  double incrementKg = 2.5,
}) {
  final validSets = lastSets.where((s) => s.reps > 0 && s.weightKg > 0).toList();
  if (validSets.isEmpty) return WeightSuggestion.noHistory;

  // Best set = highest weight × reps (volume), which reflects peak effort
  // better than always using set #1 (which is often a lighter opener).
  final bestSet = validSets.reduce(
    (a, b) => a.weightKg * a.reps >= b.weightKg * b.reps ? a : b,
  );
  final bestWeight = bestSet.weightKg;
  final bestRpe = bestSet.rpe; // null if not logged

  final minReps = validSets.map((s) => s.reps).reduce(min);
  final maxReps = validSets.map((s) => s.reps).reduce(max);

  // RPE ≤ 7.5 means they had clear room left — don't push the weight up yet
  // even if the rep count looks good.
  final easyEffort = bestRpe != null && bestRpe <= 7.5;
  final rpeStr = bestRpe != null ? ' @ RPE ${bestRpe.toStringAsFixed(1)}' : '';

  if (minReps >= repRangeMax && !easyEffort) {
    return WeightSuggestion(
      type: SuggestionType.increase,
      suggestedKg: bestWeight + incrementKg,
      message: 'Hit $maxReps reps$rpeStr — increase to ${bestWeight + incrementKg}kg',
    );
  } else if (maxReps < repRangeMin) {
    return WeightSuggestion(
      type: SuggestionType.decrease,
      suggestedKg: (bestWeight - incrementKg).clamp(0.0, double.infinity),
      message: 'Only $minReps reps$rpeStr — reduce to ${bestWeight - incrementKg}kg',
    );
  } else {
    return WeightSuggestion(
      type: SuggestionType.maintain,
      suggestedKg: bestWeight,
      message: easyEffort
          ? 'Easy effort$rpeStr — maintain ${bestWeight}kg, push to $repRangeMax reps'
          : 'Stay at ${bestWeight}kg, aim for $repRangeMax reps',
    );
  }
}
