import 'package:drift/drift.dart';

import 'exercises_table.dart';

class ExerciseNotes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  TextColumn get note => text().withLength(min: 1)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
