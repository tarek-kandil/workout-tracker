import 'dart:math';

class ProfileCalculations {
  final String gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final double targetWeightKg;
  final String fitnessGoal;
  final String activityLevel;
  // kg/week chosen pace; 0 for maintain/fitness
  final double weeklyRateKg;

  const ProfileCalculations({
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.targetWeightKg,
    required this.fitnessGoal,
    required this.activityLevel,
    this.weeklyRateKg = 0.5,
  });

  // ── BMI ──────────────────────────────────────────────────────────────────────

  double get bmi {
    final hm = heightCm / 100;
    return weightKg / (hm * hm);
  }

  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  // 0.0–1.0 position on the BMI bar (18.5 = 0, 40 = 1)
  double get bmiBarPosition => ((bmi - 18.5) / (40.0 - 18.5)).clamp(0.0, 1.0);

  // ── BMR — Mifflin-St Jeor ────────────────────────────────────────────────────

  double get bmr {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (gender) {
      case 'female':
        return base - 161;
      case 'male':
        return base + 5;
      default:
        return base - 78; // midpoint
    }
  }

  // ── TDEE ─────────────────────────────────────────────────────────────────────

  double get activityMultiplier {
    switch (activityLevel) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'active':
        return 1.725;
      case 'athletic':
        return 1.9;
      default:
        return 1.55;
    }
  }

  double get tdee => bmr * activityMultiplier;

  // ── Calorie target (driven by weeklyRateKg) ──────────────────────────────────

  // kcal equivalent of 1 kg body weight
  static const _kcalPerKg = 7700.0;

  double get dailyCalories {
    switch (fitnessGoal) {
      case 'lose':
        final deficit = weeklyRateKg * _kcalPerKg / 7;
        return max(tdee - deficit, 1200);
      case 'build':
        final surplus = weeklyRateKg * _kcalPerKg / 7;
        return tdee + surplus;
      case 'maintain':
      case 'fitness':
      default:
        return tdee;
    }
  }

  String get goalLabel {
    switch (fitnessGoal) {
      case 'lose':
        return 'To lose weight';
      case 'build':
        return 'To build muscle';
      case 'maintain':
        return 'Maintenance';
      case 'fitness':
        return 'To improve fitness';
      default:
        return 'Maintenance';
    }
  }

  // ── Macros ───────────────────────────────────────────────────────────────────

  /// 2 g/kg for muscle building, 1.8 g/kg for everything else
  double get proteinG =>
      weightKg * (fitnessGoal == 'build' ? 2.0 : 1.8);

  double get fatG => dailyCalories * 0.28 / 9;

  double get carbsG =>
      (dailyCalories - proteinG * 4 - fatG * 9) / 4;

  // ── Pace warning ─────────────────────────────────────────────────────────────

  /// null = safe, 'warn' = aggressive, 'danger' = very aggressive
  String? get paceWarning {
    switch (fitnessGoal) {
      case 'lose':
        if (weeklyRateKg >= 1.0) return 'danger';
        if (weeklyRateKg > 0.5) return 'warn';
        return null;
      case 'build':
        if (weeklyRateKg >= 0.75) return 'danger';
        if (weeklyRateKg > 0.25) return 'warn';
        return null;
      default:
        return null;
    }
  }

  // ── Timeline ─────────────────────────────────────────────────────────────────

  /// Weeks to reach targetWeightKg at current pace. Null if on target or no pace.
  double? get estimatedWeeks {
    final diff = (weightKg - targetWeightKg).abs();
    if (diff < 0.5 || weeklyRateKg < 0.01) return null;
    return diff / weeklyRateKg;
  }

  /// Human-readable date label, e.g. "Nov 2026". Null if > 5 years away.
  String? get estimatedDateLabel {
    final weeks = estimatedWeeks;
    if (weeks == null || weeks > 260) return null;
    final date = DateTime.now().add(Duration(days: (weeks * 7).round()));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  /// Recommended pace label for this goal
  static double recommendedRate(String goal) {
    switch (goal) {
      case 'lose':
        return 0.5;
      case 'build':
        return 0.25;
      default:
        return 0;
    }
  }
}
