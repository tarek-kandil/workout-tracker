# PR Celebration + Coaching Notes & RPE Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a PR celebration overlay, coaching notes bottom sheet, target RPE badge, and post-set RPE logging to the active session screen.

**Architecture:** No schema changes needed — `targetRpe` and `notes` already exist on `wod_template_exercises` (added in schema v11). `_SetData` gains a `rpe` field that is saved via `_finish()`. `_onDoneSet` becomes async to sequentially show the PR overlay then the RPE sheet before starting the rest timer.

**Tech Stack:** Flutter, Drift ORM, audioplayers package, existing `celebration_overlay.dart` pattern (Overlay + Completer).

---

## File Map

| File | Change |
|---|---|
| `lib/screens/log/active_session_screen.dart` | Add `rpe` to `_SetData`; make `_onDoneSet` async; add `_checkPrAndUpdate`, `_bestRepsAtPrWeight`, `_playPrChime`, `_showRpeSheet`, `_RpeSheet`; update `_finish()`; add ℹ icon + coaching notes sheet + target RPE badge to `_ExerciseCard` |
| `lib/widgets/celebration_overlay.dart` | Add `showPrOverlay` + `_PrOverlay` widget |

---

## Task 1: Add `rpe` to `_SetData` and save it in `_finish()`

**Files:**
- Modify: `lib/screens/log/active_session_screen.dart`

- [ ] **Step 1: Add `rpe` field to `_SetData`**

Find the `_SetData` class (line ~25) and replace it:

```dart
class _SetData {
  double weightKg;
  int reps;
  int durationSeconds;
  double? rpe;
  _SetData({required this.weightKg, required this.reps, this.durationSeconds = 0, this.rpe});
}
```

- [ ] **Step 2: Update `_finish()` to save RPE**

In `_finish()` find the `db.setsDao.insertSet(WorkoutSetsCompanion.insert(...)` call (line ~766) and add the `rpe` field:

```dart
await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
  sessionId: sessionId,
  exerciseId: exerciseId,
  setNumber: i + 1,
  reps: isTimed ? 0 : s.reps,
  weightKg: s.weightKg,
  rpe: Value(s.rpe),
  durationSeconds: isTimed ? Value(s.durationSeconds) : const Value.absent(),
));
```

- [ ] **Step 3: Verify the app compiles**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/screens/log/active_session_screen.dart
```

Expected: no errors (the `rpe` column already exists on `WorkoutSets`).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/log/active_session_screen.dart
git commit -m "feat: add rpe field to _SetData and persist it in _finish()"
```

---

## Task 2: Add `showPrOverlay` to `celebration_overlay.dart`

**Files:**
- Modify: `lib/widgets/celebration_overlay.dart`

- [ ] **Step 1: Add `showPrOverlay` function and `_PrOverlay` widget**

Append to the end of `lib/widgets/celebration_overlay.dart`:

```dart
// ─── PR overlay ───────────────────────────────────────────────────────────────

/// Animated overlay card shown when a new personal record is logged.
/// Returns when the overlay has dismissed itself (tap or 3-second auto-dismiss).
Future<void> showPrOverlay(
  BuildContext context, {
  required String exerciseName,
  required double newWeightKg,
  required int reps,
  double? oldWeightKg,
}) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PrOverlay(
      exerciseName: exerciseName,
      newWeightKg: newWeightKg,
      reps: reps,
      oldWeightKg: oldWeightKg,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _PrOverlay extends StatefulWidget {
  final String exerciseName;
  final double newWeightKg;
  final int reps;
  final double? oldWeightKg;
  final VoidCallback onDone;
  const _PrOverlay({
    required this.exerciseName,
    required this.newWeightKg,
    required this.reps,
    required this.oldWeightKg,
    required this.onDone,
  });
  @override
  State<_PrOverlay> createState() => _PrOverlayState();
}

class _PrOverlayState extends State<_PrOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: const ElasticOutCurve(0.7));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _autoTimer = Timer(const Duration(seconds: 3), widget.onDone);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtW(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final delta = widget.oldWeightKg != null && widget.oldWeightKg! > 0
        ? widget.newWeightKg - widget.oldWeightKg!
        : null;

    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (_, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.72 * _fade.value),
          child: child,
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: GestureDetector(
              onTap: () {}, // absorb taps on the card so backdrop tap still works
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1e1b4b), Color(0xFF1a1a2e)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Radial glow + trophy
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFBBF24).withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 36, decoration: TextDecoration.none)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NEW PR!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD700),
                        letterSpacing: 0.05,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmtW(widget.newWeightKg)} kg',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (delta != null && delta > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '↑ +${_fmtW(delta)} kg from ${_fmtW(widget.oldWeightKg!)} kg',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.45),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${widget.exerciseName} · ${widget.reps} reps',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: widget.onDone,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Crush it! 💪',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/widgets/celebration_overlay.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/celebration_overlay.dart
git commit -m "feat: add showPrOverlay celebration overlay"
```

---

## Task 3: Async `_onDoneSet` with PR check + RPE sheet

**Files:**
- Modify: `lib/screens/log/active_session_screen.dart`

This is the largest change. `_onDoneSet` becomes `Future<void>` and gains PR detection and RPE logging, while preserving all existing advance/rest logic.

- [ ] **Step 1: Add helper methods above `_onDoneSet`**

Insert these four methods immediately before `_onDoneSet` (line ~361):

```dart
// ── PR helpers ────────────────────────────────────────────────────────────────

int _bestRepsAtPrWeight(int exerciseId) {
  final pr = _prData[exerciseId];
  if (pr == null || pr == 0) return 0;
  final sets = _lastSets[exerciseId] ?? [];
  return sets
      .where((s) => s.weightKg == pr)
      .map((s) => s.reps)
      .fold(0, (best, r) => r > best ? r : best);
}

/// Returns true if this set is a new PR; updates _prData when it is.
bool _checkPrAndUpdate(int exerciseId, double weightKg, int reps) {
  final currentPr = _prData[exerciseId] ?? 0.0;
  final isNewWeight = weightKg > currentPr;
  final isMoreReps = weightKg == currentPr && reps > _bestRepsAtPrWeight(exerciseId);
  if (isNewWeight) _prData[exerciseId] = weightKg;
  return isNewWeight || isMoreReps;
}

Future<void> _playPrChime() async {
  HapticFeedback.heavyImpact();
  await _sfxPlayer.play(BytesSource(_makeBeepWav(hz: 660, ms: 150)));
  await Future.delayed(const Duration(milliseconds: 200));
  await _sfxPlayer.play(BytesSource(_makeBeepWav(hz: 880, ms: 150)));
  await Future.delayed(const Duration(milliseconds: 200));
  await _sfxPlayer.play(BytesSource(_makeBeepWav(hz: 1100, ms: 200)));
}

Future<double?> _showRpeSheet(String exerciseName, int setNumber) {
  return showModalBottomSheet<double>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RpeSheet(exerciseName: exerciseName, setNumber: setNumber),
  );
}
```

- [ ] **Step 2: Replace `_onDoneSet` with the async version**

Replace the entire `void _onDoneSet()` method with:

```dart
Future<void> _onDoneSet() async {
  // ── Capture BEFORE state mutation ────────────────────────────────────────
  final entry = _currentEntry;
  final exerciseId = entry.templateExercise.exerciseId;
  final capturedSetIdx = _currentSetIdx;
  final capturedSetNumber = capturedSetIdx + 1;
  final capturedName = entry.exercise.name;
  final isTimed = entry.exercise.isTimed;
  final loggedData = _setData[exerciseId]?[capturedSetIdx];

  // ── Existing advance logic (unchanged) ───────────────────────────────────
  final item = _sessionItems[_currentItemIdx].wodItem;
  final isLastItem = _currentItemIdx >= _sessionItems.length - 1;
  bool startRestAfter = true;
  int restDuration = widget.result.wodTemplate.restSeconds;
  bool needAutoStart = false;

  switch (item) {
    case StandaloneWodExercise(:final entry, :final restSeconds):
      final targetSets = entry.templateExercise.targetSets;
      final isLastSet = _currentSetIdx >= targetSets - 1;
      setState(() {
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
        _timedRunning = false;
        _timedStopped = false;
        _timedElapsed = 0;
        _exerciseTicker?.cancel();
      });
      if (isLastSet && isLastItem) {
        startRestAfter = false;
        _allExercisesDone = true;
      }
      restDuration = restSeconds ?? widget.result.wodTemplate.restSeconds;

    case WodCircuit():
      final circuit = item;
      final isLastInRound = _circuitExerciseIdx >= circuit.exercises.length - 1;
      final isLastRound = _currentSetIdx >= circuit.rounds - 1;
      setState(() {
        _timedRunning = false;
        _timedStopped = false;
        _timedElapsed = 0;
        _exerciseTicker?.cancel();
        if (!isLastInRound) {
          _circuitExerciseIdx++;
        } else if (!isLastRound) {
          _circuitExerciseIdx = 0;
          _currentSetIdx++;
        } else {
          _circuitExerciseIdx = 0;
          _currentSetIdx = 0;
          if (!isLastItem) _currentItemIdx++;
        }
      });
      final circuitDone = isLastInRound && isLastRound;
      if (circuitDone && isLastItem) {
        startRestAfter = false;
      } else if (!isLastInRound) {
        restDuration = circuit.restBetweenExercisesSeconds;
        if (restDuration == 0) startRestAfter = false;
      } else if (!isLastRound) {
        restDuration = circuit.restBetweenRoundsSeconds;
      }
      if (!startRestAfter && (!circuitDone || !isLastItem)) needAutoStart = true;
  }

  // ── PR overlay (non-timed only) ──────────────────────────────────────────
  if (!isTimed && loggedData != null && loggedData.reps > 0 && mounted) {
    final oldPrKg = _prData[exerciseId];
    if (_checkPrAndUpdate(exerciseId, loggedData.weightKg, loggedData.reps)) {
      await _playPrChime();
      if (mounted) {
        await showPrOverlay(
          context,
          exerciseName: capturedName,
          newWeightKg: loggedData.weightKg,
          reps: loggedData.reps,
          oldWeightKg: oldPrKg,
        );
      }
    }
  }

  // ── RPE sheet (non-timed only) ───────────────────────────────────────────
  if (!isTimed && loggedData != null && loggedData.reps > 0 && mounted) {
    final rpe = await _showRpeSheet(capturedName, capturedSetNumber);
    if (rpe != null && mounted) {
      setState(() {
        _setData[exerciseId]![capturedSetIdx] = _SetData(
          weightKg: loggedData.weightKg,
          reps: loggedData.reps,
          rpe: rpe,
        );
      });
    }
  }

  // ── Persist + rest ───────────────────────────────────────────────────────
  if (!mounted) return;
  _saveProgress();
  _updateNotification();
  if (startRestAfter) {
    _startRest(restDuration);
  } else if (needAutoStart) {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _maybeAutoStartCountdown();
    });
  }
}
```

- [ ] **Step 3: Add `_RpeSheet` widget at the bottom of the file**

Append before the final closing brace of the file (after the last widget class):

```dart
// ─── _RpeSheet ────────────────────────────────────────────────────────────────

class _RpeSheet extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  const _RpeSheet({required this.exerciseName, required this.setNumber});
  @override
  State<_RpeSheet> createState() => _RpeSheetState();
}

class _RpeSheetState extends State<_RpeSheet> {
  double? _selected;

  static const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];
  static const _rpeLabels = {
    6.0: 'Very easy',
    6.5: 'Easy',
    7.0: 'Moderate',
    7.5: 'Somewhat hard',
    8.0: 'Hard, 2–3 reps left',
    8.5: 'Very hard, 1–2 reps left',
    9.0: '1 rep left',
    9.5: 'Could not do more reps',
    10.0: 'Max effort',
  };

  void _select(double rpe) {
    setState(() => _selected = rpe);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(rpe);
    });
  }

  String _label(double rpe) =>
      rpe == rpe.truncateToDouble() ? rpe.toInt().toString() : rpe.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e2030),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('How hard was that?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Set ${widget.setNumber} · ${widget.exerciseName} · optional',
              style: TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: _rpeValues.map((rpe) {
              final isSelected = _selected == rpe;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _select(rpe),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFBBF24)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _label(rpe),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected == null
                ? Text(
                    'Tap to log · swipe down to skip',
                    key: const ValueKey('hint'),
                    style: const TextStyle(fontSize: 9, color: Colors.white24),
                  )
                : Container(
                    key: ValueKey(_selected),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_rpeLabels[_selected] ?? '',
                            style: TextStyle(fontSize: 10, color: Colors.white54)),
                        Text(
                          'RPE ${_label(_selected!)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/screens/log/active_session_screen.dart
```

Expected: no errors. If you see "The method '_onDoneSet' has return type 'Future<void>' but the return is 'void'" — that just means some call site needs `unawaited()` or `// ignore`. Callers that don't await fire-and-forget, which is acceptable.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/log/active_session_screen.dart
git commit -m "feat: async _onDoneSet with PR overlay and post-set RPE sheet"
```

---

## Task 4: ℹ Coaching Notes icon + Target RPE badge

**Files:**
- Modify: `lib/screens/log/active_session_screen.dart`

- [ ] **Step 1: Add `_showCoachingNotes` function inside `_ExerciseCard`**

`_ExerciseCard` is a `StatelessWidget`. Add this static helper method to it (inside the class, before `build`):

```dart
static void _showCoachingNotes(
    BuildContext context, WodExerciseEntry entry, WodTemplateExercise te) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e2030),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(entry.exercise.name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          const Text('Coaching Notes',
              style: TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              te.notes!,
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.5),
            ),
          ),
          if (te.targetRpe != null) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Target RPE',
                    style: TextStyle(fontSize: 11, color: Colors.white38)),
                Text(
                  te.targetRpe! == te.targetRpe!.truncateToDouble()
                      ? te.targetRpe!.toInt().toString()
                      : te.targetRpe!.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFBBF24)),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Add the ℹ icon button to `_ExerciseCard.build()`**

In `_ExerciseCard.build()`, find the right-column `Column` (around line ~1586):

```dart
Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
  IconButton(
    icon: const Icon(Icons.more_horiz, size: 20),
    onPressed: onShowActions,
    ...
  ),
  if (!isTimed) _SuggestionBadge(suggestion: entry.suggestion),
]),
```

Replace it with:

```dart
Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (te.notes != null && te.notes!.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          onPressed: () => _showCoachingNotes(context, entry, te),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Colors.white38,
          ),
        ),
      IconButton(
        icon: const Icon(Icons.more_horiz, size: 20),
        onPressed: onShowActions,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Colors.white38,
        ),
      ),
    ],
  ),
  if (!isTimed) _SuggestionBadge(suggestion: entry.suggestion),
]),
```

- [ ] **Step 3: Add the Target RPE badge above the active set row**

In `_ExerciseCard.build()`, find the set rows section (the `List.generate` for sets, around line ~1605). Just before `...List.generate(...)`, add:

```dart
if (isActive && te.targetRpe != null) ...[
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'Set ${currentSetIdx + 1} / ${te.targetSets}',
        style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Target RPE ${te.targetRpe! == te.targetRpe!.truncateToDouble() ? te.targetRpe!.toInt() : te.targetRpe!.toStringAsFixed(1)}',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFBBF24),
          ),
        ),
      ),
    ],
  ),
  const SizedBox(height: 6),
],
```

- [ ] **Step 4: Verify it compiles**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze lib/screens/log/active_session_screen.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/log/active_session_screen.dart
git commit -m "feat: coaching notes info icon and target RPE badge in exercise card"
```

---

## Self-Review Checklist

- [x] `rpe` field on `_SetData` and saved in `_finish()` — Task 1
- [x] `showPrOverlay` with gold card, elastic animation, auto-dismiss 3s, backdrop tap — Task 2
- [x] PR triggers: new max weight OR more reps at current PR — Task 3 `_checkPrAndUpdate`
- [x] 3-note ascending chime before overlay — Task 3 `_playPrChime`
- [x] RPE sheet after every Done Set (non-timed), returns `double?`, swipe/tap to skip — Task 3 `_RpeSheet`
- [x] RPE stored back into `_setData` for the correct set index — Task 3
- [x] Rest timer starts AFTER both sheets dismissed — Task 3 (epilogue at end of `_onDoneSet`)
- [x] ℹ icon only when `te.notes != null && te.notes!.isNotEmpty` — Task 4
- [x] Coaching notes sheet shows notes + target RPE — Task 4
- [x] Target RPE badge only when `te.targetRpe != null`, only on active card — Task 4
- [x] No schema changes needed — `targetRpe` was added in schema v11
