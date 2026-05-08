# Weekly Progression Home Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Weekly Progress card (tonnage + sparkline + stats strip + muscle balance bars) and a conditional PR card to the home screen.

**Architecture:** Four new DAO query methods on `SetsDao` feed two new Riverpod `FutureProvider`s in `home_providers.dart`. Two new `ConsumerWidget`s render the data using `LiquidGlassContainer` matching the existing glass aesthetic. Both are wired into `home_screen.dart` below the Next Workout card.

**Tech Stack:** Flutter · Drift (SQLite, dates stored as Unix milliseconds) · Riverpod FutureProvider · Space Grotesk via google_fonts · LiquidGlassContainer

---

## File Map

| Action | File |
|---|---|
| Create | `lib/models/weekly_progress_data.dart` |
| Create | `lib/models/weekly_pr_entry.dart` |
| Modify | `lib/database/daos/sets_dao.dart` |
| Modify | `lib/providers/home_providers.dart` |
| Create | `lib/screens/home/widgets/weekly_progress_card.dart` |
| Create | `lib/screens/home/widgets/weekly_pr_card.dart` |
| Modify | `lib/screens/home/home_screen.dart` |

---

## Task 1: WeeklyProgressData model

**Files:**
- Create: `lib/models/weekly_progress_data.dart`

- [ ] **Step 1: Create the model**

```dart
// lib/models/weekly_progress_data.dart

class WeeklyProgressData {
  /// Tonnage (kg) for the current calendar week (Mon–Sun).
  final double tonnageKg;

  /// Tonnage for the previous calendar week.
  final double lastWeekTonnageKg;

  /// Tonnage for each of the last 8 calendar weeks, oldest first.
  /// Index 7 = current (possibly partial) week.
  final List<double> sparkline;

  /// Number of sessions logged this calendar week.
  final int sessionCount;

  /// Number of WODs planned per week from the active program.
  final int plannedSessions;

  /// Average RPE across all sets with non-null RPE this week.
  /// Null if no sets have RPE logged.
  final double? avgRpe;

  /// Average RPE from the previous calendar week. Null if no data.
  final double? lastWeekAvgRpe;

  /// Total set count this week (including timed sets).
  final int totalSets;

  /// Total set count last week.
  final int lastWeekTotalSets;

  /// Tonnage for Push-category exercises this week.
  final double pushTonnageKg;

  /// Tonnage for Pull-category exercises this week.
  final double pullTonnageKg;

  /// Tonnage for Legs-category exercises this week.
  final double legsTonnageKg;

  /// Push set count this week.
  final int pushSets;

  /// Pull set count this week.
  final int pullSets;

  /// Legs set count this week.
  final int legsSets;

  const WeeklyProgressData({
    required this.tonnageKg,
    required this.lastWeekTonnageKg,
    required this.sparkline,
    required this.sessionCount,
    required this.plannedSessions,
    required this.avgRpe,
    required this.lastWeekAvgRpe,
    required this.totalSets,
    required this.lastWeekTotalSets,
    required this.pushTonnageKg,
    required this.pullTonnageKg,
    required this.legsTonnageKg,
    required this.pushSets,
    required this.pullSets,
    required this.legsSets,
  });

  /// Percentage change in tonnage vs last week. Null if last week = 0.
  double? get tonnageDeltaPct {
    if (lastWeekTonnageKg == 0) return null;
    return (tonnageKg - lastWeekTonnageKg) / lastWeekTonnageKg * 100;
  }

  /// Max tonnage among Push/Pull/Legs — used to compute bar fill %.
  double get maxGroupTonnage =>
      [pushTonnageKg, pullTonnageKg, legsTonnageKg]
          .fold(0.0, (a, b) => a > b ? a : b);
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/models/weekly_progress_data.dart
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/models/weekly_progress_data.dart
git commit -m "feat: add WeeklyProgressData model"
```

---

## Task 2: WeeklyPREntry model

**Files:**
- Create: `lib/models/weekly_pr_entry.dart`

- [ ] **Step 1: Create the model**

```dart
// lib/models/weekly_pr_entry.dart

class WeeklyPREntry {
  final String exerciseName;
  final double weightKg;
  final int reps;

  const WeeklyPREntry({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/models/weekly_pr_entry.dart
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/models/weekly_pr_entry.dart
git commit -m "feat: add WeeklyPREntry model"
```

---

## Task 3: SetsDao — four new query methods

**Files:**
- Modify: `lib/database/daos/sets_dao.dart`

**Context:** Drift stores `DateTimeColumn` as Unix milliseconds (integers). Confirmed in `sets_dao.dart` line 81: `DateTime.fromMillisecondsSinceEpoch(r.read<int>('date'))`. All four new methods accept `DateTime from, DateTime to` and filter using `s.date >= from.millisecondsSinceEpoch AND s.date < to.millisecondsSinceEpoch`.

- [ ] **Step 1: Add imports at top of sets_dao.dart**

The file already imports `WeightHistoryPoint` and `PersonalRecordEntry`. Add the two new model imports:

```dart
import '../../models/weekly_progress_data.dart';
import '../../models/weekly_pr_entry.dart';
```

Place after the existing model imports (after line 6 `import '../../models/personal_record_entry.dart';`).

- [ ] **Step 2: Add `getWeeklyTonnageAndStats`**

This single query returns tonnage, avg RPE, total sets, and session count for a date range. Combining them avoids 4 separate DB round-trips.

Add this method at the bottom of the `SetsDao` class (before the closing `}`):

```dart
/// Returns tonnage (kg), average RPE, total sets, and session count
/// for sessions whose date falls within [from, to) (exclusive upper bound).
/// Sets with null/zero weightKg are excluded from tonnage.
/// Sets with null RPE are excluded from the RPE average.
Future<({double tonnageKg, double? avgRpe, int totalSets, int sessionCount})>
    getWeeklyTonnageAndStats(DateTime from, DateTime to) async {
  final result = await customSelect(
    'SELECT '
    '  COALESCE(SUM(CASE WHEN ws.weight_kg > 0 THEN ws.reps * ws.weight_kg ELSE 0 END), 0.0) AS tonnage, '
    '  AVG(CASE WHEN ws.rpe IS NOT NULL THEN ws.rpe ELSE NULL END) AS avg_rpe, '
    '  COUNT(*) AS total_sets, '
    '  COUNT(DISTINCT ws.session_id) AS session_count '
    'FROM workout_sets ws '
    'JOIN workout_sessions s ON ws.session_id = s.id '
    'WHERE s.date >= ? AND s.date < ?',
    variables: [
      Variable.withInt(from.millisecondsSinceEpoch),
      Variable.withInt(to.millisecondsSinceEpoch),
    ],
    readsFrom: {workoutSets, workoutSessions},
  ).getSingle();

  return (
    tonnageKg: result.read<double>('tonnage'),
    avgRpe: result.read<double?>('avg_rpe'),
    totalSets: result.read<int>('total_sets'),
    sessionCount: result.read<int>('session_count'),
  );
}
```

- [ ] **Step 3: Add `getTonnageByCategory`**

```dart
/// Returns tonnage and set count grouped by exercise category
/// for sessions within [from, to).
/// Only counts sets with weight_kg > 0 for tonnage.
Future<Map<String, ({double tonnageKg, int sets})>> getTonnageByCategory(
    DateTime from, DateTime to) async {
  final results = await customSelect(
    'SELECT e.category, '
    '  COALESCE(SUM(CASE WHEN ws.weight_kg > 0 THEN ws.reps * ws.weight_kg ELSE 0 END), 0.0) AS tonnage, '
    '  COUNT(*) AS sets '
    'FROM workout_sets ws '
    'JOIN workout_sessions s ON ws.session_id = s.id '
    'JOIN exercises e ON ws.exercise_id = e.id '
    'WHERE s.date >= ? AND s.date < ? '
    'GROUP BY e.category',
    variables: [
      Variable.withInt(from.millisecondsSinceEpoch),
      Variable.withInt(to.millisecondsSinceEpoch),
    ],
    readsFrom: {workoutSets, workoutSessions},
  ).get();

  return {
    for (final r in results)
      r.read<String>('category'): (
        tonnageKg: r.read<double>('tonnage'),
        sets: r.read<int>('sets'),
      ),
  };
}
```

- [ ] **Step 4: Add `getSparklineTonnage`**

```dart
/// Returns tonnage for each of [weekCount] calendar weeks ending at [weekEnd].
/// Index 0 = oldest week, index [weekCount-1] = the week containing [weekEnd].
Future<List<double>> getSparklineTonnage(
    DateTime weekEnd, int weekCount) async {
  final results = <double>[];
  for (int i = weekCount - 1; i >= 0; i--) {
    final to = weekEnd.subtract(Duration(days: i * 7));
    final from = to.subtract(const Duration(days: 7));
    final stats = await getWeeklyTonnageAndStats(from, to);
    results.add(stats.tonnageKg);
  }
  return results;
}
```

- [ ] **Step 5: Add `getPRsBreakingThisWeek`**

A PR is broken if the exercise's max weight this week is strictly greater than its max weight in all previous sessions. Exercises with no prior history are excluded.

```dart
/// Returns exercises where the max weight logged within [from, to) is
/// strictly greater than the max weight logged before [from].
/// Only applies to weighted (non-timed) exercises.
Future<List<WeeklyPREntry>> getPRsBreakingThisWeek(
    DateTime from, DateTime to) async {
  final results = await customSelect(
    'SELECT e.name, '
    '  MAX(ws.weight_kg) AS this_week_max, '
    '  ws.reps '
    'FROM workout_sets ws '
    'JOIN workout_sessions s ON ws.session_id = s.id '
    'JOIN exercises e ON ws.exercise_id = e.id '
    'WHERE s.date >= ? AND s.date < ? '
    '  AND ws.weight_kg > 0 AND e.is_timed = 0 '
    'GROUP BY ws.exercise_id '
    'HAVING this_week_max > COALESCE(('
    '  SELECT MAX(ws2.weight_kg) '
    '  FROM workout_sets ws2 '
    '  JOIN workout_sessions s2 ON ws2.session_id = s2.id '
    '  WHERE ws2.exercise_id = ws.exercise_id AND s2.date < ?'
    '), -1) '
    'AND ('
    '  SELECT MAX(ws2.weight_kg) '
    '  FROM workout_sets ws2 '
    '  JOIN workout_sessions s2 ON ws2.session_id = s2.id '
    '  WHERE ws2.exercise_id = ws.exercise_id AND s2.date < ?'
    ') IS NOT NULL',
    variables: [
      Variable.withInt(from.millisecondsSinceEpoch),
      Variable.withInt(to.millisecondsSinceEpoch),
      Variable.withInt(from.millisecondsSinceEpoch),
      Variable.withInt(from.millisecondsSinceEpoch),
    ],
    readsFrom: {workoutSets, workoutSessions},
  ).get();

  return results
      .map((r) => WeeklyPREntry(
            exerciseName: r.read<String>('name'),
            weightKg: r.read<double>('this_week_max'),
            reps: r.read<int>('reps'),
          ))
      .toList();
}
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/database/daos/sets_dao.dart
```
Expected: `No issues found`

- [ ] **Step 7: Commit**

```bash
git add lib/database/daos/sets_dao.dart lib/models/weekly_progress_data.dart lib/models/weekly_pr_entry.dart
git commit -m "feat: add weekly tonnage, category, sparkline, and PR DAO queries"
```

---

## Task 4: Riverpod providers

**Files:**
- Modify: `lib/providers/home_providers.dart`

**Context:** `home_providers.dart` uses `FutureProvider` (not `@riverpod` annotation style). Follow that pattern. The calendar week runs Monday 00:00 → next Monday 00:00 local time.

- [ ] **Step 1: Add helper function at bottom of home_providers.dart**

```dart
// ─── Week boundary helper ─────────────────────────────────────────────────────

/// Returns the Monday 00:00 of the week containing [day].
DateTime _weekStart(DateTime day) {
  final d = DateTime(day.year, day.month, day.day); // strip time
  return d.subtract(Duration(days: d.weekday - 1)); // weekday: 1=Mon
}
```

- [ ] **Step 2: Add weeklyProgressProvider**

Add after the `chartExerciseProvider` at the bottom of the file:

```dart
/// Weekly progress data for the current calendar week (Mon–Sun).
final weeklyProgressProvider = FutureProvider<WeeklyProgressData>((ref) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final thisMonday = _weekStart(now);
  final nextMonday = thisMonday.add(const Duration(days: 7));
  final lastMonday = thisMonday.subtract(const Duration(days: 7));

  // Current week stats
  final current = await db.setsDao.getWeeklyTonnageAndStats(thisMonday, nextMonday);

  // Last week stats
  final last = await db.setsDao.getWeeklyTonnageAndStats(lastMonday, thisMonday);

  // Muscle group breakdown for current week
  final categories = await db.setsDao.getTonnageByCategory(thisMonday, nextMonday);
  final push = categories['Push'] ?? (tonnageKg: 0.0, sets: 0);
  final pull = categories['Pull'] ?? (tonnageKg: 0.0, sets: 0);
  final legs = categories['Legs'] ?? (tonnageKg: 0.0, sets: 0);

  // 8-week sparkline ending this Sunday (nextMonday)
  final sparkline = await db.setsDao.getSparklineTonnage(nextMonday, 8);

  // Planned sessions from active program
  int plannedSessions = 3; // sensible default
  final program = await db.programsDao.getActiveProgram();
  if (program != null) {
    final phases = await db.programsDao.getPhasesForProgram(program.id);
    if (phases.isNotEmpty) {
      final wods = await db.programsDao.getWodTemplatesForPhase(phases.first.id);
      if (wods.isNotEmpty) plannedSessions = wods.length;
    }
  }

  return WeeklyProgressData(
    tonnageKg: current.tonnageKg,
    lastWeekTonnageKg: last.tonnageKg,
    sparkline: sparkline,
    sessionCount: current.sessionCount,
    plannedSessions: plannedSessions,
    avgRpe: current.avgRpe,
    lastWeekAvgRpe: last.avgRpe,
    totalSets: current.totalSets,
    lastWeekTotalSets: last.totalSets,
    pushTonnageKg: push.tonnageKg,
    pullTonnageKg: pull.tonnageKg,
    legsTonnageKg: legs.tonnageKg,
    pushSets: push.sets,
    pullSets: pull.sets,
    legsSets: legs.sets,
  );
});
```

- [ ] **Step 3: Add weeklyPRsProvider**

```dart
/// PRs broken in the current calendar week.
/// Returns empty list if none — the PR card hides itself in that case.
final weeklyPRsProvider = FutureProvider<List<WeeklyPREntry>>((ref) async {
  final db = ref.read(databaseProvider);
  final now = DateTime.now();
  final thisMonday = _weekStart(now);
  final nextMonday = thisMonday.add(const Duration(days: 7));
  return db.setsDao.getPRsBreakingThisWeek(thisMonday, nextMonday);
});
```

- [ ] **Step 4: Add missing imports at top of home_providers.dart**

Add after existing imports:

```dart
import '../models/weekly_progress_data.dart';
import '../models/weekly_pr_entry.dart';
```

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/providers/home_providers.dart
```
Expected: `No issues found`

- [ ] **Step 6: Commit**

```bash
git add lib/providers/home_providers.dart
git commit -m "feat: add weeklyProgressProvider and weeklyPRsProvider"
```

---

## Task 5: WeeklyProgressCard widget

**Files:**
- Create: `lib/screens/home/widgets/weekly_progress_card.dart`

**Context:** Uses `LiquidGlassContainer` (from `lib/widgets/liquid_glass_container.dart`). Colors: indigo `#6366F1`, blue `#32ADE6`, green `#34C759`, red `#FF453A`. All text uses Space Grotesk automatically via `ThemeData`. Section labels: 9px, w700, letterSpacing 1.2, rgba(white,0.30), uppercase.

- [ ] **Step 1: Create the widget file**

```dart
// lib/screens/home/widgets/weekly_progress_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/weekly_progress_data.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';

class WeeklyProgressCard extends ConsumerWidget {
  const WeeklyProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(weeklyProgressProvider);

    return async.when(
      loading: () => _skeleton(isDark),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) => _card(context, isDark, data),
    );
  }

  Widget _skeleton(bool isDark) => LiquidGlassContainer(
        borderRadius: 18,
        blurSigma: 10,
        tintColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.80),
        padding: const EdgeInsets.all(14),
        child: const SizedBox(height: 160),
      );

  Widget _card(BuildContext context, bool isDark, WeeklyProgressData data) {
    return LiquidGlassContainer(
      borderRadius: 18,
      blurSigma: 10,
      tintColor: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.80),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('WEEKLY PROGRESS'),
          const SizedBox(height: 10),
          _volumeHero(data),
          const SizedBox(height: 12),
          _sparkline(data.sparkline),
          const SizedBox(height: 14),
          _statsStrip(context, data),
          const _Divider(),
          const SizedBox(height: 12),
          _sectionLabel('MUSCLE BALANCE'),
          const SizedBox(height: 10),
          _muscleBalance(data),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Color(0x4DFFFFFF), // rgba(white, 0.30)
        ),
      );

  // ── Volume hero ────────────────────────────────────────────────────────────

  Widget _volumeHero(WeeklyProgressData data) {
    final delta = data.tonnageDeltaPct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatTonnage(data.tonnageKg),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'vs ${_formatTonnage(data.lastWeekTonnageKg)} kg last week',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ),
          ],
        ),
        const Spacer(),
        if (delta != null) _trendPill(delta),
      ],
    );
  }

  Widget _trendPill(double pct) {
    final isUp = pct >= 0;
    final color = isUp ? const Color(0xFF34C759) : const Color(0xFFFF453A);
    final label = '${isUp ? '↑' : '↓'} ${pct.abs().toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatTonnage(double kg) {
    if (kg >= 1000) {
      return '${(kg / 1000).toStringAsFixed(1)}k'
          .replaceAll('.0k', 'k');
    }
    return kg.toStringAsFixed(0);
  }

  // ── Sparkline ──────────────────────────────────────────────────────────────

  Widget _sparkline(List<double> weeks) {
    final maxVal = weeks.fold(0.0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weeks.length, (i) {
          final isCurrent = i == weeks.length - 1;
          final frac = maxVal > 0 ? weeks[i] / maxVal : 0.0;
          // Fade older bars: 20% → 40% alpha, current = full indigo
          final alpha = isCurrent ? 1.0 : 0.20 + (i / (weeks.length - 1)) * 0.25;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: FractionallySizedBox(
                heightFactor: frac.clamp(0.05, 1.0),
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: alpha),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Stats strip ────────────────────────────────────────────────────────────

  Widget _statsStrip(BuildContext context, WeeklyProgressData data) {
    final tiles = <Widget>[
      _StripTile(
        value: '${data.sessionCount}',
        label: 'Sessions',
        delta: 'of ${data.plannedSessions} planned',
        deltaColor: Colors.white.withValues(alpha: 0.25),
      ),
    ];

    if (data.avgRpe != null) {
      final rpeDelta = data.lastWeekAvgRpe != null
          ? data.avgRpe! - data.lastWeekAvgRpe!
          : null;
      tiles.add(_StripTile(
        value: data.avgRpe!.toStringAsFixed(1),
        label: 'Avg RPE',
        delta: rpeDelta == null
            ? null
            : '${rpeDelta >= 0 ? '↑' : '↓'} from ${data.lastWeekAvgRpe!.toStringAsFixed(1)}',
        deltaColor: rpeDelta == null
            ? null
            : rpeDelta > 0
                ? const Color(0xFFFF9F0A)
                : const Color(0xFF34C759),
      ));
    }

    final setsDelta = data.totalSets - data.lastWeekTotalSets;
    tiles.add(_StripTile(
      value: '${data.totalSets}',
      label: 'Total Sets',
      delta: setsDelta == 0
          ? null
          : '${setsDelta > 0 ? '↑' : '↓'} ${setsDelta.abs()} sets',
      deltaColor: setsDelta >= 0
          ? const Color(0xFF34C759)
          : const Color(0xFFFF453A),
    ));

    return Row(
      children: tiles
          .expand((t) => [Expanded(child: t), const SizedBox(width: 6)])
          .toList()
        ..removeLast(),
    );
  }

  // ── Muscle balance ─────────────────────────────────────────────────────────

  Widget _muscleBalance(WeeklyProgressData data) {
    final max = data.maxGroupTonnage;
    return Column(
      children: [
        _MuscleBar(
          label: 'Push',
          tonnageKg: data.pushTonnageKg,
          sets: data.pushSets,
          color: const Color(0xFF6366F1),
          fraction: max > 0 ? data.pushTonnageKg / max : 0,
        ),
        const SizedBox(height: 7),
        _MuscleBar(
          label: 'Pull',
          tonnageKg: data.pullTonnageKg,
          sets: data.pullSets,
          color: const Color(0xFF32ADE6),
          fraction: max > 0 ? data.pullTonnageKg / max : 0,
        ),
        const SizedBox(height: 7),
        _MuscleBar(
          label: 'Legs',
          tonnageKg: data.legsTonnageKg,
          sets: data.legsSets,
          color: const Color(0xFF34C759),
          fraction: max > 0 ? data.legsTonnageKg / max : 0,
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StripTile extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final Color? deltaColor;

  const _StripTile({
    required this.value,
    required this.label,
    this.delta,
    this.deltaColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              color: Colors.white.withValues(alpha: 0.30),
              letterSpacing: 0.4,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 3),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: deltaColor ?? Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MuscleBar extends StatelessWidget {
  final String label;
  final double tonnageKg;
  final int sets;
  final Color color;
  final double fraction; // 0.0–1.0

  const _MuscleBar({
    required this.label,
    required this.tonnageKg,
    required this.sets,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  ColoredBox(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.02, 1.0),
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            '${(tonnageKg / 1000 >= 1 ? '${(tonnageKg / 1000).toStringAsFixed(1)}k' : tonnageKg.toStringAsFixed(0))} kg',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            '$sets sets',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.30),
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 14),
        color: Colors.white.withValues(alpha: 0.06),
      );
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/home/widgets/weekly_progress_card.dart
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home/widgets/weekly_progress_card.dart
git commit -m "feat: add WeeklyProgressCard widget"
```

---

## Task 6: WeeklyPRCard widget

**Files:**
- Create: `lib/screens/home/widgets/weekly_pr_card.dart`

- [ ] **Step 1: Create the widget file**

```dart
// lib/screens/home/widgets/weekly_pr_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/home_providers.dart';
import '../../../widgets/liquid_glass_container.dart';

class WeeklyPRCard extends ConsumerWidget {
  const WeeklyPRCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyPRsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (prs) {
        if (prs.isEmpty) return const SizedBox.shrink();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return LiquidGlassContainer(
          borderRadius: 18,
          blurSigma: 10,
          tintColor: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.80),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.30)),
                ),
                child: Text(
                  '🏆 ${prs.length} PR${prs.length == 1 ? '' : 's'} this week',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9F0A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // PR rows
              ...prs.asMap().entries.map((entry) {
                final i = entry.key;
                final pr = entry.value;
                return Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF9F0A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pr.exerciseName,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${pr.weightKg % 1 == 0 ? pr.weightKg.toInt() : pr.weightKg} kg × ${pr.reps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PR',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF9F0A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < prs.length - 1)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 7),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/home/widgets/weekly_pr_card.dart
```
Expected: `No issues found`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home/widgets/weekly_pr_card.dart
git commit -m "feat: add WeeklyPRCard widget"
```

---

## Task 7: Wire into home screen

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add imports**

Add to the imports block at the top of `home_screen.dart`, after the existing widget imports:

```dart
import 'widgets/weekly_progress_card.dart';
import 'widgets/weekly_pr_card.dart';
```

- [ ] **Step 2: Insert cards in `_buildDashboard`**

In `_buildDashboard`, find the `SliverChildListDelegate` list. After the stat row and its `SizedBox(height: 20)`, insert the two new cards before the Daily Tasks section:

```dart
// ── Weekly progress ───────────────────────────────────────────────────
const WeeklyProgressCard(),
const SizedBox(height: 10),
const WeeklyPRCard(),
const SizedBox(height: 20),
```

The full `_buildDashboard` children list becomes:

```dart
delegate: SliverChildListDelegate([
  // ── Hero card ──────────────────────────────────────────────────────
  const NextWorkoutCard(),

  // ── Stat row ───────────────────────────────────────────────────────
  const SizedBox(height: 12),
  Row(
    children: [
      Expanded(child: _StatChip(label: 'Streak', value: '$score', icon: Icons.local_fire_department_rounded, iconColor: const Color(0xFFFF7A00))),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(label: 'Sessions', value: '$sessions', icon: Icons.calendar_month_rounded, iconColor: null)),
      const SizedBox(width: 10),
      Expanded(child: _StatChip(label: 'Week', value: '$week', icon: Icons.trending_up_rounded, iconColor: const Color(0xFF34C759))),
    ],
  ),
  const SizedBox(height: 12),

  // ── Weekly progress ────────────────────────────────────────────────
  const WeeklyProgressCard(),
  const SizedBox(height: 10),
  const WeeklyPRCard(),
  const SizedBox(height: 20),

  // ── Daily tasks ────────────────────────────────────────────────────
  if (enabledTasks.isNotEmpty) ...[
    _SectionLabel(label: 'DAILY TASKS'),
    const SizedBox(height: 8),
    ...enabledTasks.expand((t) => [
          DailyTaskHomeCard(task: t),
          const SizedBox(height: 8),
        ]),
  ],
  const SizedBox(height: 24),
]),
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/screens/home/home_screen.dart
```
Expected: `No issues found`

- [ ] **Step 4: Full app analyze**

```bash
flutter analyze lib/
```
Expected: `No issues found`

- [ ] **Step 5: Hot restart and verify on device**

- Weekly Progress card appears below the stat row
- Tonnage number shows (0 if no sessions logged yet)
- Sparkline renders 8 bars
- Stats strip shows Sessions / Total Sets (RPE tile hidden if no RPE logged)
- Muscle balance bars show Push/Pull/Legs
- PR card is hidden when there are no PRs this week

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat: wire WeeklyProgressCard and WeeklyPRCard into home screen"
```
