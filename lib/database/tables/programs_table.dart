import 'package:drift/drift.dart';
import 'sync_columns_mixin.dart';

class Programs extends Table with SyncColumnsMixin {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  // 0 = active, 1 = completed, 2 = draft
  IntColumn get status => integer().withDefault(const Constant(2))();
  TextColumn get notes => text().nullable()();
  // Schema v28: ownership-ready columns for future public ready-made programs.
  BoolColumn get isPublic => boolean().withDefault(const Constant(false))();
  TextColumn get sourceProgramSyncId => text().nullable()();
}
