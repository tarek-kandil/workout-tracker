import 'package:drift/drift.dart';
import 'exercises_table.dart';
import 'sync_columns_mixin.dart';

/// Per-user state attached to an exercise (especially global catalog exercises
/// whose shared row cannot hold personal `archived`, `notes`, or review state).
class UserExerciseSettings extends Table with SyncColumnsMixin {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  BoolColumn get muscleNeedsReview =>
      boolean().withDefault(const Constant(false))();
  TextColumn get muscleReviewNote => text().nullable()();
}
