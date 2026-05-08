# Weekly Progression — Home Screen Design

## Goal
Add two new cards to the home tab that give a meaningful at-a-glance answer to "am I progressing?" — without duplicating what the Records tab already shows.

## Approved Design

Two cards inserted **below the Next Workout card** on the home screen:

### Card 1: Weekly Progress
Single glass card containing four stacked sections:

1. **Volume hero** — large tonnage number (`14,280 kg`) with unit label, "vs X kg last week" sub-label, and a green/red `↑ 11%` trend pill (right-aligned)
2. **Sparkline** — 8 thin bars (one per calendar week, oldest→newest left→right), current week highlighted in full indigo `#6366F1`, past weeks in progressively faded indigo
3. **Stats strip** — 3 equal-width tiles: Sessions (of N planned) / Avg RPE (↑/↓ delta) / Total Sets (↑/↓ delta)
4. **Muscle balance** — divider then 3 horizontal progress bars: Push (indigo `#6366F1`) / Pull (blue `#32ADE6`) / Legs (green `#34C759`), each showing kg tonnage + set count

### Card 2: PR Card
Appears **only when ≥1 PR was broken in the current calendar week**, hidden otherwise. Shows a gold `🏆 N PRs this week` badge, then a row per PR: dot · exercise name · weight×reps · `PR` pill.

---

## Data & Formulas

**Calendar week:** Monday 00:00 → Sunday 23:59 local time. "Last week" is the preceding Mon–Sun window. This matches what most fitness apps use and is intuitive.

**Weekly Tonnage:**
```
tonnage = Σ (set.reps × set.weightKg)   for all sets in sessions within the week
```
Sets with `weightKg = null` (timed exercises) are excluded from tonnage.

**Muscle group tonnage:** Same formula, grouped by `exercise.category` (`Push` / `Pull` / `Legs` / `Other`). `Other` is excluded from the balance display.

**Bar fill %:** `group_tonnage / max(group_tonnage across Push+Pull+Legs) × 100%` — relative, not absolute, so the dominant group always hits 100%.

**Avg RPE:** `mean(set.rpe)` for all sets in the week that have a non-null RPE value. If no sets have RPE, hide the RPE tile.

**Total Sets:** Count of all sets logged this week (includes timed sets).

**Sessions planned:** Pulled from active program's `wodsPerWeek` field.

**Sparkline (8 weeks):** Tonnage for each of the 8 calendar weeks ending this Sunday, including current (potentially partial) week.

**PR detection:** A PR is broken this week if, for a given exercise, `max(weightKg)` across sets logged this week > `max(weightKg)` across all sets logged before this week. Only weight-based exercises. If the exercise has no prior history, it is not counted as a PR.

---

## Architecture

### New model: `WeeklyProgressData`
```dart
// lib/models/weekly_progress_data.dart
class WeeklyProgressData {
  final double tonnageKg;           // current week
  final double lastWeekTonnageKg;   // previous week
  final List<double> sparkline;     // 8 values, index 7 = current week
  final int sessionCount;
  final int plannedSessions;
  final double? avgRpe;             // null if no RPE logged
  final int totalSets;
  final int lastWeekTotalSets;
  final double pushTonnage;
  final double pullTonnage;
  final double legsTonnage;
}
```

### New model: `WeeklyPREntry`
```dart
// lib/models/weekly_pr_entry.dart  (add to existing models/)
class WeeklyPREntry {
  final String exerciseName;
  final double weightKg;
  final int reps;
}
```

### New DAO queries (in `SetsDao`)
Three new methods on the existing `SetsDao`:

```dart
// Weekly tonnage for a date range
Future<double> getWeeklyTonnage(DateTime from, DateTime to);

// Tonnage grouped by category for a date range  
Future<Map<String, double>> getTonnageByCategory(DateTime from, DateTime to);

// Average RPE and total set count for a date range
Future<({double? avgRpe, int totalSets})> getWeeklyStats(DateTime from, DateTime to);

// PRs broken within [from, to] that were not PRs before [from]
Future<List<WeeklyPREntry>> getPRsBreakingThisWeek(DateTime from, DateTime to);
```

All four use raw Drift `customSelect` with date filtering. Use `date('now', 'weekday 0', '-6 days')` pattern in Dart (compute in Dart, not SQL) for clarity.

### New provider: `weeklyProgressProvider`
```dart
// lib/providers/home_providers.dart  (add to existing file)
@riverpod
Future<WeeklyProgressData> weeklyProgress(Ref ref) async { ... }

@riverpod
Future<List<WeeklyPREntry>> weeklyPRs(Ref ref) async { ... }
```

Both providers call the new DAO methods. Recompute whenever `recentSessionsProvider` changes (use `ref.watch` on it to trigger refresh).

### New widgets
```
lib/screens/home/widgets/weekly_progress_card.dart   — Card 1
lib/screens/home/widgets/weekly_pr_card.dart         — Card 2
```

`WeeklyProgressCard` is a `ConsumerWidget` watching `weeklyProgressProvider`. Shows a skeleton/shimmer while loading (use `AsyncValue.when`).

`WeeklyPRCard` watches `weeklyPRsProvider`. Returns `SizedBox.shrink()` when the list is empty — so it naturally disappears when there are no PRs.

### Home screen change
In `lib/screens/home/home_screen.dart`, insert after the existing Next Workout card:
```dart
const WeeklyProgressCard(),
const WeeklyPRCard(),
```

---

## Visual Spec

Matches the established glass design language exactly:

| Element | Spec |
|---|---|
| Card container | `LiquidGlassContainer`, `borderRadius: 18`, `blurSigma: 10` |
| Section label | `9px`, `FontWeight.w700`, `letterSpacing: 1.2`, `rgba(white, 0.30)`, uppercase |
| Tonnage number | `40px`, `FontWeight.w800`, `letterSpacing: -1` |
| Trend pill (up) | `#34C759` fill 15% + border 30%, `fontSize: 11`, `w700` |
| Trend pill (down) | `#FF453A` fill 12% + border 25%, same text style |
| Sparkline bar | `borderRadius: 3px 3px 0 0`, current week `#6366F1`, past weeks `#6366F1` at 20→40% alpha |
| Stats strip tile | `rgba(white, 0.04)` bg, `borderRadius: 11`, delta text `fontSize: 9`, `w700` |
| Muscle bar track | `rgba(white, 0.06)`, `height: 6`, `borderRadius: 3` |
| Muscle bar fill | Push `#6366F1`, Pull `#32ADE6`, Legs `#34C759` |
| PR badge | `#FF9F0A` 15% fill + 30% border |
| PR card | Hidden (`SizedBox.shrink`) when no PRs this week |

---

## Out of Scope
- Tapping the sparkline bar to drill into that week's detail
- Configuring which muscle groups show (always Push/Pull/Legs)
- Per-exercise volume breakdown
- E1RM / Lift Ladder (Option B) — deferred, can be added later
