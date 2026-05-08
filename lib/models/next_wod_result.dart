import '../database/app_database.dart';
import 'weight_suggestion.dart';
import 'wod_item.dart';

/// An exercise in the upcoming WOD together with its weight suggestion.
class WodExerciseEntry {
  final WodTemplateExercise templateExercise;
  final Exercise exercise;
  final WeightSuggestion suggestion;

  const WodExerciseEntry({
    required this.templateExercise,
    required this.exercise,
    required this.suggestion,
  });
}

/// Full context for the "Next Workout" card / session screen.
class NextWodResult {
  final Program program;
  final ProgramPhase phase;
  final int phaseIndex; // 1-based
  final int totalPhases;
  final WodTemplate wodTemplate;
  final int weekNumberInProgram; // 1-based
  final int totalProgramWeeks; // sum of all phase durations
  /// Ordered list of WOD items (standalone exercises and circuits).
  final List<WodItem> items;
  /// Date of the most recent completed session for this WOD (null = first ever)
  final DateTime? lastSessionDate;

  const NextWodResult({
    required this.program,
    required this.phase,
    required this.phaseIndex,
    required this.totalPhases,
    required this.wodTemplate,
    required this.weekNumberInProgram,
    required this.totalProgramWeeks,
    required this.items,
    this.lastSessionDate,
  });

  /// Flat list of all exercises (from standalone items and circuit items).
  /// Useful for display in non-session contexts.
  List<WodExerciseEntry> get allExercises => [
        for (final item in items)
          if (item is StandaloneWodExercise)
            item.entry
          else if (item is WodCircuit)
            ...item.exercises,
      ];
}
