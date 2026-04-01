import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

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

/// All programs (for the program management screen).
final allProgramsProvider = FutureProvider<List<Program>>((ref) {
  return ref.watch(databaseProvider).programsDao.getAllPrograms();
});

/// Calendar week number within the active program (1-based).
/// Derived from the date of the first session; null if no sessions yet.
final currentProgramWeekProvider = FutureProvider<int?>((ref) async {
  final program = await ref.watch(activeProgramProvider.future);
  if (program == null) return null;

  final firstSession = await ref
      .watch(databaseProvider)
      .sessionsDao
      .getFirstSessionForProgram(program.id);
  if (firstSession == null) return 1; // no sessions yet — show Week 1

  final phases = await ref
      .watch(databaseProvider)
      .programsDao
      .getPhasesForProgram(program.id);
  final totalWeeks = phases.fold(0, (sum, p) => sum + p.durationWeeks);

  final daysSinceStart =
      DateTime.now().difference(firstSession.date).inDays;
  final week = (daysSinceStart / 7).floor() + 1;
  return week.clamp(1, totalWeeks);
});
