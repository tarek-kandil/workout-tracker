class PersonalRecordAttemptResult {
  final bool isPersonalRecord;
  final bool isNewTopWeight;
  final bool isMoreRepsAtTopWeight;

  const PersonalRecordAttemptResult({
    required this.isPersonalRecord,
    required this.isNewTopWeight,
    required this.isMoreRepsAtTopWeight,
  });

  static const none = PersonalRecordAttemptResult(
    isPersonalRecord: false,
    isNewTopWeight: false,
    isMoreRepsAtTopWeight: false,
  );
}

const double _weightToleranceKg = 0.0001;

bool sameRecordWeight(double a, double b) =>
    (a - b).abs() <= _weightToleranceKg;

PersonalRecordAttemptResult evaluateWeightPersonalRecord({
  required double? currentTopWeightKg,
  required int bestRepsAtCurrentTopWeight,
  required double weightKg,
  required int reps,
}) {
  if (weightKg <= 0 || reps <= 0) return PersonalRecordAttemptResult.none;

  final currentTop = currentTopWeightKg ?? 0.0;
  final isNewTopWeight = weightKg > currentTop + _weightToleranceKg;
  final isMoreRepsAtTopWeight =
      sameRecordWeight(weightKg, currentTop) &&
      reps > bestRepsAtCurrentTopWeight;

  return PersonalRecordAttemptResult(
    isPersonalRecord: isNewTopWeight || isMoreRepsAtTopWeight,
    isNewTopWeight: isNewTopWeight,
    isMoreRepsAtTopWeight: isMoreRepsAtTopWeight,
  );
}
