# Program Setup — WOD Card & Rest Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "Edit Workouts" button with per-card touch zones (name → rename, exercises → edit), and split the single rest field into independent "between sets" and "after exercise" overrides per exercise.

**Architecture:** DB schema v12 adds one nullable column. The `_WodTile` widget converts to `ConsumerStatefulWidget` to hold rename state. The exercise edit dialog gains a second rest stepper. The WOD-level "Xs rest" app bar button is removed entirely.

**Tech Stack:** Flutter, Riverpod (ConsumerStatefulWidget), Drift ORM, build_runner for code generation.

---

## File Map

| File | Change |
|---|---|
| `lib/database/tables/wod_template_exercises_table.dart` | Add `restBetweenSetsSeconds` nullable int column |
| `lib/database/app_database.dart` | Bump `schemaVersion` 11 → 12, add guarded migration |
| `lib/screens/settings/program_setup_screen.dart` | `_WodTile` → `ConsumerStatefulWidget`; in-place rename; exercises zone tap; remove "Edit Workouts" button |
| `lib/screens/settings/wod_exercise_setup_screen.dart` | Remove app bar rest button + `_editRestTime`; split rest dialog; rest pills on tile |

---

## Task 1: DB Column + Migration (schema v12)

**Files:**
- Modify: `lib/database/tables/wod_template_exercises_table.dart`
- Modify: `lib/database/app_database.dart`

- [ ] **Step 1: Add column to table class**

In `lib/database/tables/wod_template_exercises_table.dart`, add the new column after `restSeconds`:

```dart
class WodTemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wodTemplateId => integer().references(WodTemplates, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get groupId =>
      integer().nullable().references(WodExerciseGroups, #id)();
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get repRangeMin => integer().withDefault(const Constant(6))();
  IntColumn get repRangeMax => integer().withDefault(const Constant(12))();
  TextColumn get notes => text().nullable()();
  // null = use default (90 s). Standalone only.
  IntColumn get restSeconds => integer().nullable()();
  // null = use default (90 s). Between sets of the same exercise. Standalone only.
  IntColumn get restBetweenSetsSeconds => integer().nullable()();
  RealColumn get targetRpe => real().nullable()();
  TextColumn get videoUrl => text().nullable()();
}
```

- [ ] **Step 2: Bump schema version and add migration**

In `lib/database/app_database.dart`, change `schemaVersion` to 12 and add the migration block after the `from < 11` block:

```dart
@override
int get schemaVersion => 12;
```

In the `onUpgrade` body, after the existing `if (from < 11)` block, add:

```dart
if (from < 12) {
  final cols = await customSelect(
    'PRAGMA table_info(wod_template_exercises)',
  ).get();
  final hasCol = cols.any(
    (r) => r.read<String>('name') == 'rest_between_sets_seconds',
  );
  if (!hasCol) {
    await m.addColumn(
      wodTemplateExercises,
      wodTemplateExercises.restBetweenSetsSeconds,
    );
  }
}
```

- [ ] **Step 3: Run build_runner**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter pub run build_runner build --delete-conflicting-outputs 2>&1 | tail -5
```

Expected: ends with something like `[INFO] Succeeded after Xs. (N outputs)`

- [ ] **Step 4: Run flutter analyze — expect zero new issues**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze 2>&1
```

Expected: same pre-existing infos as before, no new errors or warnings in our files.

- [ ] **Step 5: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/database/tables/wod_template_exercises_table.dart \
        lib/database/app_database.dart \
        lib/database/app_database.g.dart
git commit -m "feat: schema v12 — add rest_between_sets_seconds to wod_template_exercises"
```

---

## Task 2: Program Setup Screen — WOD Tile Redesign

**Files:**
- Modify: `lib/screens/settings/program_setup_screen.dart`

### Context

`_WodList` (lines ~418–514) renders a `ReorderableListView` of `_WodTile` widgets. It currently:
- Has a "Edit Workouts" `TextButton.icon` in its parent's header row (line ~354–365 in `_ProgramSetupScreenState.build`)
- Passes `readOnly` and `dragIndex` to `_WodTile`

`_WodTile` (lines ~521–1000) is currently a `ConsumerWidget`. The full card is wrapped in an `InkWell` that navigates to `WodExerciseSetupScreen`.

### Changes

- [ ] **Step 1: Remove "Edit Workouts" button from program screen header**

In `_ProgramSetupScreenState.build`, find the `Row` that contains the "Workouts" title. Remove the `TextButton.icon` (`Edit Workouts`). The row becomes:

```dart
// ── Workouts section ───────────────────────────────────────────────
Row(
  children: [
    Text('Workouts',
        style: Theme.of(context).textTheme.titleMedium),
  ],
),
```

- [ ] **Step 2: Add `phaseId` parameter to `_WodTile` and update `_WodList` call site**

Add `phaseId` to `_WodTile`'s constructor. In `_WodListState.build`, pass it:

```dart
_WodTile(
  key: ValueKey(wods[i].id),
  wod: wods[i],
  phaseId: widget.phaseId,   // ← add this
  readOnly: widget.readOnly,
  dragIndex: widget.readOnly ? null : i,
),
```

- [ ] **Step 3: Convert `_WodTile` to `ConsumerStatefulWidget`**

Replace the class declaration and add state:

```dart
class _WodTile extends ConsumerStatefulWidget {
  final WodTemplate wod;
  final int phaseId;
  final bool readOnly;
  final int? dragIndex;
  const _WodTile({
    super.key,
    required this.wod,
    required this.phaseId,
    required this.readOnly,
    this.dragIndex,
  });

  @override
  ConsumerState<_WodTile> createState() => _WodTileState();
}

class _WodTileState extends ConsumerState<_WodTile> {
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wod.name);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _saveName();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      _nameCtrl.text = widget.wod.name;
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    await ref.read(databaseProvider).programsDao.updateWodTemplate(
      WodTemplatesCompanion(
        id: Value(widget.wod.id),
        phaseId: Value(widget.wod.phaseId),
        wodNumber: Value(widget.wod.wodNumber),
        name: Value(newName),
        notes: Value(widget.wod.notes),
      ),
    );
    ref.invalidate(wodTemplatesForPhaseProvider(widget.phaseId));
  }

  @override
  Widget build(BuildContext context) {
    // All existing ref.watch calls move here unchanged — ref is available
    // as a field of ConsumerState, no need for the (context, ref) signature.
    final templateExercisesAsync =
        ref.watch(wodTemplateExercisesProvider(widget.wod.id));
    final circuitGroupsAsync = ref.watch(wodCircuitGroupsProvider(widget.wod.id));
    final allExercisesAsync = ref.watch(exercisesProvider);
    // ... rest of build unchanged until the card assembly ...
  }
}
```

- [ ] **Step 4: Replace the card's header row and wrap exercises zone**

Inside `_WodTileState.build`, replace the `inner` container's `Column` children with the new layout:

**Header row** — name zone (tappable when not readOnly) + pencil indicator + drag handle unchanged:

```dart
// ── Header row ──────────────────────────────────────────────
Padding(
  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
  child: Row(
    children: [
      // Drag handle
      if (widget.dragIndex != null) ...[
        ReorderableDragStartListener(
          index: widget.dragIndex!,
          child: Icon(
            Icons.drag_handle,
            size: 18,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(width: 8),
      ],
      // Numbered badge
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.28),
          ),
        ),
        child: Center(
          child: Text(
            '${widget.wod.wodNumber}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF818CF8),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Name zone
      Expanded(
        child: !widget.readOnly
            ? GestureDetector(
                onTap: () {
                  setState(() => _editing = true);
                  Future.microtask(() => _focusNode.requestFocus());
                },
                child: _editing
                    ? TextField(
                        controller: _nameCtrl,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _saveName(),
                      )
                    : Text(
                        widget.wod.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
              )
            : Text(
                widget.wod.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
      ),
      // Pencil indicator (visual only — no onTap)
      if (!widget.readOnly) ...[
        const SizedBox(width: 6),
        const Icon(
          Icons.edit_outlined,
          size: 15,
          color: Color.fromRGBO(99, 102, 241, 0.4),
        ),
      ],
    ],
  ),
),
```

**Card border** — highlight when editing name:

```dart
// In the inner Container's decoration:
decoration: BoxDecoration(
  color: Colors.white.withValues(alpha: 0.06),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(
    color: _editing
        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.09),
  ),
),
```

**Exercises zone** — wrap the exercise rows `Padding` in an `InkWell` (non-readOnly only):

```dart
// Replace the existing exercise-rows Padding with:
if (!widget.readOnly && (hasExercises || isEmpty))
  InkWell(
    onTap: () => Navigator.of(context).push(
      glassRoute(WodExerciseSetupScreen(wodTemplateId: widget.wod.id)),
    ),
    borderRadius: const BorderRadius.vertical(
      bottom: Radius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: isEmpty
          ? Text(
              'No exercises — tap to add',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int idx = 0; idx < wodLevelItems.length; idx++) ...[
                  if (idx > 0) const SizedBox(height: 4),
                  _buildWodItem(context, wodLevelItems[idx], exerciseMap, circuitExMap),
                ],
              ],
            ),
    ),
  )
else if (widget.readOnly && hasExercises)
  Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int idx = 0; idx < wodLevelItems.length; idx++) ...[
          if (idx > 0) const SizedBox(height: 4),
          _buildWodItem(context, wodLevelItems[idx], exerciseMap, circuitExMap),
        ],
      ],
    ),
  )
else if (isLoading)
  const Padding(
    padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: SizedBox(height: 2, child: LinearProgressIndicator()),
  )
else if (widget.readOnly && isEmpty)
  Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: Text(
      'No exercises',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.28),
          ),
    ),
  ),
```

**Remove the outer `InkWell`** that previously wrapped the whole card:

```dart
// The return statement becomes just:
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: inner,   // no Material/InkWell wrapper
);
```

- [ ] **Step 5: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze 2>&1
```

Expected: no new errors or warnings in `program_setup_screen.dart`.

- [ ] **Step 6: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/screens/settings/program_setup_screen.dart
git commit -m "feat: WOD card — pencil indicator, in-place rename, exercises zone tap"
```

---

## Task 3: Exercise Setup Screen — Rest Restructure

**Files:**
- Modify: `lib/screens/settings/wod_exercise_setup_screen.dart`

### Context

Current state in this file:
- `_WodExerciseSetupScreenState` holds `_restSeconds` (WOD-level default, int)
- `_editRestTime()` method edits that value via a dialog
- The AppBar action shows "⏱ Xs rest" and calls `_editRestTime()`
- `_StandaloneExerciseTile` receives `defaultRestSeconds`
- `_EditExerciseDialog` receives `defaultRestSeconds` and has a single `_RestStepper` labeled "REST AFTER THIS EXERCISE"
- `_ExerciseConfig` has `restSeconds: int`

### Changes

- [ ] **Step 1: Remove WOD-level rest state and app bar button**

In `_WodExerciseSetupScreenState`:

1. Delete the `int _restSeconds = 90;` field declaration.
2. Delete `_restSeconds = wodResult?.restSeconds ?? 90;` in `_load()`.
3. Delete the entire `_editRestTime()` method (lines ~88–125).
4. In `build`, remove the `AppBar` `actions` list entirely (the `if (!_loading) TextButton.icon(...)` block). The AppBar becomes:

```dart
appBar: AppBar(
  title: Text(_wodName),
),
```

5. In the call to `_StandaloneExerciseTile`, remove `defaultRestSeconds: _restSeconds`. The constructor call becomes:

```dart
return _StandaloneExerciseTile(
  key: ValueKey('s-${item.exercise.id}'),
  templateExercise: item.exercise,
  exercise: exercise,
  dragIndex: i,
  onEdit: () => _editEntry(item.exercise, exercise),
  onDelete: () => _deleteEntry(item.exercise),
);
```

6. In `_editEntry()`, the call to `_EditExerciseDialog` — remove `defaultRestSeconds`:

```dart
final result = await showDialog<_ExerciseConfig>(
  context: context,
  builder: (ctx) => _EditExerciseDialog(
    entry: entry,
    exercise: exercise,
    inCircuit: inCircuit,
  ),
);
```

- [ ] **Step 2: Add `restBetweenSetsSeconds` to `_ExerciseConfig`**

```dart
class _ExerciseConfig {
  final int sets;
  final int repMin;
  final int repMax;
  final String notes;
  final bool isTimed;
  final int? restBetweenSetsSeconds;  // null = default (90 s)
  final int? restAfterExerciseSeconds; // null = default (90 s), 0 = no rest
  final double? targetRpe;
  final String? videoUrl;
  const _ExerciseConfig({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.notes,
    required this.isTimed,
    this.restBetweenSetsSeconds,
    this.restAfterExerciseSeconds,
    this.targetRpe,
    this.videoUrl,
  });
}
```

- [ ] **Step 3: Update `_editEntry` to save both rest values**

In `_editEntry()`, replace the `updateWodTemplateExercise` call's rest fields:

```dart
await ref.read(databaseProvider).programsDao.updateWodTemplateExercise(
  WodTemplateExercisesCompanion(
    id: Value(entry.id),
    wodTemplateId: Value(entry.wodTemplateId),
    exerciseId: Value(entry.exerciseId),
    groupId: Value(entry.groupId),
    sortOrder: Value(entry.sortOrder),
    targetSets: Value(result.sets),
    repRangeMin: Value(result.repMin),
    repRangeMax: Value(result.repMax),
    notes: Value(result.notes.isEmpty ? null : result.notes),
    restSeconds: Value(result.restAfterExerciseSeconds),
    restBetweenSetsSeconds: Value(result.restBetweenSetsSeconds),
    targetRpe: Value(result.targetRpe),
    videoUrl: Value(result.videoUrl?.isEmpty == true ? null : result.videoUrl),
  ),
);
```

- [ ] **Step 4: Update `_StandaloneExerciseTile` — remove `defaultRestSeconds`, add rest pills**

Remove the `defaultRestSeconds` field from `_StandaloneExerciseTile`:

```dart
class _StandaloneExerciseTile extends StatelessWidget {
  final WodTemplateExercise templateExercise;
  final Exercise exercise;
  final int dragIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StandaloneExerciseTile({
    super.key,
    required this.templateExercise,
    required this.exercise,
    required this.dragIndex,
    required this.onEdit,
    required this.onDelete,
  });
  // ...
}
```

In the meta row (inside `build`), add rest pills after the RPE pill. Show a pill only when the value is not null (an explicit override):

```dart
// After the existing _RpePill block:
if (te.restBetweenSetsSeconds != null) ...[
  const SizedBox(width: 5),
  _RestPill(
    label: '${_fmtSec(te.restBetweenSetsSeconds!)} sets',
  ),
],
if (te.restSeconds != null) ...[
  const SizedBox(width: 5),
  _RestPill(
    label: te.restSeconds == 0
        ? 'no rest after'
        : '${_fmtSec(te.restSeconds!)} after',
  ),
],
```

Add the `_RestPill` widget at the bottom of the file (alongside `_RepsPill`, `_RpePill`):

```dart
class _RestPill extends StatelessWidget {
  final String label;
  const _RestPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF34D399).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF34D399).withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color.fromRGBO(52, 211, 153, 0.7),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `_EditExerciseDialog` — remove `defaultRestSeconds`, add two rest steppers**

Remove `defaultRestSeconds` from the widget:

```dart
class _EditExerciseDialog extends StatefulWidget {
  final WodTemplateExercise entry;
  final Exercise exercise;
  final bool inCircuit;
  const _EditExerciseDialog({
    required this.entry,
    required this.exercise,
    this.inCircuit = false,
  });

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}
```

In `_EditExerciseDialogState`, replace the single `_restSeconds` with two fields:

```dart
// Remove: late int _restSeconds;
late int _restBetweenSets;     // display value — always 90 when null in DB
late int _restAfterExercise;   // display value — always 90 when null in DB
```

In `initState`, initialise from DB (null → 90):

```dart
// Remove: _restSeconds = widget.entry.restSeconds ?? widget.defaultRestSeconds;
_restBetweenSets = widget.entry.restBetweenSetsSeconds ?? 90;
_restAfterExercise = widget.entry.restSeconds ?? 90;
```

In `_onSave`, replace the single rest field:

```dart
void _onSave() {
  final repMax = widget.exercise.isTimed
      ? _steps[_durationIdx]
      : _repValues[_repMaxIndex];
  final repMin = widget.exercise.isTimed ? repMax : (repMax * 0.6).round();
  Navigator.pop(
    context,
    _ExerciseConfig(
      sets: _sets,
      repMin: repMin,
      repMax: repMax,
      notes: _notesCtrl.text,
      isTimed: widget.exercise.isTimed,
      // Store null when value == 90 (implicit default).
      // Store explicit value otherwise (including 0 = no rest after exercise).
      restBetweenSetsSeconds: _restBetweenSets == 90 ? null : _restBetweenSets,
      restAfterExerciseSeconds: _restAfterExercise == 90 ? null : _restAfterExercise,
      targetRpe: _rpeValues[_rpeIndex],
      videoUrl: _videoUrlCtrl.text.trim().isEmpty
          ? null
          : _videoUrlCtrl.text.trim(),
    ),
  );
}
```

In `build`, replace the single rest stepper block (currently inside `if (!widget.inCircuit)`) with two steppers:

```dart
// Per-exercise rest (standalone only)
if (!widget.inCircuit) ...[
  const _Label('REST BETWEEN SETS'),
  const SizedBox(height: 8),
  _RestStepper(
    label: 'Between sets',
    value: _restBetweenSets,
    allowZero: false,
    onChanged: (v) => setState(() => _restBetweenSets = v),
  ),
  const SizedBox(height: 16),
  const _Label('REST AFTER EXERCISE'),
  const SizedBox(height: 8),
  _RestStepper(
    label: 'After exercise',
    value: _restAfterExercise,
    allowZero: true,
    onChanged: (v) => setState(() => _restAfterExercise = v),
  ),
  const SizedBox(height: 16),
  Divider(color: Colors.white.withValues(alpha: 0.08)),
  const SizedBox(height: 12),
],
```

- [ ] **Step 6: Run flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze 2>&1
```

Expected: no new errors or warnings.

- [ ] **Step 7: Commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
git add lib/screens/settings/wod_exercise_setup_screen.dart
git commit -m "feat: split rest into between-sets + after-exercise; remove WOD-level rest button"
```

---

## Task 4: Manual Verification

- [ ] **Step 1: Run the app**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter run
```

- [ ] **Step 2: Verify WOD card — rename in-place**
  1. Open Settings → Programs → tap a program
  2. Confirm "Edit Workouts" button is gone
  3. Tap the WOD name text → cursor appears, card border highlights
  4. Type a new name → press Return → name updates, border returns to normal
  5. Tap the name → type, then tap outside → saves correctly
  6. Tap empty string, confirm → name reverts to original (not saved blank)

- [ ] **Step 3: Verify WOD card — exercise zone tap**
  1. Tap anywhere in the exercises list area → navigates to exercise setup screen
  2. Confirm the pencil icon (✎) is visible but not tappable (no ripple on its own)
  3. On an empty WOD card: "No exercises — tap to add" is tappable → navigates

- [ ] **Step 4: Verify rest dialog**
  1. Enter exercise setup for any WOD → tap the tune icon on a standalone exercise
  2. Confirm two rest steppers appear: "BETWEEN SETS" and "AFTER EXERCISE"
  3. Confirm no "Xs rest" button in the app bar
  4. Change "BETWEEN SETS" to 2:00 → save → tile shows green "2:00 sets" pill
  5. Change "AFTER EXERCISE" to 0 → save → tile shows "no rest after" pill
  6. Reset both back to 90 s → save → no rest pills shown on tile

- [ ] **Step 5: Final flutter analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker"
flutter analyze 2>&1
```

Expected: clean (same pre-existing infos only).
