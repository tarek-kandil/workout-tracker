enum SuggestionType { noHistory, increase, increaseReps, maintain, decrease }

/// Coaching suggestion for weight, reps, or duration on the next session of an exercise.
class WeightSuggestion {
  final SuggestionType type;
  final double? suggestedKg;
  final int? suggestedReps;
  final int? suggestedDurationSeconds;
  final String message;

  const WeightSuggestion({
    required this.type,
    required this.message,
    this.suggestedKg,
    this.suggestedReps,
    this.suggestedDurationSeconds,
  });

  static const WeightSuggestion noHistory = WeightSuggestion(
    type: SuggestionType.noHistory,
    message: 'No data yet',
  );
}
