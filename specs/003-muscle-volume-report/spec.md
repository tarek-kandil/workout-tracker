# Feature Specification: Muscle Taxonomy + Weekly Volume Report

**Feature Branch**: `[003-muscle-volume-report]`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Muscle Taxonomy + Weekly Volume Report using a 21-muscle taxonomy, primary/secondary effective-set credit, RIR down-weighting, rolling 7-day reporting, simple Undertrained/Optimal/Overtrained statuses, circuit support, editable exercise assignments, and non-destructive preservation of existing exercises and workout history."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review weekly muscle status (Priority: P1)

As an athlete, I want to open a weekly muscle report and see each trainable muscle classified as Undertrained, Optimal, or Overtrained so I can decide what to emphasize, maintain, or reduce in my next sessions.

**Why this priority**: This is the core value of the feature: turning logged training into actionable muscle-level feedback without requiring the athlete to manually total sets.

**Independent Test**: Can be fully tested by reviewing an athlete's last 7 days of workouts and confirming that every muscle appears with an effective-set total, a status, and enough context to guide the next training decision.

**Acceptance Scenarios**:

1. **Given** an athlete has logged workouts in the last 7 days, **When** they open the weekly muscle report, **Then** the report shows Chest, Lats, Upper Back, Traps, Spinal Erectors, Front Delts, Side Delts, Rear Delts, Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Adductors, Abductors, Hip Flexors, Calves, Abs, Obliques, and Neck, each with effective sets and one of the three statuses.
2. **Given** a muscle's 7-day effective-set total is below its minimum-effective landmark, **When** the report is shown, **Then** that muscle is labeled Undertrained and the athlete can tell it may need more direct or indirect work.
3. **Given** a muscle's 7-day effective-set total is within the productive range from minimum-effective through max-recoverable landmarks, **When** the report is shown, **Then** that muscle is labeled Optimal and the athlete can see whether it is closer to the target adaptive range.
4. **Given** a muscle's 7-day effective-set total is above its max-recoverable landmark, **When** the report is shown, **Then** that muscle is labeled Overtrained and the athlete can tell it may need reduced volume or more recovery.

---

### User Story 2 - Assign muscles and roles to exercises (Priority: P2)

As an athlete maintaining my exercise library, I want to assign one or more muscles to each exercise and mark each muscle as primary or secondary so future volume reporting reflects how the exercise is actually trained.

**Why this priority**: Accurate reporting depends on accurate exercise attribution, especially for custom exercises and compound movements.

**Independent Test**: Can be tested by creating or editing an exercise, assigning primary and secondary muscles, logging that exercise, and verifying the weekly report credits the selected muscles according to their roles.

**Acceptance Scenarios**:

1. **Given** an athlete creates a custom exercise, **When** they save muscle assignments, **Then** they can choose at least one primary muscle and optionally one or more secondary muscles from the 21-muscle taxonomy.
2. **Given** an athlete edits an exercise's muscle assignments, **When** they save the change, **Then** weekly volume reports that include that exercise use the saved assignments while workout records remain intact.
3. **Given** an exercise has no muscle assignment, **When** the athlete views or logs it, **Then** the app makes clear that the exercise cannot contribute to muscle-volume totals until at least one muscle role is assigned.

---

### User Story 3 - Attribute volume from normal exercises and circuits (Priority: P2)

As an athlete who logs both straight sets and circuits, I want the weekly report to credit every completed exercise set inside those workouts so circuit training does not disappear from muscle-volume feedback.

**Why this priority**: Circuits are part of the app's workout model and must be counted consistently for the report to be trusted.

**Independent Test**: Can be tested by logging the same exercise as straight sets and inside a circuit, then confirming both contribute to the relevant muscles under the same credit and effort rules.

**Acceptance Scenarios**:

1. **Given** an athlete completes straight sets for an exercise with primary and secondary muscles, **When** the weekly report is calculated, **Then** each completed set credits the assigned muscles according to role and effort.
2. **Given** an athlete completes a circuit round containing multiple exercises, **When** the weekly report is calculated, **Then** each completed exercise within the circuit round contributes to its assigned muscles according to the same role and effort rules used for straight sets.
3. **Given** a circuit includes conditioning or Full Body labels, **When** muscle-volume totals are calculated, **Then** those labels do not inflate any muscle's hypertrophy status unless the individual exercises also have specific muscle assignments.

---

### User Story 4 - Preserve existing exercises and history during upgrade (Priority: P3)

As an existing athlete, I want my saved exercises, muscle assignments, and workout history preserved when the app moves from broad tags to the new muscle taxonomy so I do not lose training records or have to rebuild my library from scratch.

**Why this priority**: Trust in the report depends on a safe transition from existing logs and exercise mappings, but it can be validated independently from the new report experience.

**Independent Test**: Can be tested by upgrading an account with existing default exercises, custom exercises, broad muscle tags, circuits, and historical workouts, then confirming all records remain available and are mapped into the new taxonomy wherever possible.

**Acceptance Scenarios**:

1. **Given** an athlete has existing exercises assigned to broad categories such as Back, Shoulders, Core, Full Body, or Cardio, **When** the app is upgraded, **Then** those exercises are preserved and mapped to the most appropriate new muscle assignments or marked for user review if a safe mapping cannot be inferred.
2. **Given** an athlete has historical workouts and logged sets before the upgrade, **When** they view workout history or the weekly report after the upgrade, **Then** no historical workout, exercise, circuit, or set is lost.
3. **Given** a previous assignment cannot be confidently mapped to the new taxonomy, **When** the athlete reviews their exercise library or weekly report, **Then** the app identifies the exercise as needing muscle assignment rather than silently dropping or inventing volume.

### Edge Cases

- An exercise with no muscles assigned does not contribute to muscle-volume totals and is surfaced as unmapped so the athlete can fix it.
- A muscle trained for 0 effective sets in the rolling 7-day window still appears in the report and is labeled Undertrained, with below-maintenance context when applicable.
- A set with no RIR recorded counts at full role credit rather than being penalized for missing effort data.
- A set recorded with RIR 5 or higher is down-weighted as very easy work, including when it belongs to a secondary muscle.
- A single exercise may credit many muscles; every assigned muscle receives its role-based credit, with no arbitrary cap across muscles.
- Sparse history still produces a report from the available last-7-day data without inventing missing workouts.
- During deload weeks, the report still classifies low volume as Undertrained, but the language should remain advisory so intentional lower-volume weeks are not treated as data errors.
- Circuits credit each completed exercise in the circuit, not merely the circuit name.
- Cardio and Full Body remain non-muscle categories and never receive hypertrophy landmarks or muscle-readiness statuses.
- Boundary values are classified consistently: totals below MEV are Undertrained, totals from MEV through MRV are Optimal, and totals above MRV are Overtrained.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST define the trainable muscle taxonomy as exactly these 21 muscles: Chest, Lats, Upper Back, Traps, Spinal Erectors, Front Delts, Side Delts, Rear Delts, Biceps, Triceps, Forearms, Quads, Hamstrings, Glutes, Adductors, Abductors, Hip Flexors, Calves, Abs, Obliques, and Neck.
- **FR-002**: The app MUST treat Cardio and Full Body as non-muscle categories that may describe training style but are excluded from hypertrophy landmarks and muscle-volume status calculations.
- **FR-003**: Every default exercise intended to contribute to strength or hypertrophy volume MUST be mapped to at least one taxonomy muscle with a primary or secondary role.
- **FR-004**: Each exercise MUST support assignment to one or more muscles, and each assignment MUST identify the muscle's role as primary or secondary.
- **FR-005**: Any exercise that contributes to muscle volume MUST have at least one primary muscle; secondary muscles are optional and may be added when they materially contribute.
- **FR-006**: Athletes MUST be able to create and edit muscle assignments for custom and default exercises without losing the exercise or its logged workout history.
- **FR-007**: The weekly report MUST calculate effective hard sets per muscle over a rolling 7-day window ending at the time the athlete views the report.
- **FR-008**: For each completed set, a primary muscle assignment MUST receive 1.0 effective-set credit and a secondary muscle assignment MUST receive 0.5 effective-set credit.
- **FR-009**: A completed set recorded with RIR 5 or higher MUST have its role-based credit multiplied by 0.5; a completed set with no RIR recorded MUST keep full role-based credit.
- **FR-010**: Straight sets and circuit work MUST use the same effective-set credit rules, with each completed exercise inside a circuit contributing according to its own muscle assignments.
- **FR-011**: The app MUST maintain per-muscle volume landmarks for MV, MEV, MAV, and MRV in effective sets per week for each of the 21 muscles.
- **FR-012**: The weekly report MUST classify each muscle using exactly three user-facing statuses: Undertrained when below MEV, Optimal when from MEV through MRV, and Overtrained when above MRV.
- **FR-013**: When a muscle is below MV, the report MAY add below-maintenance context, but the user-facing status MUST remain Undertrained.
- **FR-014**: The weekly report MUST show all 21 muscles even when a muscle has no logged volume in the rolling window.
- **FR-015**: The upgrade from broad categories to the new taxonomy MUST be non-destructive: existing exercises, custom exercises, circuits, workout history, logged sets, and prior exercise assignments must remain available after the upgrade.
- **FR-016**: Existing broad-category exercise assignments MUST be back-filled to the new taxonomy where a safe mapping is available; assignments that cannot be mapped confidently MUST be preserved for review rather than discarded.
- **FR-017**: Unmapped or partially mapped exercises MUST be visible to the athlete as needing review, and their unassigned portions MUST NOT silently inflate any muscle's weekly volume.
- **FR-018**: The report MUST make the crediting basis understandable to athletes by indicating that primary muscles count more than secondary muscles and very easy sets count less.

### Key Entities *(include if feature involves data)*

- **Muscle**: A trainable body part in the 21-muscle taxonomy. A muscle can be assigned to exercises and receives weekly effective-set totals and a status.
- **ExerciseMuscleAssignment**: The relationship between an exercise and a muscle, including whether that muscle is a primary or secondary contributor for the exercise.
- **VolumeLandmark**: The weekly effective-set reference values for a muscle: maintenance volume (MV), minimum-effective volume (MEV), maximum-adaptive volume (MAV), and max-recoverable volume (MRV).
- **WeeklyMuscleVolume**: The report result for one muscle over the rolling 7-day window, including effective sets, landmark comparison, and Undertrained, Optimal, or Overtrained status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of default strength and hypertrophy exercises are mapped to at least one of the 21 muscles with a primary or secondary role before release.
- **SC-002**: For any athlete, including one with no workouts in the last 7 days, the weekly report shows all 21 muscles with an effective-set total and one of the three statuses.
- **SC-003**: In validation examples covering straight sets, circuits, primary muscles, secondary muscles, missing RIR, and RIR 5+, 100% of weekly effective-set totals match the published credit rules.
- **SC-004**: After upgrading from the broad-category system, 100% of existing exercises, custom exercises, circuits, workout logs, and logged sets remain accessible.
- **SC-005**: At least 95% of existing default exercise assignments are automatically mapped to the new taxonomy; any remaining assignments are clearly marked for athlete review.
- **SC-006**: In a usability check, at least 90% of athletes can identify one undertrained or overtrained muscle and state a reasonable next training adjustment within 30 seconds of opening the report.
- **SC-007**: At least 90% of athletes can assign primary and secondary muscles to a new custom exercise in under 60 seconds without outside instruction.
- **SC-008**: The weekly report is usable within 3 seconds for an athlete with a full year of workout history.

## Assumptions

- The feature uses one Intermediate landmark set for all athletes; there is no beginner, advanced, sex-specific, age-specific, or goal-specific landmark setting in this feature.
- The weekly report is a rolling 7-day view ending when the athlete opens the report, not a fixed calendar-week scorecard.
- MAV is treated as a target adaptive band inside the broader Optimal range; MEV through MRV is still labeled Optimal for the simple 3-status experience.
- Volume statuses are coaching signals for training planning, not medical diagnoses. "Overtrained" means above the selected weekly recoverable volume landmark, not a clinical overtraining diagnosis.
- Existing Cardio and Full Body labels may remain useful for organization and conditioning context, but they do not count toward muscle hypertrophy landmarks.
- If an athlete intentionally deloads, the report may show Undertrained muscles for that week; the app should present that as expected low volume rather than lost data.
- These Intermediate landmark defaults give planning concrete numbers in effective sets per week. Neck values are conservative and should be treated as provisional because neck training needs vary widely.

| Muscle | MV | MEV | MAV target band | MRV |
|--------|----|-----|-----------------|-----|
| Chest | 4 | 8 | 12-18 | 22 |
| Lats | 4 | 8 | 12-18 | 22 |
| Upper Back | 4 | 8 | 12-20 | 24 |
| Traps | 2 | 6 | 10-16 | 20 |
| Spinal Erectors | 2 | 4 | 6-10 | 12 |
| Front Delts | 2 | 4 | 6-10 | 12 |
| Side Delts | 4 | 8 | 12-20 | 26 |
| Rear Delts | 4 | 8 | 12-20 | 24 |
| Biceps | 4 | 8 | 12-18 | 22 |
| Triceps | 4 | 8 | 12-18 | 22 |
| Forearms | 2 | 6 | 8-14 | 18 |
| Quads | 4 | 8 | 12-18 | 22 |
| Hamstrings | 4 | 8 | 10-16 | 20 |
| Glutes | 4 | 8 | 10-18 | 22 |
| Adductors | 2 | 4 | 6-10 | 14 |
| Abductors | 2 | 4 | 6-10 | 14 |
| Hip Flexors | 2 | 4 | 6-10 | 14 |
| Calves | 4 | 8 | 12-20 | 24 |
| Abs | 4 | 8 | 10-16 | 20 |
| Obliques | 2 | 6 | 8-14 | 18 |
| Neck | 0 | 2 | 4-8 | 10 |
