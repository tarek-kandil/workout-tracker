import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/programs_table.dart';
import '../tables/program_phases_table.dart';
import '../tables/wod_templates_table.dart';
import '../tables/wod_template_exercises_table.dart';

part 'programs_dao.g.dart';

@DriftAccessor(
    tables: [Programs, ProgramPhases, WodTemplates, WodTemplateExercises])
class ProgramsDao extends DatabaseAccessor<AppDatabase>
    with _$ProgramsDaoMixin {
  ProgramsDao(super.db);

  // ── Programs ──────────────────────────────────────────────────────────────

  Stream<Program?> watchActiveProgram() =>
      (select(programs)..where((p) => p.status.equals(0)))
          .watchSingleOrNull();

  Future<List<Program>> getAllPrograms() =>
      (select(programs)
            ..orderBy([
              (p) => OrderingTerm(
                  expression: p.status), // active first, then completed, draft
            ]))
          .get();

  Future<int> insertProgram(ProgramsCompanion entry) =>
      into(programs).insert(entry);

  Future<void> updateProgram(ProgramsCompanion entry) =>
      update(programs).replace(entry);

  Future<void> updateProgramStatus(int programId, int status) =>
      (update(programs)..where((p) => p.id.equals(programId)))
          .write(ProgramsCompanion(status: Value(status)));

  Future<void> deleteProgram(int programId) async {
    final phases = await getPhasesForProgram(programId);
    for (final phase in phases) {
      await deletePhase(phase.id);
    }
    await (delete(programs)..where((p) => p.id.equals(programId))).go();
  }

  // ── Phases ────────────────────────────────────────────────────────────────

  Future<List<ProgramPhase>> getPhasesForProgram(int programId) =>
      (select(programPhases)
            ..where((pp) => pp.programId.equals(programId))
            ..orderBy([(pp) => OrderingTerm(expression: pp.phaseNumber)]))
          .get();

  Future<int> insertPhase(ProgramPhasesCompanion entry) =>
      into(programPhases).insert(entry);

  Future<void> updatePhase(ProgramPhasesCompanion entry) =>
      update(programPhases).replace(entry);

  Future<void> deletePhase(int phaseId) async {
    final wods = await getWodTemplatesForPhase(phaseId);
    for (final wod in wods) {
      await deleteWodTemplate(wod.id);
    }
    await (delete(programPhases)..where((pp) => pp.id.equals(phaseId))).go();
  }

  // ── WOD Templates ─────────────────────────────────────────────────────────

  Future<List<WodTemplate>> getWodTemplatesForPhase(int phaseId) =>
      (select(wodTemplates)
            ..where((w) => w.phaseId.equals(phaseId))
            ..orderBy([(w) => OrderingTerm(expression: w.wodNumber)]))
          .get();

  Future<int> insertWodTemplate(WodTemplatesCompanion entry) =>
      into(wodTemplates).insert(entry);

  Future<void> updateWodTemplate(WodTemplatesCompanion entry) =>
      update(wodTemplates).replace(entry);

  Future<void> deleteWodTemplate(int wodTemplateId) async {
    await (delete(wodTemplateExercises)
          ..where((w) => w.wodTemplateId.equals(wodTemplateId)))
        .go();
    await (delete(wodTemplates)..where((w) => w.id.equals(wodTemplateId))).go();
  }

  // ── WOD Template Exercises ────────────────────────────────────────────────

  Future<List<WodTemplateExercise>> getTemplateExercises(
          int wodTemplateId) =>
      (select(wodTemplateExercises)
            ..where((w) => w.wodTemplateId.equals(wodTemplateId))
            ..orderBy([(w) => OrderingTerm(expression: w.sortOrder)]))
          .get();

  Future<int> insertWodTemplateExercise(WodTemplateExercisesCompanion entry) =>
      into(wodTemplateExercises).insert(entry);

  Future<void> updateWodTemplateExercise(
          WodTemplateExercisesCompanion entry) =>
      update(wodTemplateExercises).replace(entry);

  Future<void> deleteWodTemplateExercise(int id) =>
      (delete(wodTemplateExercises)..where((w) => w.id.equals(id))).go();

  // ── Duplicate program as draft (for re-use after completion) ─────────────

  Future<int> duplicateProgram(int sourceProgramId, String newName) async {
    final sourcePhases = await getPhasesForProgram(sourceProgramId);
    final newProgramId = await insertProgram(ProgramsCompanion(
      name: Value(newName),
      status: const Value(2), // draft
    ));
    for (final phase in sourcePhases) {
      final newPhaseId = await insertPhase(ProgramPhasesCompanion(
        programId: Value(newProgramId),
        phaseNumber: Value(phase.phaseNumber),
        name: Value(phase.name),
        durationWeeks: Value(phase.durationWeeks),
      ));
      final wods = await getWodTemplatesForPhase(phase.id);
      for (final wod in wods) {
        final newWodId = await insertWodTemplate(WodTemplatesCompanion(
          phaseId: Value(newPhaseId),
          wodNumber: Value(wod.wodNumber),
          name: Value(wod.name),
          notes: Value(wod.notes),
        ));
        final exercises = await getTemplateExercises(wod.id);
        for (final ex in exercises) {
          await insertWodTemplateExercise(WodTemplateExercisesCompanion(
            wodTemplateId: Value(newWodId),
            exerciseId: Value(ex.exerciseId),
            sortOrder: Value(ex.sortOrder),
            targetSets: Value(ex.targetSets),
            repRangeMin: Value(ex.repRangeMin),
            repRangeMax: Value(ex.repRangeMax),
            notes: Value(ex.notes),
          ));
        }
      }
    }
    return newProgramId;
  }
}
