import 'package:drift/drift.dart';
import '../../utils/sync_ids.dart';

/// Cloud-sync & multi-device identity columns shared across all tables
/// (Schema v28 / Backend Phase 1).
///
/// - [syncId]: Globally unique UUID (deterministic UUID v5 for global catalog
///   rows; random UUID v4 for user-created rows). Maps 1-to-1 to the `id UUID`
///   primary key in Supabase Postgres.
/// - [userId]: Nullable owner `auth.uid()`. `null` for global library records
///   and local records created prior to first sign-in.
/// - [updatedAt]: UTC last-modified timestamp for incremental sync / LWW.
/// - [deletedAt]: Nullable UTC soft-delete tombstone timestamp for sync.
mixin SyncColumnsMixin on Table {
  TextColumn get syncId => text().clientDefault(generateUuidV4)();
  TextColumn get userId => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
