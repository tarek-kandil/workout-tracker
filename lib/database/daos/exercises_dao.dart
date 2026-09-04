import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/exercise_muscles_table.dart';
import '../tables/sets_table.dart';
import '../tables/wod_template_exercises_table.dart';
import '../tables/exercise_notes_table.dart';
import '../../models/exercise_muscle_seed.dart';
import '../../utils/constants.dart';

part 'exercises_dao.g.dart';

/// Outcome of [ExercisesDao.deleteOrArchiveExercise], so callers can tailor
/// their UI feedback (e.g. a different SnackBar message).
enum ExerciseDeleteOutcome {
  /// The exercise had no logged history (no workout_sets rows) and was
  /// permanently removed, along with its program-template references and
  /// notes (exercise_muscles/exercise_variations cascade automatically).
  hardDeleted,

  /// The exercise had logged history, so it was kept (never destructive to
  /// workout history) but archived: `archived = true`, hidden from the
  /// library/pickers, and removed from program templates.
  archived,
}

@DriftAccessor(tables: [
  Exercises,
  ExerciseMuscles,
  WorkoutSets,
  WodTemplateExercises,
  ExerciseNotes,
])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  // ── Exercises ──────────────────────────────────────────────────────────────

  /// Live, library/picker-facing list: excludes archived exercises.
  Stream<List<Exercise>> watchAllExercises() =>
      (select(exercises)
        ..where((e) => e.archived.equals(false))
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .watch();

  /// One-shot, library/picker-facing list: excludes archived exercises.
  Future<List<Exercise>> getAllExercises() =>
      (select(exercises)
        ..where((e) => e.archived.equals(false))
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .get();

  /// Every exercise row regardless of [Exercise.archived]. Use this instead
  /// of [getAllExercises] whenever archived rows must still be visible —
  /// e.g. default-exercise seeding/name-matching (so a re-seed never
  /// duplicate-inserts an archived exercise) or resolving exercise names for
  /// past workout history that may reference an archived exercise.
  Future<List<Exercise>> getAllExercisesIncludingArchived() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .get();

  /// Name → id map over *all* rows (including archived), so seeding/migration
  /// never misses an already-seeded (but archived) exercise and re-inserts a
  /// duplicate.
  Future<Map<String, int>> getExerciseIdsByName() async {
    final all = await getAllExercisesIncludingArchived();
    return {for (final e in all) e.name: e.id};
  }

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  /// Deprecated: throws a foreign-key constraint error if the exercise has
  /// logged history, is used in a program template, or has a note (see
  /// sets_table.dart/wod_template_exercises_table.dart/exercise_notes_table.dart
  /// — all reference Exercises with the default RESTRICT action). Prefer
  /// [deleteOrArchiveExercise], which is always safe to call.
  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

  /// Always-safe replacement for [deleteExercise]. Never throws a foreign-key
  /// error and never deletes logged workout history:
  ///  - If the exercise has NO workout_sets rows, it is hard-deleted after
  ///    first removing the rows that would otherwise block it under the
  ///    default RESTRICT foreign key (its wod_template_exercises rows and
  ///    exercise_notes rows). exercise_muscles/exercise_variations cascade
  ///    automatically.
  ///  - If the exercise HAS workout_sets rows, it is archived instead
  ///    (`archived = true`) so history stays intact, and it is removed from
  ///    program templates (wod_template_exercises) so it leaves active
  ///    programs. In both cases it disappears from the library and pickers
  ///    immediately (see [watchAllExercises]/[getAllExercises]).
  Future<ExerciseDeleteOutcome> deleteOrArchiveExercise(int id) {
    return transaction(() async {
      final setCount = await (selectOnly(workoutSets)
            ..addColumns([workoutSets.id.count()])
            ..where(workoutSets.exerciseId.equals(id)))
          .map((row) => row.read(workoutSets.id.count()) ?? 0)
          .getSingle();

      // Always leave active program templates, regardless of outcome.
      await (delete(wodTemplateExercises)
            ..where((te) => te.exerciseId.equals(id)))
          .go();

      if (setCount == 0) {
        await (delete(exerciseNotes)
              ..where((n) => n.exerciseId.equals(id)))
            .go();
        await (delete(exercises)..where((e) => e.id.equals(id))).go();
        return ExerciseDeleteOutcome.hardDeleted;
      }

      await (update(exercises)..where((e) => e.id.equals(id))).write(
        const ExercisesCompanion(archived: Value(true)),
      );
      return ExerciseDeleteOutcome.archived;
    });
  }

  Future<void> seedExercises(List<ExercisesCompanion> entries) async {
    await batch((b) => b.insertAllOnConflictUpdate(exercises, entries));
  }

  // ── Muscles (schema v20: role-aware, active-row model) ─────────────────────

  /// Exercises flagged during the v20 taxonomy migration (or still
  /// unassigned) as needing an athlete review of their muscle assignment
  /// (FR-016/FR-017).
  Future<List<Exercise>> getExercisesNeedingMuscleReview() =>
      (select(exercises)..where((e) => e.muscleNeedsReview.equals(true)))
          .get();

  /// Clears the "needs review" flag for one exercise — called once the
  /// athlete has saved an intentional muscle assignment for it.
  Future<void> clearMuscleReview(int exerciseId) =>
      (update(exercises)..where((e) => e.id.equals(exerciseId))).write(
        const ExercisesCompanion(
          muscleNeedsReview: Value(false),
          muscleReviewNote: Value(null),
        ),
      );

  /// Returns active muscle assignments for one exercise, primary first, then
  /// by sortOrder. Legacy/inactive rows preserved by the v20 migration are
  /// excluded.
  Future<List<ExerciseMuscle>> getMusclesForExercise(int exerciseId) =>
      (select(exerciseMuscles)
            ..where((m) =>
                m.exerciseId.equals(exerciseId) & m.isActive.equals(true))
            ..orderBy([
              (m) => OrderingTerm(
                  expression: m.role.equals(kMuscleRolePrimary),
                  mode: OrderingMode.desc),
              (m) => OrderingTerm(expression: m.sortOrder),
            ]))
          .get();

  /// Replaces the *active* muscle assignments for an exercise with
  /// [assignments]. Never deletes rows: any currently-active row is marked
  /// `is_active = 0` first, then the new assignments are inserted as fresh
  /// active rows. This keeps the operation non-destructive for history/audit
  /// purposes while still reflecting exactly what the athlete (or seed data)
  /// intends right now.
  ///
  /// [assignments] order is preserved as `sortOrder`. Callers (UI, seeding)
  /// are responsible for validating "at least one primary" before calling
  /// for exercises meant to contribute to muscle volume.
  Future<void> setMusclesForExercise(
    int exerciseId,
    List<ExerciseMuscleSeed> assignments, {
    bool clearReview = true,
  }) async {
    await (update(exerciseMuscles)
          ..where((m) =>
              m.exerciseId.equals(exerciseId) & m.isActive.equals(true)))
        .write(const ExerciseMusclesCompanion(isActive: Value(false)));

    for (int i = 0; i < assignments.length; i++) {
      final seed = assignments[i];
      await into(exerciseMuscles).insert(ExerciseMusclesCompanion(
        exerciseId: Value(exerciseId),
        muscle: Value(seed.muscle),
        sortOrder: Value(i),
        role: Value(seed.role == ExerciseMuscleRole.primary
            ? kMuscleRolePrimary
            : kMuscleRoleSecondary),
        isActive: const Value(true),
      ));
    }

    if (clearReview) {
      await clearMuscleReview(exerciseId);
    }
  }

  /// Reactive map: exerciseId → active [ExerciseMuscle] rows, primary first.
  /// Empty list means no active muscle assigned for that exercise.
  Stream<Map<int, List<ExerciseMuscle>>> watchAllMuscleAssignmentMap() =>
      _muscleAssignmentMapQuery().watch().map(_groupMuscleRows);

  /// One-shot equivalent of [watchAllMuscleAssignmentMap]. Prefer this in
  /// short-lived UI (e.g. a bottom sheet) that doesn't need live updates —
  /// it avoids leaving a long-lived `.watch()` stream subscription open for
  /// the life of the widget tree.
  Future<Map<int, List<ExerciseMuscle>>> getAllMuscleAssignmentMap() =>
      _muscleAssignmentMapQuery().get().then(_groupMuscleRows);

  SimpleSelectStatement<$ExerciseMusclesTable, ExerciseMuscle>
      _muscleAssignmentMapQuery() => select(exerciseMuscles)
        ..where((m) => m.isActive.equals(true))
        ..orderBy([
          (m) => OrderingTerm(
              expression: m.role.equals(kMuscleRolePrimary),
              mode: OrderingMode.desc),
          (m) => OrderingTerm(expression: m.sortOrder),
        ]);

  Map<int, List<ExerciseMuscle>> _groupMuscleRows(List<ExerciseMuscle> rows) {
    final map = <int, List<ExerciseMuscle>>{};
    for (final r in rows) {
      (map[r.exerciseId] ??= []).add(r);
    }
    return map;
  }
}
