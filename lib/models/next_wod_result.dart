import '../database/app_database.dart';
import 'weight_suggestion.dart';

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

/// Full context for the "Next Workout" card on the home screen.
class NextWodResult {
  final Program program;
  final ProgramPhase phase;
  final int phaseIndex; // 1-based
  final int totalPhases;
  final WodTemplate wodTemplate;
  final int weekNumberInProgram; // 1-based
  final int totalProgramWeeks; // sum of all phase durations
  final List<WodExerciseEntry> exercises;
  /// Date of the most recent completed session for this program (null = first ever)
  final DateTime? lastSessionDate;

  const NextWodResult({
    required this.program,
    required this.phase,
    required this.phaseIndex,
    required this.totalPhases,
    required this.wodTemplate,
    required this.weekNumberInProgram,
    required this.totalProgramWeeks,
    required this.exercises,
    this.lastSessionDate,
  });
}
