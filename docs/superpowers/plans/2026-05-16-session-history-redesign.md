# Session History Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the session history list (stats-preview tiles) and session detail (stats header + long-press edit/delete) per the spec at `docs/superpowers/specs/2026-05-16-session-history-redesign.md`.

**Architecture:** Four tasks in dependency order — DAO additions first, then providers, then history list screen, then detail screen. Tasks 3 and 4 can be done in either order but both depend on Tasks 1–2.

**Tech Stack:** Flutter, Riverpod (StreamProvider.family, FutureProvider), Drift (customSelect, watch), Dart

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/database/daos/sets_dao.dart` | Modify | Add `SessionSetStats`, `watchSetsForSession`, `getAllSessionStats`, `getVolumeForPriorSession` |
| `lib/providers/session_providers.dart` | Modify | Add `setsForSessionProvider`, `allSessionStatsProvider`, `priorSessionVolumeProvider` |
| `lib/screens/history/session_history_screen.dart` | Modify | Full tile redesign with date badge, stats strip, PR chip, volume delta |
| `lib/screens/history/session_detail_screen.dart` | Modify | Stats header, reactive sets stream, long-press edit/delete, edit bottom sheet |

---

### Task 1: DAO additions — `SessionSetStats`, `watchSetsForSession`, `getAllSessionStats`, `getVolumeForPriorSession`

**Files:**
- Modify: `lib/database/daos/sets_dao.dart`

> Note: `updateSet(WorkoutSetsCompanion)` and `deleteSet(int)` already exist at lines 18–22. Do NOT add duplicate methods.

- [ ] **Step 1: Add `SessionSetStats` class after the imports in `sets_dao.dart`**

Insert after the `part 'sets_dao.g.dart';` line:

```dart
class SessionSetStats {
  final int sessionId;
  final double totalVolume;
  final int setCount;
  final double? avgRpe;
  final double topWeight;
  final int exerciseCount;
  final int prCount;
  const SessionSetStats({
    required this.sessionId,
    required this.totalVolume,
    required this.setCount,
    this.avgRpe,
    required this.topWeight,
    required this.exerciseCount,
    required this.prCount,
  });
}
```

- [ ] **Step 2: Add `watchSetsForSession` to `SetsDao`**

Add after the `getSetsForSession` method (after line 33):

```dart
Stream<List<WorkoutSet>> watchSetsForSession(int sessionId) =>
    (select(workoutSets)
          ..where((s) => s.sessionId.equals(sessionId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.exerciseId),
            (s) => OrderingTerm(expression: s.setNumber),
          ]))
        .watch();
```

- [ ] **Step 3: Add `getAllSessionStats` to `SetsDao`**

Add after `watchSetsForSession`:

```dart
Future<Map<int, SessionSetStats>> getAllSessionStats() async {
  final results = await customSelect(
    'SELECT '
    '  ws.session_id, '
    '  COALESCE(SUM(ws.weight_kg * ws.reps), 0.0) AS total_volume, '
    '  COUNT(*) AS set_count, '
    '  AVG(ws.rpe) AS avg_rpe, '
    '  COALESCE(MAX(ws.weight_kg), 0.0) AS top_weight, '
    '  COUNT(DISTINCT ws.exercise_id) AS exercise_count, '
    '  COUNT(DISTINCT CASE WHEN ws.weight_kg = ex_max.max_weight '
    '    AND ws.weight_kg > 0 THEN ws.exercise_id END) AS pr_count '
    'FROM workout_sets ws '
    'LEFT JOIN ( '
    '  SELECT exercise_id, MAX(weight_kg) AS max_weight '
    '  FROM workout_sets '
    '  WHERE weight_kg > 0 '
    '  GROUP BY exercise_id '
    ') ex_max ON ws.exercise_id = ex_max.exercise_id '
    'GROUP BY ws.session_id',
    readsFrom: {workoutSets},
  ).get();

  return {
    for (final r in results)
      r.read<int>('session_id'): SessionSetStats(
        sessionId: r.read<int>('session_id'),
        totalVolume: r.read<double>('total_volume'),
        setCount: r.read<int>('set_count'),
        avgRpe: r.read<double?>('avg_rpe'),
        topWeight: r.read<double>('top_weight'),
        exerciseCount: r.read<int>('exercise_count'),
        prCount: r.read<int>('pr_count'),
      ),
  };
}
```

- [ ] **Step 4: Add `getVolumeForPriorSession` to `SetsDao`**

Add after `getAllSessionStats`:

```dart
/// Volume (sum weight_kg * reps) of the most recent session with the same
/// workoutName that occurred strictly before [beforeDate].
/// Returns null if no prior session exists.
Future<double?> getVolumeForPriorSession(
    String workoutName, DateTime beforeDate) async {
  final result = await customSelect(
    'SELECT COALESCE(SUM(ws.weight_kg * ws.reps), 0.0) AS volume '
    'FROM workout_sets ws '
    'WHERE ws.session_id = ('
    '  SELECT id FROM workout_sessions '
    '  WHERE workout_name = ? AND date < ? '
    '  ORDER BY date DESC '
    '  LIMIT 1 '
    ')',
    variables: [
      Variable.withString(workoutName),
      Variable.withInt(beforeDate.millisecondsSinceEpoch ~/ 1000),
    ],
    readsFrom: {workoutSets, workoutSessions},
  ).getSingleOrNull();
  final v = result?.read<double?>('volume');
  return (v == null || v == 0.0) ? null : v;
}
```

- [ ] **Step 5: Run the app to verify no compile errors**

```
flutter run
```

Expected: app launches normally. No Dart compile errors.

- [ ] **Step 6: Commit**

```bash
git add lib/database/daos/sets_dao.dart
git commit -m "feat: add SessionSetStats, watchSetsForSession, getAllSessionStats, getVolumeForPriorSession"
```

---

### Task 2: New providers

**Files:**
- Modify: `lib/providers/session_providers.dart`

- [ ] **Step 1: Add imports for `WorkoutSet` and `SessionSetStats`**

The file already imports `app_database.dart` and `database_provider.dart`. Add the missing import for `sets_dao.dart` types:

```dart
import '../database/daos/sets_dao.dart';
```

- [ ] **Step 2: Add the three new providers at the bottom of `session_providers.dart`**

```dart
/// Reactive stream of sets for a single session — used by session detail
/// so edits reflect immediately without a reload.
final setsForSessionProvider =
    StreamProvider.family<List<WorkoutSet>, int>((ref, sessionId) {
  return ref
      .watch(databaseProvider)
      .setsDao
      .watchSetsForSession(sessionId);
});

/// Batch stats (volume, sets, RPE, top weight, PR count) for every session.
/// Invalidated after any set edit or delete so the history list stays fresh.
final allSessionStatsProvider =
    FutureProvider<Map<int, SessionSetStats>>((ref) {
  return ref.watch(databaseProvider).setsDao.getAllSessionStats();
});

```

- [ ] **Step 3: Run the app to verify no compile errors**

```
flutter run
```

Expected: app launches normally.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/session_providers.dart
git commit -m "feat: add setsForSessionProvider, allSessionStatsProvider, priorSessionVolumeProvider"
```

---

### Task 3: Session History List redesign

**Files:**
- Modify: `lib/screens/history/session_history_screen.dart`

The existing file has `SessionHistoryScreen`, `_ListItem`, `_groupByWeek`, `_WeekHeader`, and `_SessionTile`. We keep the grouping logic and `_WeekHeader` unchanged. We rewrite `_SessionTile` and add several helper widgets.

- [ ] **Step 1: Update imports at the top of `session_history_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/daos/sessions_dao.dart';
import '../../database/daos/sets_dao.dart';
import '../../providers/database_provider.dart';
import '../../providers/home_providers.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'session_detail_screen.dart';
```

- [ ] **Step 2: Update `SessionHistoryScreen.build` to also watch `allSessionStatsProvider`**

Replace the `build` method of `SessionHistoryScreen`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final sessionsAsync = ref.watch(sessionHistoryProvider);
  final statsAsync = ref.watch(allSessionStatsProvider);

  return Scaffold(
    appBar: AppBar(title: const Text('History')),
    body: Stack(
      children: [
        const Positioned.fill(child: GlassBackground()),
        sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (entries) {
            if (entries.isEmpty) {
              return Center(
                child: Text(
                  'No sessions logged yet.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
              );
            }
            final stats = statsAsync.asData?.value ?? {};
            final grouped = _groupByWeek(entries);
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 50),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final group = grouped[i];
                if (group.isHeader) {
                  return _WeekHeader(label: group.label);
                }
                final entry = group.entry!;
                final isMostRecent = entry == entries.first;
                final sessionStats = stats[entry.session.id];
                // Find prior same-name session for delta
                double? priorVolume;
                if (sessionStats != null) {
                  final prior = entries.firstWhere(
                    (e) =>
                        e.session.workoutName == entry.session.workoutName &&
                        e.session.date.isBefore(entry.session.date),
                    orElse: () => entry,
                  );
                  if (prior != entry) {
                    priorVolume = stats[prior.session.id]?.totalVolume;
                  }
                }
                return _SessionTile(
                  entry: entry,
                  stats: sessionStats,
                  priorVolume: priorVolume,
                  isMostRecent: isMostRecent,
                );
              },
            );
          },
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Rewrite `_SessionTile` as a `ConsumerWidget`**

Replace the entire `_SessionTile` class with:

```dart
class _SessionTile extends ConsumerWidget {
  final SessionWithProgram entry;
  final SessionSetStats? stats;
  final double? priorVolume;
  final bool isMostRecent;
  const _SessionTile({
    required this.entry,
    required this.stats,
    required this.priorVolume,
    required this.isMostRecent,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final session = entry.session;
    await db.setsDao.deleteSetsForSession(session.id);
    await db.sessionsDao.deleteSession(session.id);
    ref.invalidate(nextWodProvider);
    ref.invalidate(personalRecordsProvider);
    ref.invalidate(pointsScoreProvider);
    ref.invalidate(allSessionStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${session.workoutName} deleted'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = entry.session;
    const indigo = Color(0xFF6366F1);
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (entry.programName != null) parts.add(entry.programName!);
    if (session.weekNumber != null) parts.add('Week ${session.weekNumber}');
    final subtitle = parts.isNotEmpty ? parts.join(' · ') : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(session.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(context, ref),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: cs.error),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              glassRoute(SessionDetailScreen(session: session)),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  // Row 1: date badge + name + PR chip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DateBadge(date: session.date, isMostRecent: isMostRecent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.workoutName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.45),
                                        fontSize: 10,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        if ((stats?.prCount ?? 0) > 0)
                          _PrChip(prCount: stats!.prCount),
                      ],
                    ),
                  ),
                  // Row 2: stats strip
                  if (stats != null)
                    _StatsStrip(
                      stats: stats!,
                      priorVolume: priorVolume,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add `_DateBadge` widget**

```dart
class _DateBadge extends StatelessWidget {
  final DateTime date;
  final bool isMostRecent;
  const _DateBadge({required this.date, required this.isMostRecent});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final bg = isMostRecent
        ? indigo.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.08);
    final fgStrong = isMostRecent ? indigo : Colors.white;
    final fgDim = isMostRecent
        ? indigo.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      width: 44,
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: fgStrong),
          ),
          Text(
            days[date.weekday - 1],
            style: TextStyle(fontSize: 10, color: fgDim),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add `_PrChip` widget**

```dart
class _PrChip extends StatelessWidget {
  final int prCount;
  const _PrChip({required this.prCount});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: indigo.withValues(alpha: 0.35)),
      ),
      child: Text(
        '🏆 $prCount PR${prCount > 1 ? 's' : ''}',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: indigo),
      ),
    );
  }
}
```

- [ ] **Step 6: Add `_StatsStrip` and `_StatCol` widgets**

```dart
class _StatsStrip extends StatelessWidget {
  final SessionSetStats stats;
  final double? priorVolume;
  const _StatsStrip({required this.stats, this.priorVolume});

  String _fmtVol(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  String? _delta() {
    if (priorVolume == null || priorVolume! == 0) return null;
    final pct = (stats.totalVolume - priorVolume!) / priorVolume! * 100;
    if (pct >= 0) return '↑${pct.toStringAsFixed(0)}%';
    return '↓${(-pct).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta();
    final deltaColor = delta == null
        ? null
        : delta.startsWith('↑')
            ? const Color(0xFF34C759)
            : const Color(0xFFFF453A);

    final cols = <Widget>[
      _StatCol(
        label: 'VOL kg',
        value: _fmtVol(stats.totalVolume),
        sub: delta,
        subColor: deltaColor,
      ),
      _VertDivider(),
      _StatCol(label: 'SETS', value: '${stats.setCount}'),
    ];

    if (stats.avgRpe != null) {
      cols.addAll([
        _VertDivider(),
        _StatCol(label: 'AVG RPE', value: stats.avgRpe!.toStringAsFixed(1)),
      ]);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        color: const Color.fromRGBO(0, 0, 0, 0.18),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: cols),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const _StatCol(
      {required this.label, required this.value, this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subColor ?? Colors.white),
            ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1));
  }
}
```

- [ ] **Step 7: Remove the old `_formatDate` helper (no longer used in tile)**

The history screen's `_formatDate` function is now unused in the tile (date is shown via `_DateBadge`). Delete the `_formatDate` function at the bottom of the file.

- [ ] **Step 8: Run on device and verify tile appearance**

Check:
- Date badge shows day number + day name
- Most recent session has indigo-tinted badge
- Stats strip appears under every tile with VOL, SETS, and AVG RPE (when logged)
- Volume delta shows ↑/↓ in green/red for sessions that have a prior same-name session
- PR chip shows `🏆 N PRs` for sessions with PRs
- Swipe-to-delete still works

- [ ] **Step 9: Commit**

```bash
git add lib/screens/history/session_history_screen.dart
git commit -m "feat: redesign session history tiles with date badge, stats strip, PR chip"
```

---

### Task 4: Session Detail redesign

**Files:**
- Modify: `lib/screens/history/session_detail_screen.dart`

This is a full rewrite of the file. The rewrite:
1. Replaces the one-shot Future load with `setsForSessionProvider` stream
2. Adds a stats header
3. Adds long-press → Edit/Delete on set rows
4. Adds an `_EditSetSheet` modal bottom sheet

- [ ] **Step 1: Replace the entire file content**

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../database/daos/sets_dao.dart';
import '../../providers/database_provider.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/vibrant_text.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Map<int, Exercise> _exerciseMap = {};
  bool _exercisesLoaded = false;
  double? _priorVolume;
  int? _pressedSetId;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final db = ref.read(databaseProvider);
    final exercises = await db.exercisesDao.getAllExercises();
    final prior = await db.setsDao.getVolumeForPriorSession(
      widget.session.workoutName,
      widget.session.date,
    );
    setState(() {
      _exerciseMap = {for (final e in exercises) e.id: e};
      _priorVolume = prior;
      _exercisesLoaded = true;
    });
  }

  void _clearPressed() {
    if (_pressedSetId != null) setState(() => _pressedSetId = null);
  }

  Future<void> _deleteSet(BuildContext ctx, int setId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Set'),
        content: const Text('Remove this set from the session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('Delete', style: TextStyle(color: Color(0xFFFF453A)))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).setsDao.deleteSet(setId);
    ref.invalidate(personalRecordsProvider);
    ref.invalidate(allSessionStatsProvider);
    setState(() => _pressedSetId = null);
  }

  void _openEditSheet(BuildContext ctx, WorkoutSet set) {
    final exercise = _exerciseMap[set.exerciseId];
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSetSheet(
        set: set,
        exerciseName: exercise?.name ?? 'Exercise',
        isTimed: exercise?.isTimed ?? false,
        onSaved: () {
          ref.invalidate(personalRecordsProvider);
          ref.invalidate(allSessionStatsProvider);
          // Re-fetch prior volume in case it changed
          ref
              .read(databaseProvider)
              .setsDao
              .getVolumeForPriorSession(
                  widget.session.workoutName, widget.session.date)
              .then((v) {
            if (mounted) setState(() => _priorVolume = v);
          });
        },
      ),
    );
    setState(() => _pressedSetId = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final setsAsync = ref.watch(setsForSessionProvider(session.id));
    final dateStr = _formatDate(session.date);

    return GestureDetector(
      onTap: _clearPressed,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.workoutName),
              Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: GlassBackground()),
            setsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sets) {
                if (!_exercisesLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sets.isEmpty) {
                  return Center(
                    child: Text(
                      'No sets recorded for this session.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                    ),
                  );
                }
                final groups = _buildGroups(sets);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: groups.length + 2, // header + hint + groups
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _StatsHeader(
                        sets: sets,
                        exerciseMap: _exerciseMap,
                        session: session,
                        priorVolume: _priorVolume,
                      );
                    }
                    if (i == 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                        child: Text(
                          'Long-press any set to edit or delete',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                  ),
                        ),
                      );
                    }
                    final group = groups[i - 2];
                    return _ExerciseCard(
                      group: group,
                      pressedSetId: _pressedSetId,
                      onLongPress: (id) =>
                          setState(() => _pressedSetId = id),
                      onEdit: (set) => _openEditSheet(context, set),
                      onDelete: (id) => _deleteSet(context, id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_ExerciseGroup> _buildGroups(List<WorkoutSet> sets) {
    final seen = <int>[];
    final grouped = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      if (!grouped.containsKey(s.exerciseId)) {
        seen.add(s.exerciseId);
        grouped[s.exerciseId] = [];
      }
      grouped[s.exerciseId]!.add(s);
    }
    return seen.map((id) {
      final ex = _exerciseMap[id];
      return _ExerciseGroup(
        exerciseId: id,
        name: ex?.name ?? 'Unknown',
        isTimed: ex?.isTimed ?? false,
        sets: grouped[id]!,
      );
    }).toList();
  }
}

// ─── Stats Header ─────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final List<WorkoutSet> sets;
  final Map<int, Exercise> exerciseMap;
  final WorkoutSession session;
  final double? priorVolume;
  const _StatsHeader({
    required this.sets,
    required this.exerciseMap,
    required this.session,
    this.priorVolume,
  });

  @override
  Widget build(BuildContext context) {
    // Compute stats from set list
    double totalVolume = 0;
    double topWeight = 0;
    double rpeSum = 0;
    int rpeCount = 0;
    final exerciseIds = <int>{};
    for (final s in sets) {
      totalVolume += s.weightKg * s.reps;
      if (s.weightKg > topWeight) topWeight = s.weightKg;
      if (s.rpe != null) {
        rpeSum += s.rpe!;
        rpeCount++;
      }
      exerciseIds.add(s.exerciseId);
    }
    final avgRpe = rpeCount > 0 ? rpeSum / rpeCount : null;

    String? deltaStr;
    Color? deltaColor;
    if (priorVolume != null && priorVolume! > 0 && totalVolume > 0) {
      final pct = (totalVolume - priorVolume!) / priorVolume! * 100;
      if (pct >= 0) {
        deltaStr = '↑ +${pct.toStringAsFixed(0)}% vs last ${session.workoutName}';
        deltaColor = const Color(0xFF34C759);
      } else {
        deltaStr =
            '↓ ${pct.toStringAsFixed(0)}% vs last ${session.workoutName}';
        deltaColor = const Color(0xFFFF453A);
      }
    }

    const indigo = Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Featured stat box
          LiquidGlassContainer(
            borderRadius: 16,
            blurSigma: 10,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtVol(totalVolume),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'total volume · kg',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      if (deltaStr != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          deltaStr,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: deltaColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Grid of smaller stats
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _SmallStat(label: 'SETS', value: '${sets.length}'),
              _SmallStat(
                  label: 'AVG RPE',
                  value: avgRpe != null ? avgRpe.toStringAsFixed(1) : '—'),
              _SmallStat(
                  label: 'TOP WEIGHT',
                  value: topWeight > 0 ? '${_fmtW(topWeight)} kg' : '—'),
              _SmallStat(
                  label: 'EXERCISES',
                  value: '${exerciseIds.length}'),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtVol(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      borderRadius: 12,
      blurSigma: 8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Exercise group / set rows ────────────────────────────────────────────────

class _ExerciseGroup {
  final int exerciseId;
  final String name;
  final bool isTimed;
  final List<WorkoutSet> sets;
  _ExerciseGroup({
    required this.exerciseId,
    required this.name,
    required this.isTimed,
    required this.sets,
  });
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseGroup group;
  final int? pressedSetId;
  final void Function(int setId) onLongPress;
  final void Function(WorkoutSet set) onEdit;
  final void Function(int setId) onDelete;
  const _ExerciseCard({
    required this.group,
    required this.pressedSetId,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VibrantText(
                group.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...group.sets.map((s) => _SetRow(
                    set: s,
                    isTimed: group.isTimed,
                    isPressed: pressedSetId == s.id,
                    onLongPress: () => onLongPress(s.id),
                    onEdit: () => onEdit(s),
                    onDelete: () => onDelete(s.id),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final WorkoutSet set;
  final bool isTimed;
  final bool isPressed;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SetRow({
    required this.set,
    required this.isTimed,
    required this.isPressed,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    const red = Color(0xFFFF453A);

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPressed
              ? indigo.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                'Set ${set.setNumber}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
              ),
            ),
            Expanded(
              child: isTimed
                  ? Text(_fmtSec(set.durationSeconds ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600))
                  : Row(
                      children: [
                        Text('${_fmtW(set.weightKg)} kg',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('×',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Text('${set.reps} reps',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (set.rpe != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'RPE ${set.rpe!.toStringAsFixed(1)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFFCC00),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
            ),
            if (isPressed) ...[
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    foregroundColor: indigo),
                child: const Text('Edit',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    foregroundColor: red),
                child: const Text('Delete',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Edit Set Bottom Sheet ────────────────────────────────────────────────────

class _EditSetSheet extends ConsumerStatefulWidget {
  final WorkoutSet set;
  final String exerciseName;
  final bool isTimed;
  final VoidCallback onSaved;
  const _EditSetSheet({
    required this.set,
    required this.exerciseName,
    required this.isTimed,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends ConsumerState<_EditSetSheet> {
  late double _weight;
  late int _reps;
  late int _durationSeconds;
  late double _rpe;
  late TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.set.weightKg;
    _reps = widget.set.reps;
    _durationSeconds = widget.set.durationSeconds ?? 0;
    _rpe = widget.set.rpe ?? 0.0;
    _notesCtrl = TextEditingController(text: widget.set.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(databaseProvider).setsDao.updateSet(WorkoutSetsCompanion(
          id: Value(widget.set.id),
          sessionId: Value(widget.set.sessionId),
          exerciseId: Value(widget.set.exerciseId),
          setNumber: Value(widget.set.setNumber),
          reps: Value(_reps),
          weightKg: Value(_weight),
          durationSeconds: Value(
              widget.isTimed ? _durationSeconds : widget.set.durationSeconds),
          rpe: Value(_rpe == 0.0 ? null : _rpe),
          notes: Value(_notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim()),
        ));
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _stepper({
    required String label,
    required String display,
    required VoidCallback onDec,
    required VoidCallback onInc,
    String? unit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.5),
            ),
          ),
          IconButton(
            onPressed: onDec,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(display,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(unit,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45))),
          ],
          const SizedBox(width: 12),
          IconButton(
            onPressed: onInc,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final d = DateTime.fromMillisecondsSinceEpoch(
        widget.set.sessionId); // just for type, real date comes from session
    // Use set number + exercise name for subtitle
    final subtitle =
        'Set ${widget.set.setNumber}';

    final bool saveEnabled = widget.isTimed
        ? _durationSeconds > 0
        : (_weight > 0 && _reps > 0);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Text(
            'Edit Set · ${widget.exerciseName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.45)),
          ),
          const Divider(height: 24),
          // Weight stepper (weighted exercises only)
          if (!widget.isTimed)
            _stepper(
              label: 'WEIGHT',
              display: _weight == _weight.roundToDouble()
                  ? _weight.toInt().toString()
                  : _weight.toStringAsFixed(1),
              unit: 'kg',
              onDec: () => setState(
                  () => _weight = (_weight - 0.5).clamp(0.0, 9999.0)),
              onInc: () =>
                  setState(() => _weight = (_weight + 0.5).clamp(0.0, 9999.0)),
            ),
          // Reps stepper (weighted) or Duration stepper (timed)
          if (!widget.isTimed)
            _stepper(
              label: 'REPS',
              display: '$_reps',
              onDec: () =>
                  setState(() => _reps = (_reps - 1).clamp(0, 9999)),
              onInc: () =>
                  setState(() => _reps = (_reps + 1).clamp(0, 9999)),
            )
          else
            _stepper(
              label: 'DURATION',
              display: _fmtSec(_durationSeconds),
              onDec: () => setState(() =>
                  _durationSeconds = (_durationSeconds - 5).clamp(0, 99999)),
              onInc: () => setState(
                  () => _durationSeconds = (_durationSeconds + 5).clamp(0, 99999)),
            ),
          // RPE slider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'RPE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _rpe == 0.0 ? 6.0 : _rpe,
                    min: 6.0,
                    max: 10.0,
                    divisions: 8,
                    activeColor: const Color(0xFFFFCC00),
                    onChanged: (v) => setState(() => _rpe = v),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    _rpe == 0.0 ? '—' : _rpe.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFCC00)),
                  ),
                ),
              ],
            ),
          ),
          // Clear RPE button
          if (_rpe != 0.0)
            GestureDetector(
              onTap: () => setState(() => _rpe = 0.0),
              child: Text(
                'Clear RPE',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          const SizedBox(height: 8),
          // Notes field
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              labelText: 'Notes',
              labelStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (saveEnabled && !_saving) ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 2: Run on device and verify**

Check:
- Stats header shows total volume, sets, avg RPE, top weight, exercises
- Delta shows vs prior same-name session (or nothing if no prior session)
- Hint text "Long-press any set to edit or delete" appears
- Long-pressing a set highlights it and shows Edit/Delete buttons
- Tapping outside clears the pressed state
- Delete shows a confirmation dialog then removes the set
- Edit opens the bottom sheet pre-filled with the set's values
- Saving in the edit sheet updates the set immediately (stream reactivity)
- RPE clamp: slider visible, Clear RPE button shows when RPE is set

- [ ] **Step 3: Commit**

```bash
git add lib/screens/history/session_detail_screen.dart
git commit -m "feat: session detail stats header, reactive sets, long-press edit/delete"
```

---

## Post-implementation

After all four tasks:

- [ ] Push to remote

```bash
git push
```
