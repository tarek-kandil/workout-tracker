import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/programs_table.dart';
import '../tables/program_phases_table.dart';
import '../tables/wod_templates_table.dart';
import '../tables/wod_exercise_groups_table.dart';
import '../tables/wod_template_exercises_table.dart';

part 'programs_dao.g.dart';

@DriftAccessor(
    tables: [Programs, ProgramPhases, WodTemplates, WodExerciseGroups, WodTemplateExercises])
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

  /// Returns only standalone exercises (not part of any circuit).
  Future<List<WodTemplateExercise>> getTemplateExercises(
          int wodTemplateId) =>
      (select(wodTemplateExercises)
            ..where((w) =>
                w.wodTemplateId.equals(wodTemplateId) &
                w.groupId.isNull())
            ..orderBy([(w) => OrderingTerm(expression: w.sortOrder)]))
          .get();

  /// Returns ALL exercises for a WOD (standalone + circuit), used for duplication.
  Future<List<WodTemplateExercise>> getAllTemplateExercises(
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

  // ── WOD Exercise Groups (Circuits) ────────────────────────────────────────

  Future<List<WodExerciseGroup>> getGroupsForWod(int wodTemplateId) =>
      (select(wodExerciseGroups)
            ..where((g) => g.wodTemplateId.equals(wodTemplateId))
            ..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
          .get();

  Future<int> insertGroup(WodExerciseGroupsCompanion entry) =>
      into(wodExerciseGroups).insert(entry);

  Future<void> updateGroup(WodExerciseGroupsCompanion entry) =>
      update(wodExerciseGroups).replace(entry);

  Future<void> deleteGroup(int groupId) async {
    // Detach any exercises that belonged to this group (make them standalone)
    await (update(wodTemplateExercises)
          ..where((e) => e.groupId.equals(groupId)))
        .write(const WodTemplateExercisesCompanion(groupId: Value(null)));
    await (delete(wodExerciseGroups)
          ..where((g) => g.id.equals(groupId)))
        .go();
  }

  Future<List<WodTemplateExercise>> getExercisesForGroup(int groupId) =>
      (select(wodTemplateExercises)
            ..where((e) => e.groupId.equals(groupId))
            ..orderBy([(e) => OrderingTerm(expression: e.sortOrder)]))
          .get();

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
          restSeconds: Value(wod.restSeconds),
        ));
        // Copy circuits first, then map old groupId → new groupId
        final groups = await getGroupsForWod(wod.id);
        final groupIdMap = <int, int>{};
        for (final g in groups) {
          final newGid = await insertGroup(WodExerciseGroupsCompanion(
            wodTemplateId: Value(newWodId),
            sortOrder: Value(g.sortOrder),
            name: Value(g.name),
            rounds: Value(g.rounds),
            restBetweenExercisesSeconds: Value(g.restBetweenExercisesSeconds),
            restBetweenRoundsSeconds: Value(g.restBetweenRoundsSeconds),
          ));
          groupIdMap[g.id] = newGid;
        }
        final exercises = await getAllTemplateExercises(wod.id);
        for (final ex in exercises) {
          final newGid =
              ex.groupId != null ? groupIdMap[ex.groupId!] : null;
          await insertWodTemplateExercise(WodTemplateExercisesCompanion(
            wodTemplateId: Value(newWodId),
            exerciseId: Value(ex.exerciseId),
            sortOrder: Value(ex.sortOrder),
            groupId: Value(newGid),
            targetSets: Value(ex.targetSets),
            repRangeMin: Value(ex.repRangeMin),
            repRangeMax: Value(ex.repRangeMax),
            notes: Value(ex.notes),
            restSeconds: Value(ex.restSeconds),
          ));
        }
      }
    }
    return newProgramId;
  }
}
