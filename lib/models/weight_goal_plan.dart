import '../database/app_database.dart';

/// Immutable snapshot of the user's active weight goal plan, derived from
/// [UserProfile]. Reuses the existing `targetWeightKg`, `weeklyRateKg` and
/// `fitnessGoal` profile columns for the plan itself (per the app's existing
/// calorie/macro recommendation approach) plus the plan-specific fields
/// added in schema v19 (planStartDate, planStartWeightKg, planTargetDate,
/// weighInIntervalDays, weighInRemindersEnabled).
class WeightGoalPlan {
  /// lose | build | maintain
  final String goalDirection;
  final DateTime startDate;
  final double startWeightKg;
  final double targetWeightKg;
  final DateTime targetDate;
  final int weighInIntervalDays;
  final bool remindersEnabled;

  // Profile fields needed to derive calories/macros via ProfileCalculations.
  final String gender;
  final int age;
  final double heightCm;
  final String activityLevel;

  const WeightGoalPlan({
    required this.goalDirection,
    required this.startDate,
    required this.startWeightKg,
    required this.targetWeightKg,
    required this.targetDate,
    required this.weighInIntervalDays,
    required this.remindersEnabled,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.activityLevel,
  });

  /// Maintenance plans — either an explicit `maintain` goal, or a desired
  /// weight equal to the current/start weight per FR-013 — have no
  /// direction of progress to chase.
  bool get isMaintenance =>
      goalDirection == 'maintain' ||
      (targetWeightKg - startWeightKg).abs() < 0.05;

  /// Whole-plan duration in weeks (fractional). Clamped to a minimum of a
  /// single day so same-day start/target dates never divide by zero.
  double get durationWeeks {
    final hours = targetDate.difference(startDate).inHours;
    final days = hours / 24.0;
    return (days / 7.0).clamp(1 / 7, double.infinity);
  }

  /// Required weekly pace to hit [targetWeightKg] by [targetDate].
  /// Always a positive magnitude (kg/week); 0 for maintenance plans.
  double get requiredWeeklyRateKg {
    if (isMaintenance) return 0;
    return (targetWeightKg - startWeightKg).abs() / durationWeeks;
  }

  /// Derives a plan from the user's profile row. Returns null when no
  /// active plan exists (setup was never completed / plan fields are null).
  static WeightGoalPlan? fromProfile(UserProfile? profile) {
    if (profile == null ||
        profile.planStartDate == null ||
        profile.planStartWeightKg == null ||
        profile.planTargetDate == null ||
        profile.targetWeightKg == null ||
        profile.age == null ||
        profile.heightCm == null) {
      return null;
    }
    return WeightGoalPlan(
      goalDirection: profile.fitnessGoal == 'fitness'
          ? 'maintain'
          : profile.fitnessGoal,
      startDate: profile.planStartDate!,
      startWeightKg: profile.planStartWeightKg!,
      targetWeightKg: profile.targetWeightKg!,
      targetDate: profile.planTargetDate!,
      weighInIntervalDays: profile.weighInIntervalDays ?? 7,
      remindersEnabled: profile.weighInRemindersEnabled ?? true,
      gender: profile.gender,
      age: profile.age!,
      heightCm: profile.heightCm!,
      activityLevel: profile.activityLevel,
    );
  }
}
