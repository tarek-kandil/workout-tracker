# Design Spec: Muscle Taxonomy + Weekly Volume Report

**Feature:** `003-muscle-volume-report`  
**Owner:** Designer (🎨 UI/UX)  
**Date:** 2026-09-04  
**Primary constraint:** Keep the athlete-facing report simple. The main UI shows only **muscle name + this week’s effective-set count + one of three states: `Undertrained`, `Optimal`, `Overtrained`**. Training-landmark terminology from the functional spec is implementation detail and must not appear in the main list.

---

## 1. Design goals

1. **30-second scan:** an athlete immediately sees which muscles are `Undertrained` or `Overtrained` and what to adjust next.
2. **Three-state clarity:** every muscle has exactly one visible state: `Undertrained`, `Optimal`, or `Overtrained`.
3. **No jargon in the main UI:** do not show landmark acronyms or threshold labels on the primary report screen.
4. **Stable taxonomy:** always show all 21 muscles, grouped by body region, so the app feels predictable.
5. **Fast assignment:** creating/editing an exercise should make one primary + optional secondary muscles clear in under 60 seconds.
6. **Native feel:** reuse the existing Liquid Glass cards, rounded pills, uppercase labels, subtle borders, Space Grotesk typography, and Material 3 controls.

---

## 2. Existing design language to match

Use established app patterns from `app_theme.dart`, Home, Weight Hub, and Exercise Library:

- **Background:** `GlassBackground` behind full screens.
- **Cards:** `GlassCard` for Home/report surfaces; `LiquidGlassContainer` for denser detail cards.
- **Navigation:** push with `glassRoute(...)`; do not add a new bottom-nav tab.
- **Shape:** 16–20 px for rows/cards, 24–28 px for hero cards and bottom sheets.
- **Spacing:** screen padding `16`, card padding `14–20`, section gaps `16–20`, row gaps `8–12`.
- **Typography:** Space Grotesk via theme.
  - AppBar title: existing `18 / w600`.
  - Hero number/summary: `26–32 / w800`.
  - Muscle row title: `15–16 / w700`.
  - Section label: uppercase `9–11 / w700`, letter spacing `1.1–1.2`, `onSurface` at `38–45%` opacity.
  - Metadata: `11–13`, `onSurface` at `45–60%` opacity.
- **Pills:** tinted fill `alpha .10–.18`, border `alpha .25–.35`, bold label `10–12`, rounded `12–20`.

---

## 3. Athlete-facing status system

Use these exact visible labels everywhere in the report:

| Visible status | Internal meaning | Dark display color | Light display color | Icon/shape | Athlete tone |
|---|---|---:|---:|---|---|
| `Undertrained` | Below the productive weekly range | Violet `#A78BFA` | Violet `#6D28D9` | `trending_down_rounded`; hollow marker | Needs more work if growth/maintenance is the goal. |
| `Optimal` | Inside the healthy weekly range | Emerald `#34D399` | Emerald `#047857` | `check_circle_rounded`; filled dot | Keep going. |
| `Overtrained` | Above the recoverable weekly range | Rose `#E11D48` | Rose `#BE123C` | `warning_amber_rounded`; triangle marker | Pull back or recover. |

Rules:

- Use **only** `Undertrained`, `Optimal`, and `Overtrained` as report status labels.
- Do **not** use abbreviated alternatives or synonyms for these three labels.
- Do **not** show training-landmark acronyms, four-threshold labels, or tables in the main UI.
- Do **not** use color alone. Status pills include color + icon + label. Optional detail visuals include color + marker shape.
- Keep this palette separate from RIR effort colors (`#F87171`, `#FB923C`, `#FBBF24`, `#818CF8`, `#38BDF8`). Volume status is categorical; RIR color is effort intensity.

---

## 4. Weekly Muscle Report screen

### 4.1 Entry point on Home

Add a full-width **Muscle Volume** tile on Home.

- **Placement:** `HomeScreen._buildDashboard`, after the stat row and before `WeightGoalCard`.
- **Reason:** this is a planning/reporting loop tied to today’s training decision; it should be discoverable from Home without adding a fourth nav tab.
- **Style:** same family as `WeightGoalCard`, height `132–148`, using `GlassCard`.
- **Tap:** opens `WeeklyMuscleReportScreen` via `glassRoute(...)`.
- **Icon:** `Icons.radar_rounded` preferred; fallback `Icons.monitor_heart_outlined`.

Tile content:

- Eyebrow: `WEEKLY MUSCLE VOLUME`
- Default title: `3 undertrained · 1 overtrained`
- Default subtitle: `Rest optimal · last 7 days`
- Chips:
  - `3 Undertrained` violet hollow-marker chip
  - `1 Overtrained` rose triangle chip
  - `17 Optimal` emerald check chip
- All-optimal title: `All optimal`
- All-optimal subtitle: `Last 7 days · keep the plan rolling`
- No-workout title: `No volume this week`
- No-workout subtitle: `Open the report to plan your next week`
- If assignment review is needed: amber utility chip `N unmapped`

Do **not** add this to the bottom navigation. Existing shell remains Home / Records / Settings.

### 4.2 Screen scaffold

- **Route title:** `Muscle Volume`
- **AppBar actions:**
  - Info icon, tooltip `What does this mean?`
  - Optional action `Review unmapped` when unmapped count > 0
- **Body:** `Stack` with `GlassBackground`; `ListView` or `CustomScrollView` with `EdgeInsets.fromLTRB(16, 8, 16, bottomSafeArea + 88)`.
- **Scroll order:**
  1. Simple summary hero
  2. Unmapped exercises banner, if needed
  3. `Needs attention` card, if any
  4. All-muscles list grouped by body region
  5. Optional small `What does this mean?` info row at the bottom

### 4.3 Simple summary hero

Use `GlassCard(borderRadius: 24, padding: EdgeInsets.all(18))`.

Main content:

- Eyebrow: `LAST 7 DAYS`
- Summary line:
  - With attention: `{underCount} undertrained · {overCount} overtrained · rest optimal`
  - All good: `All optimal`
  - No workouts: `No workouts in the last 7 days`
- Supporting copy:
  - With attention: `Start with the muscles flagged below before changing the whole plan.`
  - All good: `Your muscle volume is balanced this week.`
  - No workouts: `Every muscle starts at zero. Use this as a deload check or plan your next session.`
- Three compact stat tiles:
  - `Undertrained` count, violet icon
  - `Optimal` count, emerald icon
  - `Overtrained` count, rose icon

No chart, threshold table, or landmark legend appears in the hero.

### 4.4 Unmapped exercises banner

Show directly below the hero when `unmappedCount > 0`.

- Surface: `GlassCard` with amber utility tint `#F59E0B alpha .10`, border `alpha .28`.
- Icon: `Icons.assignment_late_rounded`.
- Title: `{N} exercise{plural} need muscle assignment`
- Body: `They are not counted in muscle volume until reviewed.`
- If any were logged in the last 7 days: `Some recent sets were skipped until those exercises are assigned.`
- CTA: `Review assignments`
- Tap target: entire banner opens Exercise Library filtered to `Needs Review`.

Amber is a utility/warning color, not a fourth muscle-volume state.

### 4.5 Needs attention card

This is the SC-006 fast-scan mechanism. Show only when at least one muscle is `Undertrained` or `Overtrained`.

- Header: `NEEDS ATTENTION`
- Sort:
  1. `Overtrained` first, most above range first.
  2. `Undertrained` next, farthest below range first.
- Show the top 3–5 items. If more, include `View all` that scrolls to the full list.
- Row height: `64–72`, minimum tap target 44 px.
- Row content:
  - Muscle name
  - This week’s count: `7 sets` / `7.5 sets`
  - Status pill: `Undertrained` or `Overtrained`
  - One plain next-step line:
    - Undertrained: `Add a few sets next time this area appears.`
    - Overtrained: `Reduce sets or keep the next session easier.`

Do not show internal threshold names, numeric target ranges, or four-letter acronyms in this card.

### 4.6 All-muscles information architecture

Always show all 21 muscles in fixed body-region groups. Do not globally reorder the full list; the `Needs attention` card already surfaces urgent items.

Default groups and order:

1. **Chest**
   - Chest
2. **Back**
   - Lats
   - Upper Back
   - Traps
   - Spinal Erectors
3. **Shoulders**
   - Front Delts
   - Side Delts
   - Rear Delts
4. **Arms**
   - Biceps
   - Triceps
   - Forearms
5. **Legs**
   - Quads
   - Hamstrings
   - Glutes
   - Adductors
   - Abductors
   - Hip Flexors
   - Calves
6. **Core**
   - Abs
   - Obliques
7. **Neck**
   - Neck

Section behavior:

- Use section cards or lightweight collapsible sections.
- Default expanded for all sections because 21 rows is manageable and all muscles must be visible.
- Section header copy examples:
  - `BACK · 1 UNDERTRAINED · 3 OPTIMAL`
  - `LEGS · 1 OVERTRAINED · 6 OPTIMAL`
- If collapsing is implemented, remember state per session only.

### 4.7 Main muscle row: simple view

The main list row must stay glanceable and uncluttered.

Required visible content only:

1. **Muscle name** — `15–16 / w700`.
2. **This week’s effective-set count** — `0 sets`, `7 sets`, `7.5 sets`.
3. **Status pill** — exactly one of `Undertrained`, `Optimal`, `Overtrained`.

Recommended layout:

- Container: rounded 16 px, white tint `alpha .04–.06`, border `alpha .08–.10`.
- Height: `60–68` px, expandable for dynamic type.
- Left column:
  - Muscle name
  - Small metadata: `This week · {count} sets`
- Right: status pill.
- Tap row: opens the optional muscle detail sheet.

Do **not** place a landmark/gauge bar in the main list. Do **not** show numeric threshold targets in the row.

### 4.8 Optional muscle detail sheet

A row tap may open a simple detail sheet. This is progressive disclosure and should not be required for the main report to work.

Sheet:

- `DraggableScrollableSheet`, initial `0.55`, max `0.9`, rounded top 28 px.
- Title: `{Muscle}`
- Hero line: `{count} sets this week · {state}`
- One-sentence guidance:
  - Undertrained: `Add a few effective sets if this muscle is a priority this week.`
  - Optimal: `Keep this area about where it is.`
  - Overtrained: `Pull back or give this area more recovery.`

Optional simple visual:

- Label: `Your week vs healthy range`
- Bar has only three plain zones: `Low`, `Good`, `High`.
- Marker text: `You are here`.
- Use the same violet/emerald/rose colors and marker shapes.
- Do not label the underlying internal thresholds.

Optional details below visual:

- `Primary muscles count more than secondary muscles.`
- `Very easy sets count less.`
- `Circuit rounds count each completed exercise inside the circuit.`

### 4.9 Optional “What does this mean?” info affordance

Keep this unobtrusive. It can be an AppBar info icon and/or a small bottom row after the list.

Title: `What does this mean?`

Copy:

> This report estimates useful weekly work for each muscle. Primary muscles count as 1 set. Secondary muscles count as 0.5. Very easy sets count less. Each muscle is then marked Undertrained, Optimal, or Overtrained based on the app’s built-in weekly ranges.

More copy:

> These are coaching signals, not medical diagnoses. If this is an intentional deload, seeing more `Undertrained` muscles can be expected.

Do not show the internal landmark acronyms or a threshold table here by default. If implementation includes advanced debug/details later, it must be behind a clearly secondary developer/advanced affordance, not part of the athlete flow.

### 4.10 Empty and edge states

#### Muscle with 0 sets

- Row still appears in its region.
- Count: `0 sets`.
- State: `Undertrained`.
- Optional detail guidance: `Add a few sets if this muscle is a priority. If this is a deload, this may be expected.`

#### No workouts in the last 7 days

Hero:

- Title: `No workouts in the last 7 days`
- Body: `Every muscle starts at zero. Use this as a deload check or plan your next session.`
- CTA: `Start workout` if an active program exists; otherwise `Create program`.

List:

- Still show all 21 muscles as `0 sets · Undertrained`.
- Do not hide the list behind an empty state.

#### Unmapped exercises

- Show banner as above.
- Do not invent missing volume.
- If needed, show one section-level note only: `Some recent exercises were skipped until assigned.`

#### Sparse history

- Still label the period as `Last 7 days`.
- Do not apologize; one workout is valid data.

#### Loading and errors

- Loading: skeleton hero + 3–4 skeleton section cards using existing glass tint.
- Error: centered GlassCard:
  - Title: `Could not load muscle volume`
  - Body: `Try again. Your workout history is unchanged.`
  - Button: `Retry`

---

## 5. Muscle + role assignment UI

### 5.1 Where it lives

Update the existing Exercise Library create/edit bottom sheet. Keep the familiar structure:

1. Drag handle
2. Title (`New Exercise` / `Edit Exercise`)
3. Name field
4. Muscle assignment section
5. Timed exercise toggle
6. Save button

Replace the old “first chip = primary” model with explicit Primary and Secondary roles.

### 5.2 Inline assignment summary in create/edit sheet

Section header:

- Label: `MUSCLE ASSIGNMENT`
- Helper: `Choose one primary muscle. Add secondary muscles if they help move the lift.`

Summary card states:

#### Assigned

- Primary row:
  - Label chip: `PRIMARY`
  - Muscle pill: `Chest`
  - Helper: `Counts 1 set`
- Secondary row/wrap:
  - Label chip: `SECONDARY`
  - Pills: `Triceps`, `Front Delts`
  - Helper: `Each counts 0.5 sets`
- Action: `Edit muscles`

#### Unassigned

- Icon: `assignment_late_rounded`
- Title: `No muscles assigned`
- Body: `This exercise will not count toward muscle volume.`
- CTA: `Assign muscles`
- Surface: amber utility tint `#F59E0B alpha .16`, border `alpha .32`.

Save behavior:

- For strength/hypertrophy exercises, require one primary muscle before save.
- Disabled-save helper: `Add a primary muscle to include this exercise in volume reports.`
- For intentionally untracked Cardio/Full Body style exercises, allow save only after choosing secondary action `Keep untracked for muscle volume`.

### 5.3 Assignment picker sheet

Open from `Assign muscles` / `Edit muscles`.

Sheet specs:

- `DraggableScrollableSheet`, initial `0.82`, min `0.55`, max `0.95`.
- Surface: `colorScheme.surface`; top radius 28 px.
- Title: `Assign muscles`
- Subtitle: `Primary counts 1 set. Secondary counts 0.5.`
- Sticky selected summary at top.
- Search field: hint `Search muscles…`, prefix search icon, no autofocus by default.
- Grouped muscle list by the same body regions as the report.
- Bottom actions: `Clear` and `Done`; `Done` disabled until exactly one primary is selected.

Selected summary:

- Primary empty: dashed pill `Choose primary`.
- Primary filled: `Primary · Chest` with target icon and remove affordance.
- Secondary empty: `Secondary muscles optional`.
- Secondary filled: removable chips `Triceps ×`, `Front Delts ×`.

Muscle rows:

- Group header uppercase, e.g. `CHEST`, `BACK`.
- Row height: 52 px.
- Row content: muscle name + two role buttons: `Primary`, `Secondary`.
- Selected primary: violet/indigo filled tint, target icon.
- Selected secondary: neutral/indigo outline, half-dot icon.
- If a muscle is primary, its secondary button is disabled.
- Tapping `Primary` sets that muscle as the single primary. If another primary existed, move the old primary to secondary by default and show `{Old muscle} moved to secondary.`
- Tapping `Secondary` toggles secondary on/off.
- Tapping the row body sets primary if none exists; otherwise toggles secondary.

Search behavior:

- Filter all 21 muscles by name.
- Helpful aliases if implementation supports them: `delt`, `quad`, `ham`, `lat`, `ab`, `calf`, `trap`.
- Empty copy: `No muscle found for “{query}”. Try lats, quads, or delts.`

### 5.4 Exercise Library list states

Group order after upgrade:

1. `Needs Review`
2. New taxonomy groups by primary muscle/body region
3. `Cardio / Untracked` for exercises intentionally excluded from muscle volume

Exercise row content:

- Exercise name.
- Primary pill: `P Chest` or `Primary · Chest`.
- Secondary pills: `S Triceps`, `S Front Delts`.
- Existing `TIMED` pill remains.
- If needs review:
  - Border: amber `#F59E0B alpha .35`; background `alpha .08`.
  - Pill: `Needs review` with `assignment_late_rounded`.
  - Subtitle: `Assign muscles to count future volume.`
  - Tapping opens edit sheet with the Muscle Assignment section highlighted.

### 5.5 Logging / picker indicator for unmapped exercises

In exercise picker sheets and active-session cards:

- Add amber utility pill next to exercise name when no primary assignment exists: `Unmapped`.
- Semantics: `This exercise will not count toward muscle volume until assigned.`
- If the athlete selects/logs an unmapped exercise, show a non-blocking banner:
  - `"{Exercise}" won't count toward muscle volume yet.`
  - Action: `Assign`
- Do not block workout logging.

---

## 6. Microcopy library

### Status labels

Use exactly:

- `Undertrained`
- `Optimal`
- `Overtrained`

Do not use abbreviated alternatives in athlete-facing UI.

### Summary lines

- Attention: `{underCount} undertrained · {overCount} overtrained · rest optimal`
- All good: `All optimal`
- No workouts: `No workouts in the last 7 days`
- Unmapped: `{unmappedCount} exercises need muscle assignment`

### Main-list row copy

- Count: `{n} sets`
- Metadata: `This week · {n} sets`
- Status pill: `Undertrained`, `Optimal`, or `Overtrained`

### Needs-attention next steps

- Undertrained: `Add a few sets next time this area appears.`
- Optimal: `Keep this area about where it is.`
- Overtrained: `Reduce sets or keep the next session easier.`
- Deload note, only in info/detail: `If this is a deload, lower volume can be expected.`

### Info affordance copy

- `What does this mean?`
- `Primary muscles count as 1 set. Secondary muscles count as 0.5. Very easy sets count less.`
- `Circuit rounds count each completed exercise inside the circuit.`
- `The app compares each muscle to built-in weekly ranges and marks it Undertrained, Optimal, or Overtrained.`
- `These are coaching signals, not medical diagnoses.`

### Empty/error states

- No workouts title: `No workouts in the last 7 days`
- No workouts body: `Every muscle starts at zero. Use this as a deload check or plan your next session.`
- Error title: `Could not load muscle volume`
- Error body: `Try again. Your workout history is unchanged.`
- No assignment title: `No muscles assigned`
- No assignment body: `This exercise will not count toward muscle volume.`

---

## 7. Accessibility requirements

- **Contrast:** status text/icons must meet WCAG AA on both dark and light glass surfaces. Use darker light-mode status colors for text/icons.
- **Not color-only:**
  - `Undertrained`: violet + downward icon + hollow marker.
  - `Optimal`: emerald + check icon + filled dot.
  - `Overtrained`: rose + warning icon + triangle marker.
- **Tap targets:** rows, chips, role buttons, and CTAs at least 44×44 logical px; prefer 52 px for muscle picker rows.
- **Dynamic type:** main report rows may grow vertically. Never clip muscle name, count, or status pill.
- **Screen readers:**
  - Main row example: `Chest, 7 sets this week, Undertrained.`
  - Detail sheet example: `Chest, 7 sets this week, Undertrained. Add a few effective sets if this muscle is a priority.`
  - Assignment row example: `Chest, selected as primary, counts one set.`
- **Dark/light mode:** prefer `colorScheme.onSurface` with opacity for neutral text; reserve fixed constants for status accents.
- **Motion:** subtle expand/collapse only (`200–250 ms easeOutCubic`). Do not animate report status constantly.
- **In-gym ergonomics:** primary actions should be full-width or easy to hit one-handed.

---

## 8. Component mapping for Flutter

Reuse / extend these patterns:

- `WeeklyMuscleReportScreen`
  - `Scaffold` + `GlassBackground`
  - `AppBar(title: Text('Muscle Volume'))`
  - `ListView` / `CustomScrollView`
  - `GlassCard` for hero, banners, section cards
- `MuscleVolumeHomeCard`
  - Pattern: `WeightGoalCard`
  - Height: `132–148`
  - `GestureDetector` or `InkWell` + `glassRoute(WeeklyMuscleReportScreen())`
- `VolumeStatePill`
  - Pattern: `_StatusPill` in Weight Hub and `RirPill`
  - Dedicated status constants; do not call `rirColor()`
- `MuscleVolumeRow`
  - Simple row: muscle name, `This week · n sets`, status pill
  - No main-list gauge
- `MuscleDetailSheet`
  - Optional progressive disclosure
  - May include simple `Low / Good / High` bar with `You are here`
- `MuscleRegionSection`
  - Pattern: existing section labels + rounded card/list rows
  - Expanded by default
- `MuscleAssignmentSummary`
  - Lives inside `ExerciseLibraryScreen` bottom sheet
  - Explicit `PRIMARY` and `SECONDARY` chips
- `MuscleAssignmentSheet`
  - Pattern: existing `ExerciseLibrarySheet` / create-edit bottom sheet
  - `DraggableScrollableSheet`, themed `TextField`, grouped `ListView`, sticky bottom `FilledButton`
- `NeedsReviewPill`
  - Amber utility warning chip using `#F59E0B`; not a muscle-volume state

---

## 9. Implementation checklist for design fidelity

- [ ] Home tile opens the report and shows `Undertrained`, `Optimal`, and `Overtrained` counts.
- [ ] Report hero uses simple copy: `{underCount} undertrained · {overCount} overtrained · rest optimal`.
- [ ] Unmapped exercises banner appears when needed and explains skipped volume.
- [ ] All 21 muscles always appear in the specified region order.
- [ ] Main muscle rows show only muscle name, this week’s set count, and one status pill.
- [ ] No training-landmark jargon appears in the main list, hero, or needs-attention card.
- [ ] Any range visual is only in optional detail/progressive disclosure and uses plain `Low / Good / High` language.
- [ ] No-workout state still renders all 21 zero-set rows as `Undertrained`.
- [ ] Assignment UI requires one primary for volume-counted exercises.
- [ ] Secondary muscles are optional, visible, removable, and clearly worth 0.5 sets.
- [ ] Needs-review exercises are grouped/pilled in Exercise Library and resolvable from the row.
- [ ] Status colors/icons differ from RIR effort colors and remain accessible in dark/light mode.
