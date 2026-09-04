import 'package:drift/drift.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isTimed =>
      boolean().withDefault(const Constant(false))();
  // Schema v20 (Muscle Taxonomy + Weekly Volume Report): true when the
  // v19->v20 migration could not confidently map this exercise's legacy
  // broad muscle tag(s) to the new 21-muscle taxonomy (FR-016/FR-017), or
  // when the athlete has not yet assigned any muscle to it.
  BoolColumn get muscleNeedsReview =>
      boolean().withDefault(const Constant(false))();
  // Human-readable note explaining what the migration guessed/excluded for
  // this exercise, surfaced in the exercise editor and library.
  TextColumn get muscleReviewNote => text().nullable()();
  // Schema v21 (non-destructive exercise deletion): true when the athlete
  // "deleted" this exercise from the library but it has logged workout
  // history (workout_sets rows) that must be preserved. Archived exercises
  // are hidden from the library and pickers, but their row (and therefore
  // their history/foreign keys) is kept intact. See
  // ExercisesDao.deleteOrArchiveExercise.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}
