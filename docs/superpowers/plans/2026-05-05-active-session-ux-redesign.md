# Active Session UX Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the active session screen into a flat, fully-expanded scrollable list with per-set rows, inline history, and exercise swap/reorder/skip/add capabilities.

**Architecture:** A new `_SessionItem` wrapper holds mutable session state (skip flags, ad-hoc flag, skipped sets) around each `WodItem`. The `ListView` renders all items as full cards — current card glows with an accent border, completed cards are green-tinted, upcoming cards are dimmed but show last-session data. All timer, audio, notification, and save/restore logic is preserved; only the UI and the mutable items list change.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), `shared_preferences` for progress save/restore.

---

## File Map

| File | Action | Notes |
|---|---|---|
| `lib/screens/log/active_session_screen.dart` | Modify | All changes. Existing private widgets stay. New widgets appended at bottom. |

---

### Task 1 — Add `_SessionItem` model and replace `_items` with mutable list

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_SessionItem` class directly below `_SetData` (~line 31)**

```dart
/// Wraps a [WodItem] with mutable session metadata.
class _SessionItem {
  WodItem wodItem;
  bool skipped;
  bool isAdHoc;
  final Set<int> skippedSets; // 0-based set indices skipped by the user

  _SessionItem({
    required this.wodItem,
    this.skipped = false,
    this.isAdHoc = false,
  }) : skippedSets = {};
}
```

- [ ] **Replace the `_items` getter with a mutable list field in `_ActiveSessionScreenState`**

Remove:
```dart
List<WodItem> get _items => widget.result.items;
```
Add as a field:
```dart
final List<_SessionItem> _sessionItems = [];
```

- [ ] **Initialize `_sessionItems` in `_load()`, after the `_setData` population loop**

```dart
_sessionItems.addAll(widget.result.items.map((i) => _SessionItem(wodItem: i)));
```

- [ ] **Update all helper getters and methods to use `_sessionItems[x].wodItem` instead of `_items[x]`**

In `_currentEntry`, `_currentCircuit`, `_isCircuit`, `_circuitName`, `_circuitRoundLabel`, `_circuitContext`, `_circuitNextLabel`: replace `_items[_currentItemIdx]` → `_sessionItems[_currentItemIdx].wodItem`.

In `_onDoneSet()`, `_getNextLabel()`, `_updateNotification()`: replace every `_items[` reference with `_sessionItems[` and append `.wodItem` when accessing the WodItem. Replace `_items.length` → `_sessionItems.length`.

In `build()`: replace `final totalItems = _items.length` → `final totalItems = _sessionItems.length`.

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "error|warning" | head -20
```
Expected: no errors.

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "refactor: wrap session items in _SessionItem with mutable metadata"
```

---

### Task 2 — Flat ListView with card-state helpers and stub widgets

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_CardState` enum and `_cardStateFor()` helper to `_ActiveSessionScreenState`**

```dart
enum _CardState { active, completed, upcoming }

_CardState _cardStateFor(int i) {
  if (_sessionItems[i].skipped) return _CardState.completed;
  if (i < _currentItemIdx) return _CardState.completed;
  if (i == _currentItemIdx) return _CardState.active;
  return _CardState.upcoming;
}
```

- [ ] **Add `_nextNonSkippedSet()` helper**

```dart
/// Returns the next set index ≥ [fromSet] that is not in [skippedSets],
/// or [totalSets] if all remaining are skipped.
int _nextNonSkippedSet(int itemIdx, int fromSet, int totalSets) {
  int next = fromSet;
  while (next < totalSets && _sessionItems[itemIdx].skippedSets.contains(next)) {
    next++;
  }
  return next;
}
```

- [ ] **Add `_historyExpanded` map field**

```dart
final Map<int, bool> _historyExpanded = {};
```

- [ ] **Replace the existing `ListView` in `build()` with a flat `ListView.builder`**

The old `ListView(children: [...])` block (from the `ListView(` call to its closing paren, before the rest timer overlay) becomes:

```dart
ListView.builder(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
  itemCount: _sessionItems.length * 2 + 1,
  itemBuilder: (_, i) {
    if (i.isEven) {
      final insertAt = i ~/ 2;
      return _AddExerciseGap(onAdd: () => _showAddExerciseSheet(insertAt));
    }
    final itemIdx = i ~/ 2;
    final state = _cardStateFor(itemIdx);
    final si = _sessionItems[itemIdx];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: switch (si.wodItem) {
        StandaloneWodExercise(:final entry) => _ExerciseCard(
            entry: entry,
            cardState: state,
            itemIndex: itemIdx,
            setData: _setData[entry.templateExercise.exerciseId] ?? [],
            currentSetIdx: itemIdx == _currentItemIdx ? _currentSetIdx : -1,
            lastSets: _lastSets[entry.templateExercise.exerciseId] ?? [],
            prKg: _prData[entry.templateExercise.exerciseId],
            prDurationSeconds: _prDurationData[entry.templateExercise.exerciseId],
            skippedSets: si.skippedSets,
            isAdHoc: si.isAdHoc,
            timedRunning: itemIdx == _currentItemIdx ? _timedRunning : false,
            timedElapsed: itemIdx == _currentItemIdx ? _timedElapsed : 0,
            timedStopped: itemIdx == _currentItemIdx ? _timedStopped : false,
            historyExpanded: _historyExpanded[entry.templateExercise.exerciseId] ?? false,
            onToggleHistory: () => setState(() {
              final id = entry.templateExercise.exerciseId;
              _historyExpanded[id] = !(_historyExpanded[id] ?? false);
            }),
            onSetDataChanged: (setIdx, data) =>
                _onSetChanged(entry.templateExercise.exerciseId, setIdx, data),
            onDoneSet: itemIdx == _currentItemIdx ? _onDoneSet : null,
            onStartTimer: itemIdx == _currentItemIdx ? _startExerciseTimer : null,
            onStopTimer: itemIdx == _currentItemIdx ? _stopExerciseTimer : null,
            onSkipSet: (setIdx) => _skipSet(itemIdx, setIdx),
            onShowActions: () => _showExerciseActions(context, itemIdx),
          ),
        WodCircuit() => _CircuitCard(
            circuit: si.wodItem as WodCircuit,
            cardState: state,
            itemIndex: itemIdx,
            currentItemIdx: _currentItemIdx,
            currentSetIdx: _currentSetIdx,
            currentCircuitExIdx: _circuitExerciseIdx,
            setData: _setData,
            lastSets: _lastSets,
            prData: _prData,
            prDurationData: _prDurationData,
            historyExpanded: _historyExpanded,
            onToggleHistory: (exerciseId) => setState(() {
              _historyExpanded[exerciseId] = !(_historyExpanded[exerciseId] ?? false);
            }),
            onSetDataChanged: _onSetChanged,
            onDoneSet: itemIdx == _currentItemIdx ? _onDoneSet : null,
            onStartTimer: itemIdx == _currentItemIdx ? _startExerciseTimer : null,
            onStopTimer: itemIdx == _currentItemIdx ? _stopExerciseTimer : null,
            onShowCircuitActions: () => _showExerciseActions(context, itemIdx),
            onShowExerciseActions: (exIdx) =>
                _showCircuitExerciseActions(context, itemIdx, exIdx),
            timedRunning: itemIdx == _currentItemIdx ? _timedRunning : false,
            timedElapsed: itemIdx == _currentItemIdx ? _timedElapsed : 0,
            timedStopped: itemIdx == _currentItemIdx ? _timedStopped : false,
          ),
      },
    );
  },
),
```

- [ ] **Add stub methods and widgets so the file compiles**

```dart
// ── Stub action methods (implemented in Tasks 6-10) ──────────────────────
void _showAddExerciseSheet(int insertAt) {}
void _showExerciseActions(BuildContext context, int itemIdx) {}
void _showCircuitExerciseActions(BuildContext context, int itemIdx, int exIdx) {}
void _skipSet(int itemIdx, int setIdx) {}

// ── _AddExerciseGap ───────────────────────────────────────────────────────
class _AddExerciseGap extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddExerciseGap({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 13, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(width: 5),
            Text('add exercise', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.18))),
          ],
        ),
      ),
    );
  }
}

// ── _ExerciseCard stub ────────────────────────────────────────────────────
class _ExerciseCard extends StatelessWidget {
  final WodExerciseEntry entry;
  final _CardState cardState;
  final int itemIndex;
  final List<_SetData> setData;
  final int currentSetIdx;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final Set<int> skippedSets;
  final bool isAdHoc;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, _SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final void Function(int) onSkipSet;
  final VoidCallback onShowActions;

  const _ExerciseCard({
    required this.entry, required this.cardState, required this.itemIndex,
    required this.setData, required this.currentSetIdx, required this.lastSets,
    required this.prKg, required this.prDurationSeconds, required this.skippedSets,
    required this.isAdHoc, required this.timedRunning, required this.timedElapsed,
    required this.timedStopped, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onSkipSet, required this.onShowActions,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
    child: Center(child: Text(entry.exercise.name)),
  );
}

// ── _CircuitCard stub ─────────────────────────────────────────────────────
class _CircuitCard extends StatelessWidget {
  final WodCircuit circuit;
  final _CardState cardState;
  final int itemIndex;
  final int currentItemIdx;
  final int currentSetIdx;
  final int currentCircuitExIdx;
  final Map<int, List<_SetData>> setData;
  final Map<int, List<WorkoutSet>> lastSets;
  final Map<int, double?> prData;
  final Map<int, int?> prDurationData;
  final Map<int, bool> historyExpanded;
  final void Function(int) onToggleHistory;
  final void Function(int, int, _SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowCircuitActions;
  final void Function(int) onShowExerciseActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;

  const _CircuitCard({
    required this.circuit, required this.cardState, required this.itemIndex,
    required this.currentItemIdx, required this.currentSetIdx,
    required this.currentCircuitExIdx, required this.setData, required this.lastSets,
    required this.prData, required this.prDurationData, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onShowCircuitActions, required this.onShowExerciseActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
    child: const Center(child: Text('Circuit')),
  );
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "refactor: flat ListView with stub cards and add-exercise gaps"
```

---

### Task 3 — Implement `_ExerciseCard` with all set rows

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_StatusBadge`, `_ReadOnlyField` helper widgets at the bottom of the file**

```dart
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5,
    )),
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;
  final bool strikethrough;
  final Color? accent;
  const _ReadOnlyField({
    required this.label, required this.value,
    this.dim = false, this.strikethrough = false, this.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: dim ? 0.03 : 0.07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.3)),
      Text(value, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: accent ?? Colors.white.withValues(alpha: dim ? 0.3 : 0.9),
        decoration: strikethrough ? TextDecoration.lineThrough : null,
      )),
    ]),
  );
}
```

- [ ] **Add `_SetRowItem` widget**

```dart
class _SetRowItem extends StatelessWidget {
  final int setIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final bool isSkipped;
  final bool canSkip; // true = long-press to skip is available
  final _SetData data;
  final _SetData referenceData;
  final void Function(_SetData)? onChanged; // non-null only when isActive
  final VoidCallback onSkip;

  const _SetRowItem({
    super.key,
    required this.setIndex, required this.isTimed, required this.isActive,
    required this.isDone, required this.isSkipped, required this.canSkip,
    required this.data, required this.referenceData,
    required this.onChanged, required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPress: canSkip ? onSkip : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
            width: 46,
            child: Text('Set ${setIndex + 1}', style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? accent : Colors.white.withValues(alpha: isDone ? 0.4 : 0.22),
              decoration: isSkipped ? TextDecoration.lineThrough : null,
            )),
          ),
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: isSkipped ? Colors.white12 : isDone ? Colors.green : isActive ? accent : Colors.white24,
          ),
          const SizedBox(width: 8),
          if (isActive && onChanged != null)
            Expanded(child: _SetRow(
              key: ValueKey('srinput-$setIndex'),
              setNumber: setIndex + 1,
              isTimed: isTimed,
              data: data,
              referenceData: referenceData,
              onChanged: onChanged!,
            ))
          else ...[
            if (!isTimed) ...[
              Expanded(child: _ReadOnlyField(
                label: 'WEIGHT',
                value: isSkipped || data.weightKg == 0 ? '—' : '${_fmtW(data.weightKg)} kg',
                dim: !isDone,
              )),
              const SizedBox(width: 6),
            ],
            Expanded(child: _ReadOnlyField(
              label: isTimed ? 'DURATION' : 'REPS',
              value: isSkipped
                  ? 'skip'
                  : isTimed
                      ? (data.durationSeconds > 0 ? _fmtSec(data.durationSeconds) : '—')
                      : (data.reps > 0 ? '${data.reps}' : '—'),
              dim: !isDone,
              strikethrough: isSkipped,
              accent: isSkipped ? Colors.orange : null,
            )),
          ],
        ]),
      ),
    );
  }
}
```

- [ ] **Replace `_ExerciseCard.build()` stub with full implementation**

```dart
@override
Widget build(BuildContext context) {
  final te = entry.templateExercise;
  final isTimed = entry.exercise.isTimed;
  final accent = Theme.of(context).colorScheme.primary;
  final isActive = cardState == _CardState.active;
  final isDone = cardState == _CardState.completed;

  final borderColor = isActive
      ? accent.withValues(alpha: 0.6)
      : isDone ? Colors.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08);
  final bgColor = isActive
      ? accent.withValues(alpha: 0.09)
      : isDone ? Colors.green.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03);

  return AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
      boxShadow: isActive ? [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: 1)] : null,
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isActive) _StatusBadge(label: '▶ NOW', color: accent)
            else if (isDone) const _StatusBadge(label: '✓ DONE', color: Colors.green)
            else if (isAdHoc) const _StatusBadge(label: '＋ added', color: Colors.orange),
            Text(entry.exercise.name,
                style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              isTimed
                  ? '${te.targetSets} sets · ${_fmtSec(te.repRangeMin)}'
                  : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 20),
              onPressed: onShowActions,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(minimumSize: const Size(32, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
            ),
            if (!isTimed) _SuggestionBadge(suggestion: entry.suggestion),
          ]),
        ]),

        const SizedBox(height: 8),

        // ── History chip ─────────────────────────────────────────────────
        _HistoryChipRow(
          lastSets: lastSets, isTimed: isTimed,
          prKg: prKg, prDurationSeconds: prDurationSeconds,
          expanded: historyExpanded, onToggle: onToggleHistory,
        ),

        const SizedBox(height: 10),

        // ── Set rows ─────────────────────────────────────────────────────
        ...List.generate(te.targetSets, (setIdx) {
          final isSetActive = isActive && setIdx == currentSetIdx;
          final isSetDone = (isActive && setIdx < currentSetIdx) || (isDone && !skippedSets.contains(setIdx));
          final isSetSkipped = skippedSets.contains(setIdx);

          // Reference data: first set uses suggestion, subsequent copy previous
          final _SetData refData;
          if (setIdx == 0) {
            refData = isTimed
                ? _SetData(weightKg: 0, reps: 0, durationSeconds: lastSets.isNotEmpty ? (lastSets[0].durationSeconds ?? te.repRangeMin) : te.repRangeMin)
                : _SetData(weightKg: entry.suggestion.suggestedKg ?? 0.0, reps: lastSets.isNotEmpty ? lastSets[0].reps : te.repRangeMax);
          } else {
            refData = setIdx - 1 < setData.length ? setData[setIdx - 1] : _SetData(weightKg: 0, reps: 0);
          }

          return _SetRowItem(
            key: ValueKey('set-${te.exerciseId}-$itemIndex-$setIdx'),
            setIndex: setIdx, isTimed: isTimed,
            isActive: isSetActive, isDone: isSetDone, isSkipped: isSetSkipped,
            canSkip: !isSetActive && !isSetDone && !isSetSkipped && isActive,
            data: setIdx < setData.length ? setData[setIdx] : _SetData(weightKg: 0, reps: 0),
            referenceData: refData,
            onChanged: isSetActive ? (data) => onSetDataChanged(setIdx, data) : null,
            onSkip: () => onSkipSet(setIdx),
          );
        }),

        // ── Done button / timer ──────────────────────────────────────────
        if (isActive && onDoneSet != null) ...[
          const SizedBox(height: 12),
          if (isTimed)
            _TimedSetInput(
              running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
              target: te.repRangeMin, isCircuit: false,
              onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
            )
          else
            Center(child: _CheckCircleButton(
              key: ValueKey('check-${entry.exercise.id}-$currentSetIdx'),
              onDone: onDoneSet!,
            )),
        ],
      ]),
    ),
  );
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: implement _ExerciseCard with per-set rows and status highlighting"
```

---

### Task 4 — `_HistoryChipRow`: expandable inline last-session table

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_HistoryChipRow` widget**

```dart
class _HistoryChipRow extends StatelessWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final double? prKg;
  final int? prDurationSeconds;
  final bool expanded;
  final VoidCallback onToggle;

  const _HistoryChipRow({
    required this.lastSets, required this.isTimed,
    required this.prKg, required this.prDurationSeconds,
    required this.expanded, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasHistory = lastSets.isNotEmpty;
    final prStr = isTimed
        ? (prDurationSeconds != null && prDurationSeconds! > 0 ? _fmtSec(prDurationSeconds!) : null)
        : (prKg != null && prKg! > 0 ? '${_fmtW(prKg!)} kg' : null);

    if (!hasHistory && prStr == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (hasHistory)
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Last', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 13, color: Colors.white38),
              ]),
            ),
          ),
        if (hasHistory && prStr != null) const SizedBox(width: 8),
        if (prStr != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Text('PR $prStr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber)),
          ),
      ]),
      if (expanded && hasHistory) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (int i = 0; i < lastSets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 46, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38))),
                  if (!isTimed)
                    Expanded(child: Text('${_fmtW(lastSets[i].weightKg)} kg',
                        style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(
                    isTimed ? _fmtSec(lastSets[i].durationSeconds ?? 0) : '× ${lastSets[i].reps} reps',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  )),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: expandable history chip with inline set table"
```

---

### Task 5 — Implement `_CircuitCard` with per-exercise round rows

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_RoundRowItem` widget (same pattern as `_SetRowItem`, labeled "Round N")**

```dart
class _RoundRowItem extends StatelessWidget {
  final int roundIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final _SetData data;
  final _SetData referenceData;
  final void Function(_SetData)? onChanged;

  const _RoundRowItem({
    required this.roundIndex, required this.isTimed,
    required this.isActive, required this.isDone,
    required this.data, required this.referenceData, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final teal = const Color(0xFF14B8A6);
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 52, child: Text('Round ${roundIndex + 1}', style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          color: isActive ? teal : Colors.white.withValues(alpha: isDone ? 0.4 : 0.2),
        ))),
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13, color: isDone ? teal : isActive ? accent : Colors.white24),
        const SizedBox(width: 8),
        if (isActive && onChanged != null)
          Expanded(child: _SetRow(
            key: ValueKey('round-input-$roundIndex'),
            setNumber: roundIndex + 1, isTimed: isTimed,
            data: data, referenceData: referenceData, onChanged: onChanged!,
          ))
        else ...[
          if (!isTimed) ...[
            Expanded(child: _ReadOnlyField(label: 'WEIGHT',
                value: data.weightKg > 0 ? '${_fmtW(data.weightKg)} kg' : '—', dim: !isDone)),
            const SizedBox(width: 6),
          ],
          Expanded(child: _ReadOnlyField(
            label: isTimed ? 'DURATION' : 'REPS',
            value: isTimed
                ? (data.durationSeconds > 0 ? _fmtSec(data.durationSeconds) : '—')
                : (data.reps > 0 ? '${data.reps}' : '—'),
            dim: !isDone,
          )),
        ],
      ]),
    );
  }
}
```

- [ ] **Add `_CircuitExerciseSection` widget**

```dart
class _CircuitExerciseSection extends StatelessWidget {
  final WodExerciseEntry exercise;
  final int rounds;
  final bool isCurrentExercise;
  final int currentRound; // 0-based, -1 when circuit not active
  final List<_SetData> setData;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, _SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;

  const _CircuitExerciseSection({
    required this.exercise, required this.rounds,
    required this.isCurrentExercise, required this.currentRound,
    required this.setData, required this.lastSets,
    required this.prKg, required this.prDurationSeconds,
    required this.historyExpanded, required this.onToggleHistory,
    required this.onSetDataChanged, required this.onDoneSet,
    required this.onStartTimer, required this.onStopTimer,
    required this.onShowActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
  });

  _SetData _refData(int roundIdx) {
    final te = exercise.templateExercise;
    final isTimed = exercise.exercise.isTimed;
    if (roundIdx == 0) {
      return isTimed
          ? _SetData(weightKg: 0, reps: 0, durationSeconds: lastSets.isNotEmpty ? (lastSets[0].durationSeconds ?? te.repRangeMin) : te.repRangeMin)
          : _SetData(weightKg: exercise.suggestion.suggestedKg ?? 0.0, reps: lastSets.isNotEmpty ? lastSets[0].reps : te.repRangeMax);
    }
    return roundIdx - 1 < setData.length ? setData[roundIdx - 1] : _SetData(weightKg: 0, reps: 0);
  }

  @override
  Widget build(BuildContext context) {
    final te = exercise.templateExercise;
    final isTimed = exercise.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isCurrentExercise) _StatusBadge(label: '▶ NOW', color: accent),
            Text(exercise.exercise.name,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Text(
              isTimed ? _fmtSec(te.repRangeMin) : '${te.repRangeMin}–${te.repRangeMax} reps',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ])),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 18),
            onPressed: onShowActions,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
          ),
        ]),
        const SizedBox(height: 6),
        _HistoryChipRow(
          lastSets: lastSets, isTimed: isTimed,
          prKg: prKg, prDurationSeconds: prDurationSeconds,
          expanded: historyExpanded, onToggle: onToggleHistory,
        ),
        const SizedBox(height: 8),
        for (int r = 0; r < rounds; r++)
          _RoundRowItem(
            roundIndex: r, isTimed: isTimed,
            isActive: isCurrentExercise && r == currentRound,
            isDone: r < currentRound || (!isCurrentExercise && r < setData.length &&
                (isTimed ? setData[r].durationSeconds > 0 : setData[r].reps > 0)),
            data: r < setData.length ? setData[r] : _SetData(weightKg: 0, reps: 0),
            referenceData: _refData(r),
            onChanged: isCurrentExercise && r == currentRound ? (d) => onSetDataChanged(r, d) : null,
          ),
        if (isCurrentExercise && onDoneSet != null) ...[
          const SizedBox(height: 10),
          if (isTimed)
            _TimedSetInput(
              running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
              target: te.repRangeMin, isCircuit: true,
              onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
            )
          else
            Center(child: _CheckCircleButton(
              key: ValueKey('circ-check-${te.exerciseId}-$currentRound'),
              onDone: onDoneSet!,
            )),
        ],
      ]),
    );
  }
}
```

- [ ] **Replace `_CircuitCard.build()` stub with full implementation**

```dart
@override
Widget build(BuildContext context) {
  const teal = Color(0xFF14B8A6);
  final isActive = cardState == _CardState.active && itemIndex == currentItemIdx;
  final isDone = cardState == _CardState.completed;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 280),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: isDone ? 0.04 : 0.07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isActive ? teal.withValues(alpha: 0.55) : isDone ? Colors.green.withValues(alpha: 0.25) : teal.withValues(alpha: 0.18),
        width: isActive ? 1.5 : 1.0,
      ),
      boxShadow: isActive ? [BoxShadow(color: teal.withValues(alpha: 0.12), blurRadius: 12)] : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Circuit header
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          const Icon(Icons.loop, size: 14, color: Color(0xFF14B8A6)),
          const SizedBox(width: 7),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              circuit.name != null && circuit.name!.isNotEmpty ? circuit.name! : 'Circuit',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
            ),
            Text(
              '${circuit.rounds} rounds · ${circuit.restBetweenRoundsSeconds}s rest between rounds',
              style: TextStyle(fontSize: 9, color: teal.withValues(alpha: 0.6)),
            ),
          ])),
          if (isDone) const _StatusBadge(label: '✓ DONE', color: Colors.green),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 18),
            onPressed: onShowCircuitActions,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
          ),
        ]),
      ),
      const Divider(height: 1, color: Color(0x1414B8A6)),

      // Per-exercise sections
      for (int exIdx = 0; exIdx < circuit.exercises.length; exIdx++) ...[
        _CircuitExerciseSection(
          exercise: circuit.exercises[exIdx],
          rounds: circuit.rounds,
          isCurrentExercise: isActive && exIdx == currentCircuitExIdx,
          currentRound: isActive ? currentSetIdx : -1,
          setData: setData[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
          lastSets: lastSets[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
          prKg: prData[circuit.exercises[exIdx].templateExercise.exerciseId],
          prDurationSeconds: prDurationData[circuit.exercises[exIdx].templateExercise.exerciseId],
          historyExpanded: historyExpanded[circuit.exercises[exIdx].templateExercise.exerciseId] ?? false,
          onToggleHistory: () => onToggleHistory(circuit.exercises[exIdx].templateExercise.exerciseId),
          onSetDataChanged: (r, d) => onSetDataChanged(circuit.exercises[exIdx].templateExercise.exerciseId, r, d),
          onDoneSet: isActive && exIdx == currentCircuitExIdx ? onDoneSet : null,
          onStartTimer: isActive && exIdx == currentCircuitExIdx ? onStartTimer : null,
          onStopTimer: isActive && exIdx == currentCircuitExIdx ? onStopTimer : null,
          onShowActions: () => onShowExerciseActions(exIdx),
          timedRunning: isActive && exIdx == currentCircuitExIdx ? timedRunning : false,
          timedElapsed: isActive && exIdx == currentCircuitExIdx ? timedElapsed : 0,
          timedStopped: isActive && exIdx == currentCircuitExIdx ? timedStopped : false,
        ),
        if (exIdx < circuit.exercises.length - 1)
          const Divider(height: 1, color: Color(0x08FFFFFF)),
      ],
      const SizedBox(height: 6),
    ]),
  );
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: implement _CircuitCard with per-exercise round rows"
```

---

### Task 6 — Exercise action sheet (`···` menu)

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_ActionTile` widget**

```dart
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
    );
  }
}
```

- [ ] **Replace `_showExerciseActions` stub with full implementation**

```dart
void _showExerciseActions(BuildContext context, int itemIdx) {
  final si = _sessionItems[itemIdx];
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          _ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
              onTap: () { Navigator.pop(ctx); _showSwapExerciseSheet(itemIdx); }),
          if (itemIdx > 0)
            _ActionTile(icon: Icons.arrow_upward, label: 'Move Up',
                onTap: () { Navigator.pop(ctx); _moveItemUp(itemIdx); }),
          if (itemIdx < _sessionItems.length - 1)
            _ActionTile(icon: Icons.arrow_downward, label: 'Move Down',
                onTap: () { Navigator.pop(ctx); _moveItemDown(itemIdx); }),
          _ActionTile(icon: Icons.skip_next, label: 'Skip Exercise',
              onTap: () { Navigator.pop(ctx); _skipExercise(itemIdx); }),
          if (si.isAdHoc)
            _ActionTile(icon: Icons.delete_outline, label: 'Remove', color: Colors.red.shade300,
                onTap: () { Navigator.pop(ctx); _removeAdHocItem(itemIdx); }),
          const SizedBox(height: 4),
        ]),
      ),
    ),
  );
}
```

- [ ] **Replace `_showCircuitExerciseActions` stub**

```dart
void _showCircuitExerciseActions(BuildContext context, int itemIdx, int exIdx) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          _ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
              onTap: () { Navigator.pop(ctx); _showSwapCircuitExerciseSheet(itemIdx, exIdx); }),
          const SizedBox(height: 4),
        ]),
      ),
    ),
  );
}
```

- [ ] **Add stub `_showSwapCircuitExerciseSheet` (implemented Task 10)**

```dart
void _showSwapCircuitExerciseSheet(int itemIdx, int exIdx) {}
void _showSwapExerciseSheet(int itemIdx) {} // implemented Task 10
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: exercise action sheet with swap/move/skip/remove options"
```

---

### Task 7 — Skip exercise, skip set, move up/down, remove ad-hoc

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Replace stub `_skipExercise()`**

```dart
void _skipExercise(int itemIdx) {
  setState(() {
    _sessionItems[itemIdx].skipped = true;
    if (itemIdx == _currentItemIdx) {
      int next = _currentItemIdx + 1;
      while (next < _sessionItems.length && _sessionItems[next].skipped) next++;
      if (next < _sessionItems.length) {
        _currentItemIdx = next;
        _currentSetIdx = 0;
        _circuitExerciseIdx = 0;
      }
    }
  });
  _restTimer?.cancel();
  setState(() { _resting = false; _restEndsAt = null; });
  _saveProgress();
  _updateNotification();
}
```

- [ ] **Replace stub `_skipSet()`**

```dart
void _skipSet(int itemIdx, int setIdx) {
  setState(() {
    _sessionItems[itemIdx].skippedSets.add(setIdx);
    if (itemIdx == _currentItemIdx && setIdx == _currentSetIdx) {
      final totalSets = switch (_sessionItems[itemIdx].wodItem) {
        StandaloneWodExercise(:final entry) => entry.templateExercise.targetSets,
        WodCircuit(:final rounds) => rounds,
      };
      final next = _nextNonSkippedSet(itemIdx, _currentSetIdx + 1, totalSets);
      if (next >= totalSets) {
        final nextItem = _currentItemIdx + 1;
        if (nextItem < _sessionItems.length) {
          _currentItemIdx = nextItem;
          _currentSetIdx = 0;
          _circuitExerciseIdx = 0;
        }
      } else {
        _currentSetIdx = next;
      }
    }
  });
  _saveProgress();
}
```

- [ ] **Add `_moveItemUp()`, `_moveItemDown()`, `_removeAdHocItem()`**

```dart
void _moveItemUp(int i) {
  if (i <= 0) return;
  setState(() {
    final tmp = _sessionItems[i];
    _sessionItems[i] = _sessionItems[i - 1];
    _sessionItems[i - 1] = tmp;
    if (_currentItemIdx == i) _currentItemIdx = i - 1;
    else if (_currentItemIdx == i - 1) _currentItemIdx = i;
  });
  _saveProgress();
}

void _moveItemDown(int i) {
  if (i >= _sessionItems.length - 1) return;
  setState(() {
    final tmp = _sessionItems[i];
    _sessionItems[i] = _sessionItems[i + 1];
    _sessionItems[i + 1] = tmp;
    if (_currentItemIdx == i) _currentItemIdx = i + 1;
    else if (_currentItemIdx == i + 1) _currentItemIdx = i;
  });
  _saveProgress();
}

void _removeAdHocItem(int i) {
  if (!_sessionItems[i].isAdHoc) return;
  setState(() {
    _sessionItems.removeAt(i);
    if (_currentItemIdx > i) _currentItemIdx--;
    _currentItemIdx = _currentItemIdx.clamp(0, (_sessionItems.length - 1).clamp(0, double.maxFinite.toInt()));
  });
  _saveProgress();
}
```

- [ ] **Update `_onDoneSet()` — advance past skipped sets in the `StandaloneWodExercise` branch**

In `_onDoneSet()`, find the `StandaloneWodExercise` case. Replace the `!isLastSet` increment:

```dart
// Replace:
if (!isLastSet) {
  _currentSetIdx++;
} else if (!isLastItem) {
  ...
}

// With:
if (!isLastSet) {
  final next = _nextNonSkippedSet(_currentItemIdx, _currentSetIdx + 1, targetSets);
  if (next < targetSets) {
    _currentSetIdx = next;
  } else if (!isLastItem) {
    _currentItemIdx++;
    _currentSetIdx = 0;
    _circuitExerciseIdx = 0;
  }
} else if (!isLastItem) {
  _currentItemIdx++;
  _currentSetIdx = 0;
  _circuitExerciseIdx = 0;
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: skip exercise/set, move up/down, remove ad-hoc, skip-aware advancement"
```

---

### Task 8 — Exercise library search sheet (shared by Add and Swap)

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_ExerciseLibrarySheet` widget**

`Exercise` fields: `id` (int), `name` (String), `isTimed` (bool), `category` (String), `notes` (String?).  
`ExercisesCompanion.insert(name: ..., isTimed: Value(false))` inserts a new exercise.

```dart
class _ExerciseLibrarySheet extends ConsumerStatefulWidget {
  final String title;
  final void Function(Exercise) onSelected;
  const _ExerciseLibrarySheet({required this.title, required this.onSelected});

  @override
  ConsumerState<_ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends ConsumerState<_ExerciseLibrarySheet> {
  String _query = '';
  List<Exercise> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).exercisesDao.getAllExercises().then((list) {
      if (mounted) setState(() { _all = list; _loading = false; });
    });
  }

  List<Exercise> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect(String name) async {
    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(name: name),
    );
    final created = Exercise(id: id, name: name, isTimed: false, category: 'Other', notes: null);
    if (mounted) widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showCreate = _query.isNotEmpty &&
        filtered.every((e) => e.name.toLowerCase() != _query.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(controller: scroll, children: [
                    if (showCreate)
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline, color: Colors.purple),
                        title: Text('Create "$_query"', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Add to exercise library'),
                        onTap: () => _createAndSelect(_query),
                      ),
                    for (final ex in filtered)
                      ListTile(
                        title: Text(ex.name),
                        subtitle: Text(ex.isTimed ? 'Timed' : 'Weighted',
                            style: const TextStyle(fontSize: 11)),
                        onTap: () => widget.onSelected(ex),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: exercise library search sheet with create-new support"
```

---

### Task 9 — Add Exercise flow

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Add `_ConfigStepper` widget**

```dart
class _ConfigStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;
  const _ConfigStepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(
        onPressed: value > min ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove, size: 16),
        style: IconButton.styleFrom(minimumSize: const Size(32, 32), backgroundColor: Colors.white.withValues(alpha: 0.07), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      IconButton(
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add, size: 16),
        style: IconButton.styleFrom(minimumSize: const Size(32, 32), backgroundColor: Colors.white.withValues(alpha: 0.07), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    ]),
  ]);
}
```

- [ ] **Replace `_showAddExerciseSheet` stub with full implementation**

```dart
void _showAddExerciseSheet(int insertAt) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseLibrarySheet(
      title: 'Add Exercise',
      onSelected: (exercise) { Navigator.pop(context); _showAddExerciseConfig(insertAt, exercise); },
    ),
  );
}

void _showAddExerciseConfig(int insertAt, Exercise exercise) {
  int sets = 3, repMin = 8, repMax = 12;
  showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(exercise.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Configure for this session', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _ConfigStepper(label: 'Sets', value: sets, min: 1, max: 10, onChanged: (v) => setM(() => sets = v))),
          const SizedBox(width: 12),
          Expanded(child: _ConfigStepper(label: 'Min reps', value: repMin, min: 1, max: 100, onChanged: (v) => setM(() => repMin = v))),
          const SizedBox(width: 12),
          Expanded(child: _ConfigStepper(label: 'Max reps', value: repMax, min: 1, max: 100, onChanged: (v) => setM(() => repMax = v))),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () { Navigator.pop(ctx); _insertAdHocExercise(insertAt, exercise, sets, repMin, repMax); },
          child: const Text('Add to Workout'),
        )),
      ]),
    )),
  );
}

void _insertAdHocExercise(int insertAt, Exercise exercise, int sets, int repMin, int repMax) {
  // Check the WodTemplateExercise data class constructor in app_database.g.dart
  // for exact field order. All fields below match the table definition.
  final fakeTe = WodTemplateExercise(
    id: -(DateTime.now().millisecondsSinceEpoch),
    wodTemplateId: widget.result.wodTemplate.id,
    exerciseId: exercise.id,
    sortOrder: insertAt,
    groupId: null,
    targetSets: sets,
    repRangeMin: repMin,
    repRangeMax: repMax,
    notes: null,
    restSeconds: null,
  );
  final entry = WodExerciseEntry(
    templateExercise: fakeTe,
    exercise: exercise,
    suggestion: WeightSuggestion.noHistory,
  );
  final si = _SessionItem(
    wodItem: StandaloneWodExercise(entry: entry, restSeconds: null),
    isAdHoc: true,
  );
  setState(() {
    _sessionItems.insert(insertAt, si);
    _setData[exercise.id] = List.generate(sets, (_) => _SetData(weightKg: 0, reps: 0));
    _lastSets[exercise.id] = [];
    _prData[exercise.id] = null;
    if (insertAt <= _currentItemIdx) _currentItemIdx++;
  });
  _saveProgress();
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: add exercise flow with library search, create-new, and config step"
```

---

### Task 10 — Swap Exercise (standalone and circuit)

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Replace `_showSwapExerciseSheet` stub and add `_swapExercise()` + `_loadExerciseHistory()`**

```dart
void _showSwapExerciseSheet(int itemIdx) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseLibrarySheet(
      title: 'Swap Exercise',
      onSelected: (exercise) { Navigator.pop(context); _swapExercise(itemIdx, exercise); },
    ),
  );
}

void _swapExercise(int itemIdx, Exercise exercise) {
  final original = _sessionItems[itemIdx].wodItem;
  if (original is! StandaloneWodExercise) return;

  final origEntry = original.entry;
  final fakeTe = WodTemplateExercise(
    id: -(DateTime.now().millisecondsSinceEpoch),
    wodTemplateId: widget.result.wodTemplate.id,
    exerciseId: exercise.id,
    sortOrder: itemIdx,
    groupId: null,
    targetSets: origEntry.templateExercise.targetSets,
    repRangeMin: origEntry.templateExercise.repRangeMin,
    repRangeMax: origEntry.templateExercise.repRangeMax,
    notes: null,
    restSeconds: original.restSeconds,
  );
  final newEntry = WodExerciseEntry(
    templateExercise: fakeTe, exercise: exercise, suggestion: WeightSuggestion.noHistory,
  );
  setState(() {
    _sessionItems[itemIdx] = _SessionItem(
      wodItem: StandaloneWodExercise(entry: newEntry, restSeconds: original.restSeconds),
      isAdHoc: true,
    );
    _setData[exercise.id] = List.generate(origEntry.templateExercise.targetSets, (_) => _SetData(weightKg: 0, reps: 0));
    _lastSets[exercise.id] = [];
    _prData[exercise.id] = null;
    if (itemIdx == _currentItemIdx) { _currentSetIdx = 0; _circuitExerciseIdx = 0; }
  });
  _loadExerciseHistory(exercise.id);
  _saveProgress();
}

Future<void> _loadExerciseHistory(int exerciseId) async {
  final db = ref.read(databaseProvider);
  final lastSets = await db.setsDao.getLastSetsForExerciseInWod(exerciseId, widget.result.wodTemplate.id);
  final pr = await db.setsDao.getPersonalRecord(exerciseId);
  if (mounted) setState(() { _lastSets[exerciseId] = lastSets; _prData[exerciseId] = pr; });
}
```

- [ ] **Replace `_showSwapCircuitExerciseSheet` stub**

```dart
void _showSwapCircuitExerciseSheet(int itemIdx, int exIdx) {
  showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseLibrarySheet(
      title: 'Swap Exercise',
      onSelected: (exercise) { Navigator.pop(context); _swapCircuitExercise(itemIdx, exIdx, exercise); },
    ),
  );
}

void _swapCircuitExercise(int itemIdx, int exIdx, Exercise newExercise) {
  final circuit = _sessionItems[itemIdx].wodItem as WodCircuit;
  final original = circuit.exercises[exIdx];
  final fakeTe = WodTemplateExercise(
    id: -(DateTime.now().millisecondsSinceEpoch),
    wodTemplateId: widget.result.wodTemplate.id,
    exerciseId: newExercise.id,
    sortOrder: exIdx,
    groupId: circuit.groupId,
    targetSets: circuit.rounds,
    repRangeMin: original.templateExercise.repRangeMin,
    repRangeMax: original.templateExercise.repRangeMax,
    notes: null,
    restSeconds: null,
  );
  final newEntry = WodExerciseEntry(
    templateExercise: fakeTe, exercise: newExercise, suggestion: WeightSuggestion.noHistory,
  );
  final newExercises = List<WodExerciseEntry>.from(circuit.exercises);
  newExercises[exIdx] = newEntry;
  final newCircuit = WodCircuit(
    groupId: circuit.groupId,
    name: circuit.name,
    rounds: circuit.rounds,
    restBetweenExercisesSeconds: circuit.restBetweenExercisesSeconds,
    restBetweenRoundsSeconds: circuit.restBetweenRoundsSeconds,
    exercises: newExercises,
  );
  setState(() {
    _sessionItems[itemIdx] = _SessionItem(wodItem: newCircuit, isAdHoc: _sessionItems[itemIdx].isAdHoc);
    _setData[newExercise.id] = List.generate(circuit.rounds, (_) => _SetData(weightKg: 0, reps: 0));
    _lastSets[newExercise.id] = [];
    _prData[newExercise.id] = null;
    if (itemIdx == _currentItemIdx && exIdx == _circuitExerciseIdx) {
      _currentSetIdx = 0;
    }
  });
  _loadExerciseHistory(newExercise.id);
  _saveProgress();
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: swap exercise (standalone and within circuit)"
```

---

### Task 11 — Update `_finish()` and `_saveProgress()` / `_resumeWorkout()`

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Update `_finish()` — iterate `_sessionItems` instead of `widget.result.allExercises`**

In `_finish()`, replace the `for (final entry in widget.result.allExercises)` loop with:

```dart
for (final si in _sessionItems) {
  if (si.skipped) continue;
  final entries = switch (si.wodItem) {
    StandaloneWodExercise(:final entry) => [(entry, si.skippedSets)],
    WodCircuit(:final exercises) => exercises.map((e) => (e, <int>{})).toList(),
  };
  for (final (entry, skippedSets) in entries) {
    final exerciseId = entry.templateExercise.exerciseId;
    final isTimed = entry.exercise.isTimed;
    final sets = _setData[exerciseId] ?? [];
    for (int i = 0; i < sets.length; i++) {
      if (skippedSets.contains(i)) continue;
      final s = sets[i];
      if (isTimed ? s.durationSeconds == 0 : s.reps == 0) continue;
      await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: i + 1,
        reps: isTimed ? 0 : s.reps,
        weightKg: s.weightKg,
        durationSeconds: isTimed ? Value(s.durationSeconds) : const Value.absent(),
      ));
    }
  }
}
```

- [ ] **Replace `_saveProgress()` body to persist session item order and skip state**

```dart
Future<void> _saveProgress() async {
  final prefs = await SharedPreferences.getInstance();
  final setsJson = <String, dynamic>{};
  for (final e in _setData.entries) {
    setsJson[e.key.toString()] = e.value.map((s) => {'w': s.weightKg, 'r': s.reps, 'd': s.durationSeconds}).toList();
  }
  final itemsJson = _sessionItems.map((si) => switch (si.wodItem) {
    StandaloneWodExercise(:final entry) => {
      'type': 'standalone',
      'exerciseId': entry.templateExercise.exerciseId,
      'isAdHoc': si.isAdHoc,
      'skipped': si.skipped,
      'skippedSets': si.skippedSets.toList(),
    },
    WodCircuit(:final groupId) => {
      'type': 'circuit',
      'groupId': groupId,
      'skipped': si.skipped,
    },
  }).toList();
  await prefs.setString(
    'workout_progress_${widget.result.wodTemplate.id}',
    jsonEncode({
      'itemIdx': _currentItemIdx,
      'setIdx': _currentSetIdx,
      'circuitExIdx': _circuitExerciseIdx,
      'sets': setsJson,
      'items': itemsJson,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    }),
  );
}
```

- [ ] **Update `_resumeWorkout()` to restore skip state**

After the existing `for (final entry in savedSets.entries)` loop that restores `_setData`, add:

```dart
final savedItems = data['items'] as List<dynamic>?;
if (savedItems != null && savedItems.length == _sessionItems.length) {
  for (int i = 0; i < savedItems.length; i++) {
    final m = savedItems[i] as Map<String, dynamic>;
    _sessionItems[i].skipped = m['skipped'] as bool? ?? false;
    final skippedSets = ((m['skippedSets'] as List<dynamic>?) ?? []).cast<int>();
    _sessionItems[i].skippedSets.addAll(skippedSets);
  }
}
```

Apply identical restoration in the `widget.autoResume` branch inside `_load()`.

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: update finish/save/restore for skipped sets, ad-hoc exercises, reordering"
```

---

### Task 12 — Text size polish and remove dead old widgets

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Increase font size in `_StepperField.build()` value text**

Find the `GestureDetector` child text in `_StepperField`:
```dart
// Change from:
style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
// To:
style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
```

- [ ] **Increase font size in `_SetRow.build()` set label**

In `_SetRow.build()`, the "Set N" `SizedBox` text:
```dart
// Change from fontSize implied by bodySmall to:
style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: ...),
```

- [ ] **Delete the now-unused old widgets**

Remove these classes entirely — they are replaced by `_ExerciseCard`, `_CircuitCard`, `_SetRowItem`:
- `_CurrentExerciseCard`
- `_CompletedExerciseTile`
- `_UpcomingExerciseTile`
- `_CompletedCircuitTile`
- `_UpcomingCircuitTile`
- `_ExerciseStats`
- `_StatChip`
- `_NextExerciseBanner` (if no longer used)

- [ ] **Final analyze — zero errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | tail -5
```
Expected: `No issues found!`

- [ ] **Final commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "polish: bigger text sizes, remove replaced legacy widgets"
```

---

## Self-Review

**Spec coverage:**
- ✅ Flat scrollable list, all cards expanded — Task 2
- ✅ Current card glow + badge — Task 3
- ✅ Completed/upcoming states — Task 3
- ✅ Per-set rows with active/done/future states — Task 3
- ✅ History chip (expandable inline) — Task 4
- ✅ Circuit with per-exercise round rows — Task 5
- ✅ `···` exercise actions sheet — Task 6
- ✅ Skip exercise — Task 7
- ✅ Skip set (long-press) — Task 7
- ✅ Move up / move down — Task 7
- ✅ Remove ad-hoc — Task 7
- ✅ Skip-aware set advancement — Task 7
- ✅ Exercise library search sheet — Task 8
- ✅ Create new exercise from search — Task 8
- ✅ Add exercise flow with config — Task 9
- ✅ Swap standalone exercise — Task 10
- ✅ Swap circuit exercise — Task 10
- ✅ Update `_finish()` for skipped sets and ad-hoc — Task 11
- ✅ Update save/restore for new state — Task 11
- ✅ Bigger text, old widgets removed — Task 12
