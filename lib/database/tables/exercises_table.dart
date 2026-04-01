import 'package:drift/drift.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get notes => text().nullable()();
}
