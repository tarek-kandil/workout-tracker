import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/sessions_dao.dart';
import '../database/daos/sets_dao.dart';
import '../models/personal_record_entry.dart';
import 'database_provider.dart';

/// Stream of all sessions, most recent first. Used by the History tab.
final recentSessionsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(databaseProvider).sessionsDao.watchRecentSessions(limit: 200);
});

/// Sessions with program name joined — used by the history screen.
final sessionHistoryProvider =
    StreamProvider<List<SessionWithProgram>>((ref) {
  return ref
      .watch(databaseProvider)
      .sessionsDao
      .watchSessionsWithProgram(limit: 200);
});

/// All exercises with at least one logged set, with PR and estimated 1RM.
final personalRecordsProvider =
    FutureProvider<List<PersonalRecordEntry>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllPersonalRecords();
});

/// Reactive stream of sets for a single session — used by session detail
/// so edits reflect immediately without a reload.
final setsForSessionProvider =
    StreamProvider.family<List<WorkoutSet>, int>((ref, sessionId) {
  return ref
      .watch(databaseProvider)
      .setsDao
      .watchSetsForSession(sessionId);
});

/// Batch stats (volume, sets, RIR, top weight, PR count) for every session.
/// Invalidated after any set edit or delete so the history list stays fresh.
final allSessionStatsProvider =
    FutureProvider<Map<int, SessionSetStats>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllSessionStats();
});
