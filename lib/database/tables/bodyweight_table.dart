import 'package:drift/drift.dart';

class BodyweightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  RealColumn get weightKg => real()();
  TextColumn get notes => text().nullable()();
}
