# Rest Timer Pill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the full-screen rest timer overlay with a compact floating pill at the top of the screen so users can interact with the workout list during rest.

**Architecture:** All changes are in a single file. The `_RestTimerOverlay` widget is deleted and replaced with a new `_RestPill` widget. In `build()`, an `AnimatedPositioned` + `AnimatedOpacity` keeps the pill always in the widget tree, sliding it above the viewport when not resting. The `ListView` top padding becomes conditional on `_resting`. The `bottomNavigationBar` always renders.

**Tech Stack:** Flutter, existing `_fmtSec` top-level helper already in the file.

---

## File Map

| File | Action |
|---|---|
| `lib/screens/log/active_session_screen.dart` | Delete `_RestTimerOverlay`, add `_RestPill`, update `build()` |

---

### Task 1 — Add `_RestPill` widget and delete `_RestTimerOverlay`

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Delete the entire `_RestTimerOverlay` class (lines 2063–2121)**

Remove from:
```dart
// ─── _RestTimerOverlay ────────────────────────────────────────────────────────
```
through to (and including) the closing `}` of the class.

- [ ] **Add `_RestPill` in its place at the same location in the file**

```dart
// ─── _RestPill ─────────────────────────────────────────────────────────────────

class _RestPill extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final String nextLabel;
  final VoidCallback onSkip;

  const _RestPill({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.nextLabel,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        SizedBox(
          width: 36, height: 36,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: Colors.white12,
              color: accent,
            ),
            Text(
              _fmtSec(secondsLeft),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nextLabel,
            style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next, size: 14),
          label: const Text('Skip', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 2 — Wire up `build()`: pill, bottom bar, ListView padding

**Files:** Modify `lib/screens/log/active_session_screen.dart`

- [ ] **Fix `bottomNavigationBar` — always show the Finish Workout button (line ~1100)**

Replace:
```dart
      bottomNavigationBar: _resting
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _saving || _loading ? null : _finish,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Finish Workout'),
                ),
              ),
            ),
```

With:
```dart
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _finish,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Finish Workout'),
          ),
        ),
      ),
```

- [ ] **Fix `ListView` top padding — add 64 px when resting (line ~1121)**

Replace:
```dart
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
```

With:
```dart
              padding: EdgeInsets.fromLTRB(16, _resting ? 72 : 8, 16, 24),
```

- [ ] **Replace the `_RestTimerOverlay` usage with an animated `_RestPill` (lines ~1189–1195)**

Replace:
```dart
          if (_resting && !_loading)
            _RestTimerOverlay(
              secondsLeft: _restSecondsLeft,
              totalSeconds: _restTotalSeconds,
              nextLabel: _getNextLabel(),
              onSkip: _skipRest,
            ),
```

With:
```dart
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            top: _resting && !_loading ? 8 : -80,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _resting && !_loading ? 1.0 : 0.0,
              child: _RestPill(
                secondsLeft: _restSecondsLeft,
                totalSeconds: _restTotalSeconds,
                nextLabel: _getNextLabel(),
                onSkip: _skipRest,
              ),
            ),
          ),
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

- [ ] **Build to confirm no compile errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter build apk --debug 2>&1 | tail -5
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/log/active_session_screen.dart && git commit -m "feat: replace full-screen rest overlay with floating pill — workout list stays interactive during rest"
```
