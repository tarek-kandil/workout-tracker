import 'package:drift/drift.dart';
import 'sync_columns_mixin.dart';

class BodyweightEntries extends Table with SyncColumnsMixin {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get notes => text().nullable()();
}
