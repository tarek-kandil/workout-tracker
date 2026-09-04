import 'dart:math';

import '../database/app_database.dart';
import '../models/weight_goal_plan.dart';
import 'profile_calculations.dart';

/// Coaching status for a weight goal plan, evaluated at the latest weigh-in
/// (or at "now" when no weigh-ins have been logged yet).
enum WeightGoalVerdict {
  /// No active plan exists.
  noPlan,

  /// Not enough weigh-in data since the plan started to compute a reliable
  /// trend (0 or 1 readings). Provisional — never confirms a calorie change.
  buildingTrend,

  /// Actual progress is within tolerance of the planned pace.
  onTrack,

  /// Progress is slower than planned (beyond tolerance).
  behind,

  /// Progress is faster than planned but still within a safe pace.
  ahead,

  /// Progress is faster than planned and the *actual* pace itself has
  /// entered the caution zone (warn-level pace).
  tooFast,

  /// Actual pace has entered the danger zone — a real safety concern.
  unsafe,

  /// Short-term trend has been flat (~<0.10 kg/wk) for two consecutive
  /// check-ins while pursuing a loss/build goal.
  plateau,

  /// Maintenance plan, trend within the maintenance band.
  maintenanceOnTrack,

  /// Trend weight is within the target band of the desired weight.
  goalReached,
}

/// Macro suggestion in grams, alongside the calorie target it was derived
/// from.
class MacroTargets {
  final double dailyCalories;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const MacroTargets({
    required this.dailyCalories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });
}

/// A single point on the trend/projection chart.
class WeightChartPoint {
  final DateTime date;
  final double? actualKg;
  final double projectedKg;
  const WeightChartPoint({
    required this.date,
    required this.actualKg,
    required this.projectedKg,
  });
}

/// Full coaching evaluation for the current state of a plan.
class WeightGoalProgress {
  final WeightGoalVerdict verdict;
  final String message;
  final bool isProvisional;

  /// True once a behind/ahead/tooFast direction has repeated for two
  /// consecutive check-ins (FR-022). Never true for the very first
  /// off-track check-in in a new direction.
  final bool isConfirmed;

  /// Suggested daily calorie delta (kcal/day) implied by the current
  /// status. Null when no adjustment is suggested (on track / provisional /
  /// no plan). This is guidance only — the app never auto-applies it
  /// (FR-025).
  final int? suggestedKcalDelta;

  final double? trendWeightKg;
  final double? expectedWeightTodayKg;
  final double? actualRateKgPerWeek;
  final double? plannedRateKgPerWeek;
  final double? toleranceKgPerWeek;

  final double? dailyCalories;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;

  final double? weeksRemaining;

  /// 0.0–1.0 fraction of the plan's weight distance covered so far, for a
  /// progress bar. Clamped; null when there's no meaningful start→target
  /// distance (maintenance plans).
  final double? progressFraction;

  final List<WeightChartPoint> chartPoints;

  const WeightGoalProgress({
    required this.verdict,
    required this.message,
    this.isProvisional = false,
    this.isConfirmed = false,
    this.suggestedKcalDelta,
    this.trendWeightKg,
    this.expectedWeightTodayKg,
    this.actualRateKgPerWeek,
    this.plannedRateKgPerWeek,
    this.toleranceKgPerWeek,
    this.dailyCalories,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.weeksRemaining,
    this.progressFraction,
    this.chartPoints = const [],
  });

  static const noPlan = WeightGoalProgress(
    verdict: WeightGoalVerdict.noPlan,
    message: 'Set a weight goal to get a personalized plan.',
  );
}

/// A single evaluated check-in used internally to detect two-consecutive
/// off-track streaks (FR-022) and plateaus (FR-023).
class _CheckIn {
  final DateTime date;
  final double trendWeightKg;
  final bool isProvisional;
  final double elapsedWeeks;

  /// Positive = progress in the intended direction (loss for `lose`, gain
  /// for `build`) since plan start, measured via the short-term trend.
  final double actualRateKgPerWeek;

  /// Positive = progress in the intended direction since the *previous*
  /// check-in (used for plateau detection).
  final double shortTermRateKgPerWeek;

  const _CheckIn({
    required this.date,
    required this.trendWeightKg,
    required this.isProvisional,
    required this.elapsedWeeks,
    required this.actualRateKgPerWeek,
    required this.shortTermRateKgPerWeek,
  });
}

/// Wraps [ProfileCalculations] to implement the Weight Goal Coaching Loop:
/// pace guardrails, on-track tolerance, plateau/maintenance/goal-reached
/// detection, and calorie/macro suggestions. Never mutates the plan itself
/// (FR-025) — everything here is a pure, side-effect-free read.
class WeightGoalCalculations {
  const WeightGoalCalculations._();

  static const _kMinWeeks = 1 / 7; // 1 day, avoids divide-by-zero

  // ── Pace guardrails (FR-009 / FR-010) ───────────────────────────────────

  /// null = safe, 'warn' = aggressive, 'danger' = not recommended.
  /// [rateKgPerWeek] is a positive magnitude.
  static String? paceWarningFor(String goalDirection, double rateKgPerWeek) {
    switch (goalDirection) {
      case 'lose':
        if (rateKgPerWeek >= 1.0) return 'danger';
        if (rateKgPerWeek > 0.5) return 'warn';
        return null;
      case 'build':
        if (rateKgPerWeek >= 0.75) return 'danger';
        if (rateKgPerWeek > 0.25) return 'warn';
        return null;
      default:
        return null;
    }
  }

  // ── Tolerance band (FR-018) ──────────────────────────────────────────────

  static double toleranceKgPerWeek(double plannedRateKgPerWeek) =>
      max(0.10, min(0.25, plannedRateKgPerWeek * 0.50));

  // ── Calories & macros ────────────────────────────────────────────────────

  /// Daily calorie target for the plan's required pace, using the given
  /// [weightKgForCalc] as the current bodyweight input to BMR (the trend
  /// weight when available, else the plan's start weight).
  static double dailyCaloriesFor(
    WeightGoalPlan plan, {
    required double weightKgForCalc,
    double? weeklyRateOverrideKg,
    String? goalDirectionOverride,
  }) {
    final calc = ProfileCalculations(
      gender: plan.gender,
      age: plan.age,
      heightCm: plan.heightCm,
      weightKg: weightKgForCalc,
      targetWeightKg: plan.targetWeightKg,
      fitnessGoal: goalDirectionOverride ?? plan.goalDirection,
      activityLevel: plan.activityLevel,
      weeklyRateKg: weeklyRateOverrideKg ?? plan.requiredWeeklyRateKg,
    );
    return calc.dailyCalories;
  }

  /// Macro refinement per the Coach's rules:
  ///  - cut: protein ≥1.8 g/kg, bumped to 2.0 g/kg if the loss pace is
  ///    faster than 0.5 kg/wk
  ///  - build: 2.0 g/kg
  ///  - fat: 28% of calories, floored near 0.6 g/kg when calories allow
  ///  - carbs: remainder
  static MacroTargets macrosFor(
    WeightGoalPlan plan, {
    required double weightKgForCalc,
    double? weeklyRateOverrideKg,
    String? goalDirectionOverride,
  }) {
    final goal = goalDirectionOverride ?? plan.goalDirection;
    final rate = weeklyRateOverrideKg ?? plan.requiredWeeklyRateKg;
    final calories = dailyCaloriesFor(
      plan,
      weightKgForCalc: weightKgForCalc,
      weeklyRateOverrideKg: rate,
      goalDirectionOverride: goal,
    );

    double proteinPerKg;
    if (goal == 'build') {
      proteinPerKg = 2.0;
    } else if (goal == 'lose') {
      proteinPerKg = rate > 0.5 ? 2.0 : 1.8;
    } else {
      proteinPerKg = 1.8;
    }
    final protein = weightKgForCalc * proteinPerKg;

    var fat = calories * 0.28 / 9;
    final minFat = weightKgForCalc * 0.6;
    // Only raise fat toward the floor if calories allow without pushing
    // carbs negative.
    if (fat < minFat) {
      final carbsAtMinFat = (calories - protein * 4 - minFat * 9) / 4;
      if (carbsAtMinFat >= 0) fat = minFat;
    }

    final carbs = max(0.0, (calories - protein * 4 - fat * 9) / 4);

    return MacroTargets(
      dailyCalories: calories,
      proteinG: protein,
      fatG: fat,
      carbsG: carbs,
    );
  }

  // ── Trend & check-in replay ──────────────────────────────────────────────

  static double _weeksBetween(DateTime a, DateTime b) =>
      max(b.difference(a).inHours / (24.0 * 7.0), _kMinWeeks);

  /// Signed "progress so far" toward the goal direction: positive means
  /// movement in the intended direction (down for lose, up for build).
  static double _progressMagnitude(
      String goalDirection, double fromKg, double toKg) {
    if (goalDirection == 'build') return toKg - fromKg;
    return fromKg - toKg; // lose (and maintenance, unused for rate calc)
  }

  /// Replays every logged weigh-in since [plan.startDate] into a sequence
  /// of check-ins, each carrying a ~7-day trend weight and both the
  /// since-start and short-term (vs previous check-in) rates. Returns an
  /// empty list if there are no weigh-ins on/after the plan start date.
  static List<_CheckIn> _computeCheckIns(
      WeightGoalPlan plan, List<BodyweightEntry> weighIns) {
    final sincePlan = weighIns
        .where((w) => !w.date.isBefore(plan.startDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (sincePlan.isEmpty) return const [];

    final checkIns = <_CheckIn>[];
    var prevTrend = plan.startWeightKg;
    var prevDate = plan.startDate;

    for (var i = 0; i < sincePlan.length; i++) {
      final date = sincePlan[i].date;
      final windowStart = date.subtract(const Duration(days: 7));
      final window = sincePlan
          .sublist(0, i + 1)
          .where((w) => !w.date.isBefore(windowStart))
          .toList();
      final trendWeight =
          window.map((w) => w.weightKg).reduce((a, b) => a + b) /
              window.length;

      final elapsedWeeks = _weeksBetween(plan.startDate, date);
      final actualRate = _progressMagnitude(
              plan.goalDirection, plan.startWeightKg, trendWeight) /
          elapsedWeeks;

      final shortTermWeeks = _weeksBetween(prevDate, date);
      final shortTermRate =
          _progressMagnitude(plan.goalDirection, prevTrend, trendWeight) /
              shortTermWeeks;

      checkIns.add(_CheckIn(
        date: date,
        trendWeightKg: trendWeight,
        isProvisional: i == 0,
        elapsedWeeks: elapsedWeeks,
        actualRateKgPerWeek: actualRate,
        shortTermRateKgPerWeek: shortTermRate,
      ));

      prevTrend = trendWeight;
      prevDate = date;
    }
    return checkIns;
  }

  /// Classifies a single check-in's raw off-track direction (before the
  /// two-consecutive confirmation rule is applied). Returns null for
  /// on-track.
  static String? _rawDirection(
      WeightGoalPlan plan, double plannedRate, double tolerance, double actualRate) {
    final diff = actualRate - plannedRate;
    if (diff < -tolerance) return 'behind';
    if (diff > tolerance) {
      final level = paceWarningFor(plan.goalDirection, actualRate.abs());
      if (level == 'danger') return 'unsafe';
      if (level == 'warn') return 'tooFast';
      return 'ahead';
    }
    return null; // on track
  }

  // ── Public evaluation entry point ───────────────────────────────────────

  /// Evaluates the current coaching status for [plan] against the full
  /// history of [weighIns] (any order — sorted internally). [now] defaults
  /// to [DateTime.now] and only affects the projected/expected-today figure
  /// when there are no weigh-ins yet.
  static WeightGoalProgress evaluate({
    required WeightGoalPlan? plan,
    required List<BodyweightEntry> weighIns,
    DateTime? now,
  }) {
    if (plan == null) return WeightGoalProgress.noPlan;
    final today = now ?? DateTime.now();

    final checkIns = _computeCheckIns(plan, weighIns);
    final weeksRemaining =
        max(plan.targetDate.difference(today).inHours / (24.0 * 7.0), 0.0);

    // No / single reading → provisional "building trend" state (FR-016).
    if (checkIns.length < 2) {
      final trend =
          checkIns.isNotEmpty ? checkIns.last.trendWeightKg : plan.startWeightKg;
      final macros = macrosFor(plan, weightKgForCalc: trend);
      return WeightGoalProgress(
        verdict: WeightGoalVerdict.buildingTrend,
        message: checkIns.isEmpty
            ? 'Log your first weigh-in to start tracking progress toward your goal.'
            : 'One scale reading can be noisy — log a couple more weigh-ins to '
                'see a reliable trend.',
        isProvisional: true,
        trendWeightKg: trend,
        expectedWeightTodayKg: _expectedWeightAt(plan, today),
        dailyCalories: macros.dailyCalories,
        proteinG: macros.proteinG,
        fatG: macros.fatG,
        carbsG: macros.carbsG,
        weeksRemaining: weeksRemaining,
        progressFraction: _progressFraction(plan, trend),
        chartPoints: _chartPoints(plan, weighIns, today),
      );
    }

    final current = checkIns.last;
    final previous = checkIns[checkIns.length - 2];
    final macros = macrosFor(plan, weightKgForCalc: current.trendWeightKg);
    final expectedToday = _expectedWeightAt(plan, today);
    final progressFraction = _progressFraction(plan, current.trendWeightKg);
    final chartPoints = _chartPoints(plan, weighIns, today);

    // ── Goal reached (FR-024) — checked before pace classification ────────
    if (!plan.isMaintenance) {
      final band = max(0.3, plan.targetWeightKg * 0.005);
      if ((current.trendWeightKg - plan.targetWeightKg).abs() <= band) {
        return WeightGoalProgress(
          verdict: WeightGoalVerdict.goalReached,
          message: "You've reached your goal weight! Consider switching to "
              'maintenance to keep your calorie and macro targets accurate.',
          trendWeightKg: current.trendWeightKg,
          expectedWeightTodayKg: expectedToday,
          dailyCalories: macros.dailyCalories,
          proteinG: macros.proteinG,
          fatG: macros.fatG,
          carbsG: macros.carbsG,
          weeksRemaining: weeksRemaining,
          progressFraction: progressFraction,
          chartPoints: chartPoints,
        );
      }
    }

    // ── Maintenance band (FR-019) ──────────────────────────────────────────
    if (plan.isMaintenance) {
      final band = max(0.5, current.trendWeightKg * 0.01);
      final diff = current.trendWeightKg - plan.startWeightKg;
      if (diff.abs() <= band) {
        return WeightGoalProgress(
          verdict: WeightGoalVerdict.maintenanceOnTrack,
          message: 'Your weight is stable — right where you want it. No '
              'change needed.',
          trendWeightKg: current.trendWeightKg,
          expectedWeightTodayKg: expectedToday,
          plannedRateKgPerWeek: 0,
          actualRateKgPerWeek: 0,
          dailyCalories: macros.dailyCalories,
          proteinG: macros.proteinG,
          fatG: macros.fatG,
          carbsG: macros.carbsG,
          weeksRemaining: weeksRemaining,
          progressFraction: progressFraction,
          chartPoints: chartPoints,
        );
      }
      // Drifted outside the maintenance band: reuse the behind/ahead
      // vocabulary (drifted down = eat more, drifted up = eat less), with
      // the same two-consecutive-check-in confirmation rule.
      final direction = diff < 0 ? 'behind' : 'ahead';
      final prevDiff = previous.trendWeightKg - plan.startWeightKg;
      final prevDirection = prevDiff.abs() <= band
          ? null
          : (prevDiff < 0 ? 'behind' : 'ahead');
      final confirmed = prevDirection == direction;
      final delta = direction == 'behind' ? 100 : -100;
      return WeightGoalProgress(
        verdict:
            direction == 'behind' ? WeightGoalVerdict.behind : WeightGoalVerdict.ahead,
        message: direction == 'behind'
            ? (confirmed
                ? "You've drifted below your maintenance range — try eating "
                    'about 100 kcal/day more.'
                : "You're a little below your maintenance range. Keep an eye "
                    'on it at your next weigh-in.')
            : (confirmed
                ? "You've drifted above your maintenance range — try eating "
                    'about 100 kcal/day less.'
                : "You're a little above your maintenance range. Keep an eye "
                    'on it at your next weigh-in.'),
        isConfirmed: confirmed,
        suggestedKcalDelta: delta,
        trendWeightKg: current.trendWeightKg,
        expectedWeightTodayKg: expectedToday,
        plannedRateKgPerWeek: 0,
        actualRateKgPerWeek: current.actualRateKgPerWeek,
        dailyCalories: macros.dailyCalories,
        proteinG: macros.proteinG,
        fatG: macros.fatG,
        carbsG: macros.carbsG,
        weeksRemaining: weeksRemaining,
        progressFraction: progressFraction,
        chartPoints: chartPoints,
      );
    }

    // ── Plateau (FR-023) — flat short-term trend for ~2 consecutive check-ins ─
    if (current.shortTermRateKgPerWeek.abs() < 0.10 &&
        previous.shortTermRateKgPerWeek.abs() < 0.10) {
      return WeightGoalProgress(
        verdict: WeightGoalVerdict.plateau,
        message: 'Your trend has been flat for a couple of check-ins. '
            'Consider adjusting your calories or extending your target date.',
        trendWeightKg: current.trendWeightKg,
        expectedWeightTodayKg: expectedToday,
        plannedRateKgPerWeek: plan.requiredWeeklyRateKg,
        actualRateKgPerWeek: current.actualRateKgPerWeek,
        toleranceKgPerWeek: toleranceKgPerWeek(plan.requiredWeeklyRateKg),
        dailyCalories: macros.dailyCalories,
        proteinG: macros.proteinG,
        fatG: macros.fatG,
        carbsG: macros.carbsG,
        weeksRemaining: weeksRemaining,
        progressFraction: progressFraction,
        chartPoints: chartPoints,
      );
    }

    // ── Rate-based classification (FR-017 / FR-018) ────────────────────────
    final plannedRate = plan.requiredWeeklyRateKg;
    final tolerance = toleranceKgPerWeek(plannedRate);
    final rawDirection =
        _rawDirection(plan, plannedRate, tolerance, current.actualRateKgPerWeek);

    if (rawDirection == null) {
      return WeightGoalProgress(
        verdict: WeightGoalVerdict.onTrack,
        message: "You're on track — no calorie change needed.",
        trendWeightKg: current.trendWeightKg,
        expectedWeightTodayKg: expectedToday,
        plannedRateKgPerWeek: plannedRate,
        actualRateKgPerWeek: current.actualRateKgPerWeek,
        toleranceKgPerWeek: tolerance,
        dailyCalories: macros.dailyCalories,
        proteinG: macros.proteinG,
        fatG: macros.fatG,
        carbsG: macros.carbsG,
        weeksRemaining: weeksRemaining,
        progressFraction: progressFraction,
        chartPoints: chartPoints,
      );
    }

    final prevRawDirection =
        _rawDirection(plan, plannedRate, tolerance, previous.actualRateKgPerWeek);
    // "unsafe" is urgent enough to surface immediately rather than waiting
    // for a second check-in — it's guidance only (FR-025), never an
    // automatic plan change.
    final confirmed = rawDirection == 'unsafe' || prevRawDirection == rawDirection;

    final isBuild = plan.goalDirection == 'build';
    int delta;
    String message;
    WeightGoalVerdict verdict;
    switch (rawDirection) {
      case 'behind':
        verdict = WeightGoalVerdict.behind;
        delta = isBuild ? 150 : -150;
        message = confirmed
            ? "You're behind pace — try eating about ${delta.abs()} kcal/day "
                '${isBuild ? 'more' : 'less'} to get back on track.'
            : "You're a little behind pace this check-in. If it continues "
                'next time, try eating about ${delta.abs()} kcal/day '
                '${isBuild ? 'more' : 'less'}.';
        break;
      case 'ahead':
        verdict = WeightGoalVerdict.ahead;
        delta = isBuild ? -100 : 100;
        message = confirmed
            ? "You're ahead of pace — try eating about ${delta.abs()} kcal/day "
                '${isBuild ? 'less' : 'more'} to settle back onto plan.'
            : "You're a little ahead of pace this check-in. If it continues "
                'next time, try eating about ${delta.abs()} kcal/day '
                '${isBuild ? 'less' : 'more'}.';
        break;
      case 'tooFast':
        verdict = WeightGoalVerdict.tooFast;
        delta = isBuild ? -100 : 100;
        message = confirmed
            ? "You're gaining/losing faster than is comfortable — try eating "
                'about ${delta.abs()} kcal/day ${isBuild ? 'less' : 'more'}.'
            : 'This check-in came in faster than planned. Keep an eye on it — '
                'if it continues, try eating about ${delta.abs()} kcal/day '
                '${isBuild ? 'less' : 'more'}.';
        break;
      case 'unsafe':
      default:
        verdict = WeightGoalVerdict.unsafe;
        delta = isBuild ? -100 : 100;
        message = 'Your pace has moved into an unsafe range — try eating '
            'about ${delta.abs()} kcal/day ${isBuild ? 'less' : 'more'}, or '
            'extend your target date.';
        break;
    }

    return WeightGoalProgress(
      verdict: verdict,
      message: message,
      isConfirmed: confirmed,
      suggestedKcalDelta: delta,
      trendWeightKg: current.trendWeightKg,
      expectedWeightTodayKg: expectedToday,
      plannedRateKgPerWeek: plannedRate,
      actualRateKgPerWeek: current.actualRateKgPerWeek,
      toleranceKgPerWeek: tolerance,
      dailyCalories: macros.dailyCalories,
      proteinG: macros.proteinG,
      fatG: macros.fatG,
      carbsG: macros.carbsG,
      weeksRemaining: weeksRemaining,
      progressFraction: progressFraction,
      chartPoints: chartPoints,
    );
  }

  // ── Chart / expected-weight helpers ─────────────────────────────────────

  static double _expectedWeightAt(WeightGoalPlan plan, DateTime date) {
    if (plan.isMaintenance) return plan.startWeightKg;
    final elapsedWeeks = _weeksBetween(plan.startDate, date);
    final signed = plan.goalDirection == 'build'
        ? plan.requiredWeeklyRateKg
        : -plan.requiredWeeklyRateKg;
    final clampedWeeks =
        min(elapsedWeeks, plan.targetDate.difference(plan.startDate).inHours / 168.0);
    return plan.startWeightKg + signed * clampedWeeks;
  }

  static double? _progressFraction(WeightGoalPlan plan, double trendWeightKg) {
    if (plan.isMaintenance) return null;
    final totalDistance = (plan.targetWeightKg - plan.startWeightKg).abs();
    if (totalDistance < 0.01) return null;
    final covered = plan.goalDirection == 'build'
        ? trendWeightKg - plan.startWeightKg
        : plan.startWeightKg - trendWeightKg;
    return (covered / totalDistance).clamp(0.0, 1.0);
  }

  /// Builds the actual-vs-projected series for the trend chart: the
  /// projected goal line spans plan start → target date; actual points are
  /// the logged weigh-ins on/after the plan start.
  ///
  /// Points that fall on the same calendar day are collapsed to one (see
  /// [_collapseSameDay]) — this matters most right after goal setup, when
  /// the user's "current weight" is stored both as [WeightGoalPlan.startWeightKg]
  /// and as a bodyweight entry dated today, which would otherwise render as
  /// two points on the same day.
  static List<WeightChartPoint> _chartPoints(
      WeightGoalPlan plan, List<BodyweightEntry> weighIns, DateTime today) {
    final actual = weighIns
        .where((w) => !w.date.isBefore(plan.startDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final raw = <_RawChartPoint>[
      _RawChartPoint(
        point: WeightChartPoint(
          date: plan.startDate,
          actualKg: plan.startWeightKg,
          projectedKg: plan.startWeightKg,
        ),
        isSynthetic: true,
      ),
    ];
    for (final entry in actual) {
      raw.add(_RawChartPoint(
        point: WeightChartPoint(
          date: entry.date,
          actualKg: entry.weightKg,
          projectedKg: _expectedWeightAt(plan, entry.date),
        ),
        isSynthetic: false,
      ));
    }

    final points = _collapseSameDay(raw);

    // Extend the projected line to the target date even without a weigh-in
    // logged there yet.
    if (plan.targetDate.isAfter(points.last.date)) {
      points.add(WeightChartPoint(
        date: plan.targetDate,
        actualKg: null,
        projectedKg: _expectedWeightAt(plan, plan.targetDate),
      ));
    }
    return points;
  }

  /// Collapses chart points that share a calendar day (ignoring time-of-day)
  /// into a single point. A logged weigh-in always wins over the synthetic
  /// plan-start point; when several real weigh-ins land on the same day,
  /// the last one (chronologically) wins.
  static List<WeightChartPoint> _collapseSameDay(List<_RawChartPoint> raw) {
    final collapsed = <_RawChartPoint>[];
    for (final entry in raw) {
      final idx =
          collapsed.indexWhere((c) => _isSameDay(c.point.date, entry.point.date));
      if (idx == -1) {
        collapsed.add(entry);
        continue;
      }
      final existing = collapsed[idx];
      if (!(existing.isSynthetic == false && entry.isSynthetic == true)) {
        collapsed[idx] = entry;
      }
    }
    return collapsed.map((c) => c.point).toList();
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Internal helper pairing a [WeightChartPoint] with whether it was the
/// synthetic plan-start point (as opposed to a real logged weigh-in), used
/// only while collapsing same-day points in [_chartPoints].
class _RawChartPoint {
  final WeightChartPoint point;
  final bool isSynthetic;
  const _RawChartPoint({required this.point, required this.isSynthetic});
}
