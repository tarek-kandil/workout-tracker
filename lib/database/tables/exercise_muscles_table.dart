import 'package:drift/drift.dart';
import 'exercises_table.dart';

class ExerciseMuscles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => text()();
  IntColumn get sortOrder => integer()();
}
