import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/weight_goal_plan.dart';
import '../services/notification_service.dart';
import '../utils/weight_goal_calculations.dart';
import 'database_provider.dart';
import 'home_providers.dart';
import 'user_profile_provider.dart';

/// Derives the active weight goal plan from the user's profile row. Null
/// when goal setup was never completed (FR-003 empty state).
final weightGoalPlanProvider = Provider<WeightGoalPlan?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return WeightGoalPlan.fromProfile(profile);
});

/// Full coaching evaluation — trend, on-track status, guidance, calories
/// and macros — for the active plan against all logged weigh-ins.
final weightGoalProgressProvider = Provider<WeightGoalProgress>((ref) {
  final plan = ref.watch(weightGoalPlanProvider);
  final weighIns = ref.watch(allBodyweightsProvider).valueOrNull ?? const [];
  return WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
});

/// Next weigh-in due date, derived from the plan's cadence anchored at the
/// latest logged weigh-in since plan start (or the plan start date itself
/// if nothing has been logged yet).
class NextWeighInDue {
  final DateTime? dueDate;
  final bool overdue;

  /// Whole days until [dueDate]; negative when overdue. Null with no plan.
  final int? daysRemaining;

  const NextWeighInDue({this.dueDate, this.overdue = false, this.daysRemaining});
}

final nextWeighInDueProvider = Provider<NextWeighInDue>((ref) {
  final plan = ref.watch(weightGoalPlanProvider);
  if (plan == null) return const NextWeighInDue();

  final weighIns = ref.watch(allBodyweightsProvider).valueOrNull ?? const [];
  final sincePlan = weighIns
      .where((w) => !w.date.isBefore(plan.startDate))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  final anchor = sincePlan.isNotEmpty ? sincePlan.first.date : plan.startDate;
  final due = anchor.add(Duration(days: plan.weighInIntervalDays));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final daysRemaining = dueDay.difference(today).inDays;

  return NextWeighInDue(
    dueDate: due,
    overdue: due.isBefore(now),
    daysRemaining: daysRemaining,
  );
});

/// Compact view-model for the home-screen tile (FR-027 – FR-030).
class WeightGoalHomeViewModel {
  final bool hasPlan;
  final WeightGoalVerdict verdict;
  final double? latestWeightKg;
  final double? trendWeightKg;
  final String statusMessage;
  final int? daysUntilNextWeighIn;
  final bool weighInOverdue;
  final double? todayCalories;
  final List<WeightChartPoint> sparkline;

  const WeightGoalHomeViewModel({
    required this.hasPlan,
    required this.verdict,
    this.latestWeightKg,
    this.trendWeightKg,
    required this.statusMessage,
    this.daysUntilNextWeighIn,
    this.weighInOverdue = false,
    this.todayCalories,
    this.sparkline = const [],
  });
}

final weightGoalHomeViewModelProvider = Provider<WeightGoalHomeViewModel>((ref) {
  final plan = ref.watch(weightGoalPlanProvider);
  if (plan == null) {
    return const WeightGoalHomeViewModel(
      hasPlan: false,
      verdict: WeightGoalVerdict.noPlan,
      statusMessage: 'Set a weight goal',
    );
  }

  final progress = ref.watch(weightGoalProgressProvider);
  final due = ref.watch(nextWeighInDueProvider);
  final weighIns = ref.watch(allBodyweightsProvider).valueOrNull ?? const [];
  final latest = weighIns.isNotEmpty
      ? (weighIns.toList()..sort((a, b) => b.date.compareTo(a.date))).first
      : null;

  return WeightGoalHomeViewModel(
    hasPlan: true,
    verdict: progress.verdict,
    latestWeightKg: latest?.weightKg,
    trendWeightKg: progress.trendWeightKg,
    statusMessage: progress.message,
    daysUntilNextWeighIn: due.daysRemaining,
    weighInOverdue: due.overdue,
    todayCalories: progress.dailyCalories,
    sparkline: progress.chartPoints,
  );
});

/// Side-effecting actions for the Weight Hub: persist plan/weigh-in changes
/// and keep the weigh-in reminder notification rolling forward. Never
/// mutates coaching-derived fields automatically (FR-025) — only what the
/// user explicitly submits via these methods.
class WeightGoalActions {
  final Ref ref;
  const WeightGoalActions(this.ref);

  AppDatabase get _db => ref.read(databaseProvider);

  /// Saves (creates or edits) the active goal plan and reschedules the
  /// weigh-in reminder to match the new cadence. Only touches plan-related
  /// profile columns — the rest of the profile (name, height, etc.) is left
  /// untouched.
  Future<void> savePlan({
    required String goalDirection,
    required DateTime startDate,
    required double startWeightKg,
    required double targetWeightKg,
    required DateTime targetDate,
    required int weighInIntervalDays,
    required bool remindersEnabled,
  }) async {
    final weeklyRate = WeightGoalPlan(
      goalDirection: goalDirection,
      startDate: startDate,
      startWeightKg: startWeightKg,
      targetWeightKg: targetWeightKg,
      targetDate: targetDate,
      weighInIntervalDays: weighInIntervalDays,
      remindersEnabled: remindersEnabled,
      gender: 'male', // unused by requiredWeeklyRateKg
      age: 0,
      heightCm: 0,
      activityLevel: 'moderate',
    ).requiredWeeklyRateKg;

    await _db.userProfileDao.upsertProfile(
      UserProfilesCompanion(
        fitnessGoal: Value(goalDirection),
        targetWeightKg: Value(targetWeightKg),
        weeklyRateKg: Value(weeklyRate),
        planStartDate: Value(startDate),
        planStartWeightKg: Value(startWeightKg),
        planTargetDate: Value(targetDate),
        weighInIntervalDays: Value(weighInIntervalDays),
        weighInRemindersEnabled: Value(remindersEnabled),
      ),
    );
    await rescheduleReminder();
  }

  /// Logs a new weigh-in and rolls the reminder forward.
  Future<void> logWeighIn({
    required double weightKg,
    required DateTime date,
    String? notes,
  }) async {
    await _db.bodyweightDao.insertBodyweight(
      BodyweightEntriesCompanion(
        date: Value(date),
        weightKg: Value(weightKg),
        notes: Value(notes),
      ),
    );
    await rescheduleReminder();
  }

  /// Deletes a weigh-in and rolls the reminder forward (its anchor may
  /// change if the deleted entry was the latest one).
  Future<void> deleteWeighIn(int id) async {
    await _db.bodyweightDao.deleteBodyweight(id);
    await rescheduleReminder();
  }

  /// Switches an active plan to maintenance at the given reference weight
  /// (offered after Goal Reached, FR-024). Requires explicit user consent
  /// to call — never invoked automatically.
  Future<void> switchToMaintenance({required double atWeightKg}) async {
    final profile = await _db.userProfileDao.getProfile();
    if (profile == null) return;
    await savePlan(
      goalDirection: 'maintain',
      startDate: DateTime.now(),
      startWeightKg: atWeightKg,
      targetWeightKg: atWeightKg,
      targetDate: DateTime.now().add(const Duration(days: 84)),
      weighInIntervalDays: profile.weighInIntervalDays ?? 7,
      remindersEnabled: profile.weighInRemindersEnabled ?? true,
    );
  }

  /// Recomputes and reschedules the next weigh-in reminder (or cancels it
  /// when there's no active plan or reminders are disabled). Call after
  /// every weigh-in insert/delete, plan save/edit, and once at app start.
  Future<void> rescheduleReminder() async {
    final profile = await _db.userProfileDao.getProfile();
    final plan = WeightGoalPlan.fromProfile(profile);
    if (plan == null || !plan.remindersEnabled) {
      await NotificationService.cancelWeighInReminder();
      return;
    }

    final weighIns = await _db.bodyweightDao.getRecentBodyweights(30);
    final sincePlan = weighIns
        .where((w) => !w.date.isBefore(plan.startDate))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final anchor = sincePlan.isNotEmpty ? sincePlan.first.date : plan.startDate;

    await NotificationService.scheduleNextWeighInReminder(
      anchorDate: anchor,
      intervalDays: plan.weighInIntervalDays,
    );
  }
}

final weightGoalActionsProvider = Provider<WeightGoalActions>((ref) {
  return WeightGoalActions(ref);
});
