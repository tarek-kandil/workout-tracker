import 'package:drift/drift.dart';

class Programs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  // 0 = active, 1 = completed, 2 = draft
  IntColumn get status => integer().withDefault(const Constant(2))();
  TextColumn get notes => text().nullable()();
}
