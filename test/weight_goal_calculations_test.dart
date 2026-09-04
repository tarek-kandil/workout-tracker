import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/weight_goal_plan.dart';
import 'package:workout_tracker/utils/weight_goal_calculations.dart';

BodyweightEntry _entry(int id, DateTime date, double kg) =>
    BodyweightEntry(id: id, date: date, weightKg: kg);

WeightGoalPlan _lossPlan({
  required DateTime start,
  required double startWeightKg,
  required double targetWeightKg,
  required int durationWeeks,
}) {
  return WeightGoalPlan(
    goalDirection: 'lose',
    startDate: start,
    startWeightKg: startWeightKg,
    targetWeightKg: targetWeightKg,
    targetDate: start.add(Duration(days: durationWeeks * 7)),
    weighInIntervalDays: 7,
    remindersEnabled: true,
    gender: 'female',
    age: 30,
    heightCm: 170,
    activityLevel: 'moderate',
  );
}

WeightGoalPlan _buildPlan({
  required DateTime start,
  required double startWeightKg,
  required double targetWeightKg,
  required int durationWeeks,
}) {
  return WeightGoalPlan(
    goalDirection: 'build',
    startDate: start,
    startWeightKg: startWeightKg,
    targetWeightKg: targetWeightKg,
    targetDate: start.add(Duration(days: durationWeeks * 7)),
    weighInIntervalDays: 7,
    remindersEnabled: true,
    gender: 'male',
    age: 25,
    heightCm: 180,
    activityLevel: 'moderate',
  );
}

void main() {
  final start = DateTime(2026, 1, 1);

  group('WeightGoalPlan', () {
    test('requiredWeeklyRateKg derives from start/target weight and duration', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      expect(plan.requiredWeeklyRateKg, closeTo(0.5, 1e-9));
    });

    test('isMaintenance true when desired == current weight (FR-013)', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 80, durationWeeks: 8);
      expect(plan.isMaintenance, isTrue);
      expect(plan.requiredWeeklyRateKg, 0);
    });
  });

  group('pace guardrails', () {
    test('lose: warn above 0.5, danger at/above 1.0', () {
      expect(WeightGoalCalculations.paceWarningFor('lose', 0.4), isNull);
      expect(WeightGoalCalculations.paceWarningFor('lose', 0.5), isNull);
      expect(WeightGoalCalculations.paceWarningFor('lose', 0.6), 'warn');
      expect(WeightGoalCalculations.paceWarningFor('lose', 0.99), 'warn');
      expect(WeightGoalCalculations.paceWarningFor('lose', 1.0), 'danger');
      expect(WeightGoalCalculations.paceWarningFor('lose', 1.5), 'danger');
    });

    test('build: warn above 0.25, danger at/above 0.75', () {
      expect(WeightGoalCalculations.paceWarningFor('build', 0.2), isNull);
      expect(WeightGoalCalculations.paceWarningFor('build', 0.25), isNull);
      expect(WeightGoalCalculations.paceWarningFor('build', 0.3), 'warn');
      expect(WeightGoalCalculations.paceWarningFor('build', 0.74), 'warn');
      expect(WeightGoalCalculations.paceWarningFor('build', 0.75), 'danger');
    });
  });

  group('tolerance band', () {
    test('clamped between 0.10 and 0.25, else 50% of planned rate', () {
      expect(WeightGoalCalculations.toleranceKgPerWeek(0.1), closeTo(0.10, 1e-9));
      expect(WeightGoalCalculations.toleranceKgPerWeek(0.5), closeTo(0.25, 1e-9));
      expect(WeightGoalCalculations.toleranceKgPerWeek(0.3), closeTo(0.15, 1e-9));
      expect(WeightGoalCalculations.toleranceKgPerWeek(0.05), closeTo(0.10, 1e-9));
    });
  });

  group('provisional / buildingTrend (FR-016)', () {
    test('zero weigh-ins yields buildingTrend, no confirmed suggestion', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: []);
      expect(result.verdict, WeightGoalVerdict.buildingTrend);
      expect(result.isProvisional, isTrue);
      expect(result.suggestedKcalDelta, isNull);
    });

    test('single weigh-in yields buildingTrend', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final result = WeightGoalCalculations.evaluate(
        plan: plan,
        weighIns: [_entry(1, start.add(const Duration(days: 3)), 79.5)],
      );
      expect(result.verdict, WeightGoalVerdict.buildingTrend);
      expect(result.isProvisional, isTrue);
    });
  });

  group('lose goal classification', () {
    test('on track: actual rate close to planned 0.5 kg/wk', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      // 4 weeks in, lost 2kg => 0.5 kg/wk actual, matches planned exactly.
      final weighIns = [
        _entry(1, start.add(const Duration(days: 7)), 79.5),
        _entry(2, start.add(const Duration(days: 14)), 79.0),
        _entry(3, start.add(const Duration(days: 21)), 78.5),
        _entry(4, start.add(const Duration(days: 28)), 78.0),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.onTrack);
      expect(result.suggestedKcalDelta, isNull);
    });

    test('behind pace shows unconfirmed guidance on first off-track check-in', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      // 14-day spacing avoids 7-day trend-window overlap between check-ins.
      // Check-in 1 (2wk): on pace (0.5 kg/wk). Check-in 2 (4wk): overall
      // pace drops to 0.1 kg/wk -> behind, but the *previous* check-in was
      // on track, so the suggestion is not yet confirmed.
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 79.0), // on track
        _entry(2, start.add(const Duration(days: 28)), 79.6), // behind
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.behind);
      expect(result.suggestedKcalDelta, -150);
      expect(result.isConfirmed, isFalse);
    });

    test('behind pace confirms suggestion after two consecutive check-ins', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 7)), 79.8), // behind
        _entry(2, start.add(const Duration(days: 14)), 79.7), // behind again
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.behind);
      expect(result.suggestedKcalDelta, -150);
      expect(result.isConfirmed, isTrue);
    });

    test('ahead of pace (safe) suggests +100 kcal once confirmed', () {
      // Planned pace is deliberately low (0.2 kg/wk) so a moderately faster
      // actual pace (0.4 kg/wk) stays under the 0.5 kg/wk warn threshold —
      // i.e. genuinely "ahead" rather than "too fast".
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 20);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 79.2), // 0.4 kg/wk
        _entry(2, start.add(const Duration(days: 28)), 78.4), // 0.4 kg/wk
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.ahead);
      expect(result.suggestedKcalDelta, 100);
      expect(result.isConfirmed, isTrue);
    });

    test('too fast when actual pace itself enters the warn zone', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      // Planned 0.5 kg/wk; losing ~0.85 kg/wk consistently (warn zone: >0.5,
      // <1.0 danger threshold).
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 78.3),
        _entry(2, start.add(const Duration(days: 28)), 76.6),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.tooFast);
      expect(result.suggestedKcalDelta, 100);
    });

    test('unsafe when actual pace enters the danger zone, confirmed immediately', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 79.0), // on track
        _entry(2, start.add(const Duration(days: 28)), 75.5), // 1.125 kg/wk since start
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.unsafe);
      expect(result.isConfirmed, isTrue); // urgent — no need to wait
      expect(result.suggestedKcalDelta, 100);
    });
  });

  group('build goal classification', () {
    test('on track: actual rate close to planned 0.25 kg/wk', () {
      final plan = _buildPlan(
          start: start, startWeightKg: 70, targetWeightKg: 74, durationWeeks: 16);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 7)), 70.25),
        _entry(2, start.add(const Duration(days: 14)), 70.5),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.onTrack);
    });

    test('behind pace (barely gaining) confirms -> +150 kcal/day suggestion', () {
      final plan = _buildPlan(
          start: start, startWeightKg: 70, targetWeightKg: 74, durationWeeks: 16);
      // 14-day spacing; overall pace stays well under the planned 0.25
      // kg/wk on both check-ins, and the recent (short-term) rate is high
      // enough (0.125 kg/wk) to avoid tripping the plateau check.
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 70.05),
        _entry(2, start.add(const Duration(days: 28)), 70.30),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.behind);
      expect(result.suggestedKcalDelta, 150);
      expect(result.isConfirmed, isTrue);
    });

    test('ahead of pace (gaining faster) confirms -> -100 kcal/day suggestion', () {
      // Planned pace is deliberately low (0.05 kg/wk) so a moderately
      // faster actual pace (0.2 kg/wk) stays under the 0.25 kg/wk warn
      // threshold for build goals — genuinely "ahead", not "too fast".
      // Target is set far from start so this scenario doesn't accidentally
      // land in the goal-reached band.
      final plan = _buildPlan(
          start: start, startWeightKg: 70, targetWeightKg: 76, durationWeeks: 120);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 70.4),
        _entry(2, start.add(const Duration(days: 28)), 70.8),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.ahead);
      expect(result.suggestedKcalDelta, -100);
      expect(result.isConfirmed, isTrue);
    });
  });

  group('plateau (FR-023)', () {
    test('flat short-term trend for two consecutive check-ins triggers plateau', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      // Good initial progress, then the last two check-ins barely move
      // (<0.10 kg/wk between them) -> plateau, regardless of the overall
      // since-start average.
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 78.5),
        _entry(2, start.add(const Duration(days: 28)), 78.45),
        _entry(3, start.add(const Duration(days: 42)), 78.40),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.plateau);
    });
  });

  group('maintenance band (FR-019)', () {
    test('within ±max(0.5kg, 1%) of reference weight -> maintenanceOnTrack', () {
      final plan = WeightGoalPlan(
        goalDirection: 'maintain',
        startDate: start,
        startWeightKg: 75,
        targetWeightKg: 75,
        targetDate: start.add(const Duration(days: 84)),
        weighInIntervalDays: 7,
        remindersEnabled: true,
        gender: 'male',
        age: 40,
        heightCm: 175,
        activityLevel: 'moderate',
      );
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 75.2),
        _entry(2, start.add(const Duration(days: 28)), 74.8),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.maintenanceOnTrack);
    });

    test('drifted outside maintenance band -> behind (eat more), unconfirmed first time', () {
      final plan = WeightGoalPlan(
        goalDirection: 'maintain',
        startDate: start,
        startWeightKg: 75,
        targetWeightKg: 75,
        targetDate: start.add(const Duration(days: 84)),
        weighInIntervalDays: 7,
        remindersEnabled: true,
        gender: 'male',
        age: 40,
        heightCm: 175,
        activityLevel: 'moderate',
      );
      final weighIns = [
        _entry(1, start.add(const Duration(days: 14)), 75.1), // in-band
        _entry(2, start.add(const Duration(days: 28)), 74.0), // drifted low
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.behind);
      expect(result.isConfirmed, isFalse);
      expect(result.suggestedKcalDelta, 100);
    });
  });

  group('goal reached (FR-024)', () {
    test('trend within target band celebrates goal reached', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 72, durationWeeks: 16);
      final weighIns = [
        _entry(1, start.add(const Duration(days: 98)), 72.5),
        _entry(2, start.add(const Duration(days: 105)), 72.1),
      ];
      final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
      expect(result.verdict, WeightGoalVerdict.goalReached);
    });
  });

  group('macros', () {
    test('lose pace > 0.5 kg/wk bumps protein to 2.0 g/kg', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 68, durationWeeks: 12); // 1.0 kg/wk
      final macros = WeightGoalCalculations.macrosFor(plan, weightKgForCalc: 80);
      expect(macros.proteinG, closeTo(80 * 2.0, 1e-9));
    });

    test('lose pace <= 0.5 kg/wk keeps protein at 1.8 g/kg', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8); // 0.5 kg/wk
      final macros = WeightGoalCalculations.macrosFor(plan, weightKgForCalc: 80);
      expect(macros.proteinG, closeTo(80 * 1.8, 1e-9));
    });

    test('build goal always uses 2.0 g/kg protein', () {
      final plan = _buildPlan(
          start: start, startWeightKg: 70, targetWeightKg: 72, durationWeeks: 16);
      final macros = WeightGoalCalculations.macrosFor(plan, weightKgForCalc: 70);
      expect(macros.proteinG, closeTo(70 * 2.0, 1e-9));
    });

    test('carbs are the remainder after protein and fat calories', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final macros = WeightGoalCalculations.macrosFor(plan, weightKgForCalc: 80);
      final total = macros.proteinG * 4 + macros.fatG * 9 + macros.carbsG * 4;
      expect(total, closeTo(macros.dailyCalories, 1.0));
    });
  });

  group('chart points (same-day dedupe)', () {
    test(
        'weigh-in logged on plan.startDate collapses into ONE point with '
        'the weigh-in\'s actual value (goal-setup double-point bug)', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final result = WeightGoalCalculations.evaluate(
        plan: plan,
        weighIns: [_entry(1, start, 79.8)],
        now: start,
      );
      final startDayPoints =
          result.chartPoints.where((p) => _isSameDay(p.date, start)).toList();
      expect(startDayPoints, hasLength(1));
      expect(startDayPoints.single.actualKg, closeTo(79.8, 1e-9));
    });

    test('multiple weigh-ins on the same later day collapse to one (last wins)', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final laterDay = start.add(const Duration(days: 5));
      final result = WeightGoalCalculations.evaluate(
        plan: plan,
        weighIns: [
          _entry(1, laterDay.add(const Duration(hours: 7)), 79.0),
          _entry(2, laterDay.add(const Duration(hours: 20)), 78.5),
        ],
        now: laterDay,
      );
      final dayPoints =
          result.chartPoints.where((p) => _isSameDay(p.date, laterDay)).toList();
      expect(dayPoints, hasLength(1));
      expect(dayPoints.single.actualKg, closeTo(78.5, 1e-9));
    });

    test('weigh-ins on distinct days are preserved in order, target point appended', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final day3 = start.add(const Duration(days: 3));
      final day7 = start.add(const Duration(days: 7));
      final result = WeightGoalCalculations.evaluate(
        plan: plan,
        weighIns: [_entry(1, day3, 79.5), _entry(2, day7, 79.0)],
        now: day7,
      );
      final dates = result.chartPoints.map((p) => p.date).toList();
      expect(dates.length, 4); // start, day3, day7, target
      expect(_isSameDay(dates[0], start), isTrue);
      expect(_isSameDay(dates[1], day3), isTrue);
      expect(_isSameDay(dates[2], day7), isTrue);
      expect(_isSameDay(dates[3], plan.targetDate), isTrue);
    });

    test('zero weigh-ins yields just [start, target]', () {
      final plan = _lossPlan(
          start: start, startWeightKg: 80, targetWeightKg: 76, durationWeeks: 8);
      final result =
          WeightGoalCalculations.evaluate(plan: plan, weighIns: [], now: start);
      expect(result.chartPoints, hasLength(2));
      expect(_isSameDay(result.chartPoints.first.date, start), isTrue);
      expect(
          _isSameDay(result.chartPoints.last.date, plan.targetDate), isTrue);
    });
  });
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
