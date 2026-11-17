import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/challenges_table.dart';

part 'challenges_dao.g.dart';

@DriftAccessor(tables: [Challenges, ChallengeAttempts, ChallengeMilestones])
class ChallengesDao extends DatabaseAccessor<AppDatabase>
    with _$ChallengesDaoMixin {
  ChallengesDao(super.db);

  Stream<List<Challenge>> watchActiveChallenges() => (select(challenges)
        ..where((c) => c.isCompleted.equals(false))
        ..orderBy([(c) => OrderingTerm(expression: c.createdAt)]))
      .watch();

  Stream<List<Challenge>> watchCompletedChallenges() => (select(challenges)
        ..where((c) => c.isCompleted.equals(true))
        ..orderBy([
          (c) => OrderingTerm(
              expression: c.completedAt, mode: OrderingMode.desc),
        ]))
      .watch();

  Future<List<Challenge>> getAllChallenges() => select(challenges).get();

  Stream<List<ChallengeAttempt>> watchAttemptsForChallenge(int challengeId) =>
      (select(challengeAttempts)
            ..where((a) => a.challengeId.equals(challengeId))
            ..orderBy([
              (a) => OrderingTerm(
                  expression: a.date, mode: OrderingMode.desc),
              (a) => OrderingTerm(
                  expression: a.id, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<List<ChallengeAttempt>> getAttemptsForChallenge(int challengeId) =>
      (select(challengeAttempts)
            ..where((a) => a.challengeId.equals(challengeId))
            ..orderBy([
              (a) => OrderingTerm(
                  expression: a.date, mode: OrderingMode.desc),
              (a) => OrderingTerm(
                  expression: a.id, mode: OrderingMode.desc),
            ]))
          .get();

  Stream<List<ChallengeMilestone>> watchMilestonesForChallenge(
          int challengeId) =>
      (select(challengeMilestones)
            ..where((m) => m.challengeId.equals(challengeId))
            ..orderBy([
              (m) => OrderingTerm(
                  expression: m.achievedAt, mode: OrderingMode.desc),
            ]))
          .watch();

  Future<int> insertChallenge(ChallengesCompanion entry) =>
      into(challenges).insert(entry);

  Future<int> insertAttempt(ChallengeAttemptsCompanion entry) =>
      into(challengeAttempts).insert(entry);

  Future<void> deleteAttempt(int attemptId) =>
      (delete(challengeAttempts)..where((a) => a.id.equals(attemptId))).go();

  Future<int> insertMilestone(ChallengeMilestonesCompanion entry) =>
      into(challengeMilestones).insert(entry);

  Future<void> completeChallenge(int challengeId) =>
      (update(challenges)..where((c) => c.id.equals(challengeId))).write(
        ChallengesCompanion(
          isCompleted: const Value(true),
          completedAt: Value(DateTime.now()),
        ),
      );

  Future<void> extendChallengeTarget({
    required int challengeId,
    double? newTargetWeightKg,
    int? newTargetReps,
    int? newTargetDurationSeconds,
  }) =>
      (update(challenges)..where((c) => c.id.equals(challengeId))).write(
        ChallengesCompanion(
          targetWeightKg: Value(newTargetWeightKg),
          targetReps: Value(newTargetReps),
          targetDurationSeconds: Value(newTargetDurationSeconds),
          isCompleted: const Value(false),
          completedAt: const Value(null),
        ),
      );

  Future<void> deleteChallenge(int challengeId) =>
      (delete(challenges)..where((c) => c.id.equals(challengeId))).go();
}
