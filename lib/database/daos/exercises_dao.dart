import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/exercise_muscles_table.dart';
import '../../models/exercise_muscle_seed.dart';
import '../../utils/constants.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises, ExerciseMuscles])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  // ── Exercises ──────────────────────────────────────────────────────────────

  Stream<List<Exercise>> watchAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .watch();

  Future<List<Exercise>> getAllExercises() =>
      (select(exercises)
        ..orderBy([(e) => OrderingTerm(expression: e.name)]))
      .get();

  Future<Map<String, int>> getExerciseIdsByName() async {
    final all = await getAllExercises();
    return {for (final e in all) e.name: e.id};
  }

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((e) => e.id.equals(id))).go();

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
