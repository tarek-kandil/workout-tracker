enum SuggestionType { noHistory, increase, maintain, decrease }

/// Coaching suggestion for weight on the next session of an exercise.
class WeightSuggestion {
  final SuggestionType type;
  final double? suggestedKg;
  final String message;

  const WeightSuggestion({
    required this.type,
    required this.message,
    this.suggestedKg,
  });

  static const WeightSuggestion noHistory = WeightSuggestion(
    type: SuggestionType.noHistory,
    message: 'No data yet',
  );
}
