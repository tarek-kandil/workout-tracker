/// Whether an exercise-muscle assignment is the primary mover (1.0 effective
/// set per completed set) or a secondary contributor (0.5).
enum ExerciseMuscleRole { primary, secondary }

/// A single role-aware default muscle assignment used to seed exercises.
/// See specs/003-muscle-volume-report/data-model.md "Role-aware default
/// exercise assignments".
class ExerciseMuscleSeed {
  final String muscle;
  final ExerciseMuscleRole role;

  const ExerciseMuscleSeed.primary(this.muscle) : role = ExerciseMuscleRole.primary;
  const ExerciseMuscleSeed.secondary(this.muscle) : role = ExerciseMuscleRole.secondary;

  const ExerciseMuscleSeed(this.muscle, this.role);
}
