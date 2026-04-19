import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/sessions_table.dart';
import '../tables/wod_templates_table.dart';
import '../tables/program_phases_table.dart';

part 'sessions_dao.g.dart';

class SessionWithProgram {
  final WorkoutSession session;
  final String? programName;
  const SessionWithProgram({required this.session, this.programName});
}

@DriftAccessor(tables: [WorkoutSessions, WodTemplates, ProgramPhases])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  Stream<List<WorkoutSession>> watchRecentSessions({int limit = 20}) =>
      (select(workoutSessions)
            ..orderBy([(s) =>
                OrderingTerm(expression: s.date, mode: OrderingMode.desc)])
            ..limit(limit))
          .watch();

  Future<int> insertSession(WorkoutSessionsCompanion entry) =>
      into(workoutSessions).insert(entry);

  Future<void> updateSession(WorkoutSessionsCompanion entry) =>
      update(workoutSessions).replace(entry);

  Future<void> deleteSession(int sessionId) =>
      (delete(workoutSessions)..where((s) => s.id.equals(sessionId))).go();

  // ── Program-linked session queries ────────────────────────────────────────

  /// Most recent session belonging to a program (any WOD, any phase)
  Future<WorkoutSession?> getLastSessionForProgram(int programId) async {
    final query = select(workoutSessions).join([
      innerJoin(wodTemplates,
          wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
      innerJoin(programPhases,
          programPhases.id.equalsExp(wodTemplates.phaseId)),
    ]);
    query
      ..where(programPhases.programId.equals(programId))
      ..orderBy([
        OrderingTerm(
            expression: workoutSessions.date, mode: OrderingMode.desc)
      ])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.readTable(workoutSessions);
  }

  /// Earliest session for a program — used to derive the program start date
  Future<WorkoutSession?> getFirstSessionForProgram(int programId) async {
    final query = select(workoutSessions).join([
      innerJoin(wodTemplates,
          wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
      innerJoin(programPhases,
          programPhases.id.equalsExp(wodTemplates.phaseId)),
    ]);
    query
      ..where(programPhases.programId.equals(programId))
      ..orderBy([OrderingTerm(expression: workoutSessions.date)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.readTable(workoutSessions);
  }

  /// All sessions for a program, oldest first — used for streak calculation
  Future<List<WorkoutSession>> getSessionsForProgram(int programId) async {
    final query = select(workoutSessions).join([
      innerJoin(wodTemplates,
          wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
      innerJoin(programPhases,
          programPhases.id.equalsExp(wodTemplates.phaseId)),
    ]);
    query
      ..where(programPhases.programId.equals(programId))
      ..orderBy([OrderingTerm(expression: workoutSessions.date)]);

    final results = await query.get();
    return results.map((r) => r.readTable(workoutSessions)).toList();
  }

  /// Number of distinct WODs completed in a given week for a program
  Future<int> getCompletedWodCountInWeek(
      int programId, int weekNumber) async {
    final query = select(workoutSessions).join([
      innerJoin(wodTemplates,
          wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
      innerJoin(programPhases,
          programPhases.id.equalsExp(wodTemplates.phaseId)),
    ]);
    query
      ..where(programPhases.programId.equals(programId))
      ..where(workoutSessions.weekNumber.equals(weekNumber));

    final results = await query.get();
    return results.length;
  }

  Future<void> clearAllSessions() => delete(workoutSessions).go();

  /// Sessions joined with their program name — used by the history screen.
  Stream<List<SessionWithProgram>> watchSessionsWithProgram({int limit = 200}) {
    final query = (select(workoutSessions)
          ..orderBy([(t) =>
              OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .join([
      leftOuterJoin(
          wodTemplates, wodTemplates.id.equalsExp(workoutSessions.wodTemplateId),
          useColumns: false),
      leftOuterJoin(
          programPhases, programPhases.id.equalsExp(wodTemplates.phaseId),
          useColumns: false),
      leftOuterJoin(
          programs, programs.id.equalsExp(programPhases.programId),
          useColumns: false),
    ]);

    return query.watch().map((rows) => rows.map((row) {
          return SessionWithProgram(
            session: row.readTable(workoutSessions),
            programName: row.readTableOrNull(programs)?.name,
          );
        }).toList());
  }

  /// Most recent session that used any WOD belonging to [phaseId].
  /// Simpler join path than getLastSessionForProgram — used for WOD rotation.
  Future<WorkoutSession?> getLastSessionForPhase(int phaseId) async {
    final query = select(workoutSessions).join([
      innerJoin(
          wodTemplates, wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
    ]);
    query
      ..where(wodTemplates.phaseId.equals(phaseId))
      ..orderBy([
        OrderingTerm(expression: workoutSessions.date, mode: OrderingMode.desc),
      ])
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.readTable(workoutSessions);
  }

  /// Number of sessions that used any WOD belonging to [phaseId].
  /// Used for session-count-based week calculation.
  Future<int> getSessionCountForPhase(int phaseId) async {
    final query = select(workoutSessions).join([
      innerJoin(
          wodTemplates, wodTemplates.id.equalsExp(workoutSessions.wodTemplateId)),
    ]);
    query.where(wodTemplates.phaseId.equals(phaseId));
    final results = await query.get();
    return results.length;
  }

  /// Sessions for a specific WOD template (for progressive overload reference)
  Future<List<WorkoutSession>> getSessionsForWodTemplate(
          int wodTemplateId) =>
      (select(workoutSessions)
            ..where((s) => s.wodTemplateId.equals(wodTemplateId))
            ..orderBy([(s) =>
                OrderingTerm(expression: s.date, mode: OrderingMode.desc)]))
          .get();
}
