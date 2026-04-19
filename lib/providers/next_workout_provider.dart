import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/next_wod_result.dart';
import '../models/weight_suggestion.dart';
import 'database_provider.dart';
import 'program_providers.dart';

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
  // One full rotation of all WODs in a phase = 1 week.
  // Weeks advance when you complete sessions, NOT from calendar time.
  // If you don't work out, the week doesn't advance automatically.
  int weekOffset = 0;
  ProgramPhase? currentPhase;
  int phaseIndex = 0;
  int currentWeek = 1;

  for (int i = 0; i < phases.length; i++) {
    final phase = phases[i];
    final phaseWodCount =
        (await db.programsDao.getWodTemplatesForPhase(phase.id)).length;

    // If this phase has no WODs yet, treat it as a 1-WOD rotation to avoid ÷0
    final rotation = phaseWodCount > 0 ? phaseWodCount : 1;
    final phaseSessions =
        await db.sessionsDao.getSessionCountForPhase(phase.id);
    final weeksUsed = phaseSessions ~/ rotation; // complete rotations done

    if (weeksUsed < phase.durationWeeks) {
      // Still in this phase
      currentPhase = phase;
      phaseIndex = i + 1;
      currentWeek = weekOffset + weeksUsed + 1;
      break;
    } else {
      weekOffset += phase.durationWeeks;
    }
  }

  // All phases exhausted → program complete
  if (currentPhase == null) return null;

  final phaseWods =
      await db.programsDao.getWodTemplatesForPhase(currentPhase.id);
  if (phaseWods.isEmpty) return null;

  // ── Determine next WOD ───────────────────────────────────────────────────
  // Query the most recent session for any WOD in the current phase directly.
  // This avoids the deep join chain that could silently return null.
  final lastPhaseSession =
      await db.sessionsDao.getLastSessionForPhase(currentPhase.id);
  WodTemplate nextWod;

  if (lastPhaseSession == null || lastPhaseSession.wodTemplateId == null) {
    // No sessions yet for this phase — start at WOD 1
    nextWod = phaseWods.first;
  } else {
    final lastWodIndex =
        phaseWods.indexWhere((w) => w.id == lastPhaseSession.wodTemplateId);
    if (lastWodIndex == -1) {
      // Last session's WOD was removed — restart from WOD 1
      nextWod = phaseWods.first;
    } else {
      // Advance to the next WOD, wrapping around
      nextWod = phaseWods[(lastWodIndex + 1) % phaseWods.length];
    }
  }

  // ── Derive lastSessionDate for "Last done" label ──────────────────────────
  // Use the last session for the specific next WOD, not the whole program.
  final wodSessions =
      await db.sessionsDao.getSessionsForWodTemplate(nextWod.id);
  final lastSession = wodSessions.firstOrNull;

  // ── Load exercises + weight suggestions ──────────────────────────────────
  final templateExercises =
      await db.programsDao.getTemplateExercises(nextWod.id);
  final allExercises = await db.exercisesDao.getAllExercises();
  final exerciseMap = {for (final e in allExercises) e.id: e};

  final entries = <WodExerciseEntry>[];
  for (final te in templateExercises) {
    final exercise = exerciseMap[te.exerciseId];
    if (exercise == null) continue;

    final lastSets = await db.setsDao
        .getLastSetsForExerciseInWod(te.exerciseId, nextWod.id);

    final suggestion = _computeSuggestion(
      lastSets: lastSets,
      repRangeMin: te.repRangeMin,
      repRangeMax: te.repRangeMax,
    );

    entries.add(WodExerciseEntry(
      templateExercise: te,
      exercise: exercise,
      suggestion: suggestion,
    ));
  }

  return NextWodResult(
    program: program,
    phase: currentPhase,
    phaseIndex: phaseIndex,
    totalPhases: phases.length,
    wodTemplate: nextWod,
    weekNumberInProgram: currentWeek,
    totalProgramWeeks: totalProgramWeeks,
    exercises: entries,
    lastSessionDate: lastSession?.date,
  );
});

WeightSuggestion _computeSuggestion({
  required List<WorkoutSet> lastSets,
  required int repRangeMin,
  required int repRangeMax,
  double incrementKg = 2.5,
}) {
  // Ignore any accidentally-stored 0-rep sets
  final validSets = lastSets.where((s) => s.reps > 0).toList();
  if (validSets.isEmpty) return WeightSuggestion.noHistory;

  final lastWeight = validSets.first.weightKg;
  final minReps = validSets.map((s) => s.reps).reduce(min);
  final maxReps = validSets.map((s) => s.reps).reduce(max);

  if (minReps >= repRangeMax) {
    return WeightSuggestion(
      type: SuggestionType.increase,
      suggestedKg: lastWeight + incrementKg,
      message: 'Hit $maxReps reps — increase to ${lastWeight + incrementKg}kg',
    );
  } else if (maxReps < repRangeMin) {
    return WeightSuggestion(
      type: SuggestionType.decrease,
      suggestedKg: (lastWeight - incrementKg).clamp(0.0, double.infinity),
      message: 'Only $minReps reps — reduce to ${lastWeight - incrementKg}kg',
    );
  } else {
    return WeightSuggestion(
      type: SuggestionType.maintain,
      suggestedKg: lastWeight,
      message: 'Stay at ${lastWeight}kg, aim for $repRangeMax reps',
    );
  }
}
