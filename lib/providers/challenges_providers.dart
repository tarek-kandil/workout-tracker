import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/exercise_tracking_mode.dart';
import 'database_provider.dart';
import 'exercise_providers.dart';

class ChallengeViewData {
  final Challenge challenge;
  final Exercise exercise;
  final List<ChallengeAttempt> attempts; // newest first
  final List<ChallengeMilestone> milestones;

  const ChallengeViewData({
    required this.challenge,
    required this.exercise,
    required this.attempts,
    required this.milestones,
  });

  ExerciseTrackingMode get mode => exercise.mode;
  int get conqueredCount => milestones.length;

  ChallengeAttempt? get previousAttempt =>
      attempts.isNotEmpty ? attempts.first : null;

  ChallengeAttempt? get bestAttempt {
    if (attempts.isEmpty) return null;
    ChallengeAttempt best = attempts.first;
    for (final a in attempts.skip(1)) {
      if (_scoreOf(a) > _scoreOf(best)) {
        best = a;
      }
    }
    return best;
  }

  double _scoreOf(ChallengeAttempt a) {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return (a.durationSeconds ?? 0).toDouble();
      case ExerciseTrackingMode.bodyweightReps:
        return a.reps.toDouble();
      case ExerciseTrackingMode.weightedReps:
        return a.weightKg * (1.0 + a.reps / 30.0);
    }
  }

  double get targetScore {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return (challenge.targetDurationSeconds ?? 60).toDouble();
      case ExerciseTrackingMode.bodyweightReps:
        return (challenge.targetReps ?? 10).toDouble();
      case ExerciseTrackingMode.weightedReps:
        final w = challenge.targetWeightKg ?? 60.0;
        final r = challenge.targetReps ?? 1;
        return w * (1.0 + r / 30.0);
    }
  }

  double get progressFraction {
    final best = bestAttempt;
    if (best == null || targetScore <= 0) return 0.0;
    return (_scoreOf(best) / targetScore).clamp(0.0, 1.0);
  }

  int get progressPct => (progressFraction * 100).round();

  bool isTargetMetBy(ChallengeAttempt a) {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return (a.durationSeconds ?? 0) >=
            (challenge.targetDurationSeconds ?? 0);
      case ExerciseTrackingMode.bodyweightReps:
        return a.reps >= (challenge.targetReps ?? 0);
      case ExerciseTrackingMode.weightedReps:
        final tw = challenge.targetWeightKg ?? 0;
        final tr = challenge.targetReps ?? 1;
        return (a.weightKg >= tw && a.reps >= tr) ||
            _scoreOf(a) >= targetScore;
    }
  }

  bool isNewBest(ChallengeAttempt a) {
    final prevBest = bestAttempt;
    if (prevBest == null) return _scoreOf(a) > 0;
    return _scoreOf(a) > _scoreOf(prevBest);
  }

  String formatAttempt(ChallengeAttempt a) {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return fmtChallengeSec(a.durationSeconds ?? 0);
      case ExerciseTrackingMode.bodyweightReps:
        return '${a.reps} reps';
      case ExerciseTrackingMode.weightedReps:
        return '${fmtChallengeKg(a.weightKg)} kg × ${a.reps}';
    }
  }

  String get bestLabel {
    final b = bestAttempt;
    if (b == null) {
      return switch (mode) {
        ExerciseTrackingMode.timed => '0:00',
        ExerciseTrackingMode.bodyweightReps => '0',
        ExerciseTrackingMode.weightedReps => '—',
      };
    }
    return formatAttempt(b);
  }

  String get targetLabel {
    switch (mode) {
      case ExerciseTrackingMode.timed:
        return fmtChallengeSec(challenge.targetDurationSeconds ?? 60);
      case ExerciseTrackingMode.bodyweightReps:
        return '${challenge.targetReps ?? 10} reps';
      case ExerciseTrackingMode.weightedReps:
        final w = fmtChallengeKg(challenge.targetWeightKg ?? 60);
        final r = challenge.targetReps ?? 1;
        return r == 1 ? '$w kg' : '$w kg × $r';
    }
  }

  String get compactProgressLabel {
    final b = bestAttempt;
    switch (mode) {
      case ExerciseTrackingMode.timed:
        final cur = b != null ? fmtChallengeSec(b.durationSeconds ?? 0) : '0:00';
        return '$cur / $targetLabel';
      case ExerciseTrackingMode.bodyweightReps:
        final cur = b?.reps ?? 0;
        return '$cur / $targetLabel';
      case ExerciseTrackingMode.weightedReps:
        final cur = b != null ? fmtChallengeKg(b.weightKg) : '0';
        return '$cur / $targetLabel';
    }
  }
}

String fmtChallengeSec(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String fmtChallengeKg(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

final activeChallengesProvider =
    StreamProvider<List<ChallengeViewData>>((ref) {
  final db = ref.watch(databaseProvider);
  final exercises = ref.watch(exercisesProvider).valueOrNull ?? const [];
  final exMap = {for (final e in exercises) e.id: e};

  return db.challengesDao.watchActiveChallenges().asyncMap((list) async {
    final out = <ChallengeViewData>[];
    for (final c in list) {
      final ex = exMap[c.exerciseId];
      if (ex == null) continue;
      final attempts = await db.challengesDao.getAttemptsForChallenge(c.id);
      final milestones =
          await db.challengesDao.watchMilestonesForChallenge(c.id).first;
      out.add(ChallengeViewData(
        challenge: c,
        exercise: ex,
        attempts: attempts,
        milestones: milestones,
      ));
    }
    return out;
  });
});

final completedChallengesProvider =
    StreamProvider<List<ChallengeViewData>>((ref) {
  final db = ref.watch(databaseProvider);
  final exercises = ref.watch(exercisesProvider).valueOrNull ?? const [];
  final exMap = {for (final e in exercises) e.id: e};

  return db.challengesDao.watchCompletedChallenges().asyncMap((list) async {
    final out = <ChallengeViewData>[];
    for (final c in list) {
      final ex = exMap[c.exerciseId];
      if (ex == null) continue;
      final attempts = await db.challengesDao.getAttemptsForChallenge(c.id);
      final milestones =
          await db.challengesDao.watchMilestonesForChallenge(c.id).first;
      out.add(ChallengeViewData(
        challenge: c,
        exercise: ex,
        attempts: attempts,
        milestones: milestones,
      ));
    }
    return out;
  });
});
