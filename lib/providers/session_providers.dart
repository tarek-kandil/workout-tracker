import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/personal_record_entry.dart';
import 'database_provider.dart';

/// Stream of all sessions, most recent first. Used by the History tab.
final recentSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(databaseProvider).sessionsDao.watchRecentSessions(limit: 200);
});

/// All exercises with at least one logged set, with PR and estimated 1RM.
final personalRecordsProvider =
    FutureProvider<List<PersonalRecordEntry>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllPersonalRecords();
});
