import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';
import 'next_workout_provider.dart';

/// The single active program (status = 0). Null if none.
final activeProgramProvider = StreamProvider<Program?>((ref) {
  return ref.watch(databaseProvider).programsDao.watchActiveProgram();
});

/// All phases for the active program, sorted by phase_number.
final activePhasesProvider = FutureProvider<List<ProgramPhase>>((ref) async {
  final program = await ref.watch(activeProgramProvider.future);
  if (program == null) return [];
  return ref
      .watch(databaseProvider)
      .programsDao
      .getPhasesForProgram(program.id);
});

/// WOD templates for a specific phase (used in phase cards).
final wodTemplatesForPhaseProvider =
    FutureProvider.family<List<WodTemplate>, int>((ref, phaseId) {
  return ref.watch(databaseProvider).programsDao.getWodTemplatesForPhase(phaseId);
});

/// All template exercises for a specific WOD (standalone + circuit), used for program preview.
final wodTemplateExercisesProvider =
    FutureProvider.family<List<WodTemplateExercise>, int>((ref, wodTemplateId) {
  return ref.read(databaseProvider).programsDao.getAllTemplateExercises(wodTemplateId);
});

/// Circuit groups for a specific WOD (used for program preview).
final wodCircuitGroupsProvider =
    FutureProvider.family<List<WodExerciseGroup>, int>((ref, wodTemplateId) {
  return ref.read(databaseProvider).programsDao.getGroupsForWod(wodTemplateId);
});

/// All programs (for the program management screen).
final allProgramsProvider = FutureProvider<List<Program>>((ref) {
  return ref.watch(databaseProvider).programsDao.getAllPrograms();
});

/// Session-count-based week within the active program (1-based).
/// Delegates to nextWodProvider so both cards always show the same week.
final currentProgramWeekProvider = FutureProvider<int?>((ref) async {
  final result = await ref.watch(nextWodProvider.future);
  return result?.weekNumberInProgram;
});
