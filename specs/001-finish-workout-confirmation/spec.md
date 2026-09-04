# Feature Specification: Finish Workout Confirmation

**Feature Branch**: `[001-finish-workout-confirmation]`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Make finishing an active workout deliberate by de-emphasizing the Finish Workout action, adding a Review & Finish summary before completion, and warning only when exercises or sets remain unfinished. Do not hard-block early finishes; skipped exercises and sets count as resolved."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review before finishing (Priority: P1)

As a lifter logging an active workout, I want finishing to be a deliberate review step rather than an always-prominent action, so I do not accidentally mark the workout done while entering sets.

**Why this priority**: Preventing accidental premature completion is the primary user harm this feature addresses. A review step creates a clear transition from logging to completion while preserving user control.

**Independent Test**: Can be tested by opening an active workout, logging sets, locating the finish path away from the primary set-logging controls, choosing Review & Finish, and verifying the workout is not completed until the user confirms from the review flow.

**Acceptance Scenarios**:

1. **Given** a lifter is actively logging sets, **When** they are on the main logging screen, **Then** the finish action is not presented as a persistent primary control in the bottom thumb zone used for set logging.
2. **Given** a lifter chooses the finish path, **When** the review step opens, **Then** the lifter sees a summary of the session before the workout is committed.
3. **Given** a lifter is on the review step, **When** they choose to keep logging, **Then** they return to the active workout without completing it or losing logged/skipped progress.

---

### User Story 2 - Warn only for unfinished work (Priority: P2)

As a lifter who may end early because of time, fatigue, pain, deloading, or intentionally skipped accessories, I want a clear warning only when work remains unfinished, so I can make an informed choice without being blocked.

**Why this priority**: The feature must prevent accidental completion without undermining legitimate early finishes. Incomplete-only confirmation preserves flexibility while highlighting risk.

**Independent Test**: Can be tested by leaving one or more exercises or sets unfinished, entering the review flow, attempting to finish, and verifying an incomplete warning lists the unfinished items and offers both return and finish-anyway choices.

**Acceptance Scenarios**:

1. **Given** a workout has unfinished sets, **When** the lifter attempts to finish from the review step, **Then** the system shows an incomplete warning summarizing completed or resolved exercises out of total exercises and naming the unfinished exercises.
2. **Given** the incomplete warning is shown, **When** the lifter chooses Keep going, **Then** the workout remains active and the lifter returns to logging.
3. **Given** the incomplete warning is shown, **When** the lifter chooses Finish anyway, **Then** the workout is completed despite unfinished items.
4. **Given** an exercise or set has been intentionally skipped, **When** the system evaluates completion, **Then** that skipped work counts as resolved and does not cause an unfinished warning by itself.

---

### User Story 3 - Low-friction completion when resolved (Priority: P3)

As a lifter who has completed or intentionally resolved all planned work, I want to finish after reviewing with minimal extra friction, so the safeguard does not slow down normal successful workout completion.

**Why this priority**: The safeguard should be noticeable when risk exists but lightweight when the session is already complete or resolved.

**Independent Test**: Can be tested by completing or skipping all planned work, entering the review flow, and verifying the lifter can finish without an incomplete warning.

**Acceptance Scenarios**:

1. **Given** all exercises and sets are completed or skipped, **When** the lifter finishes from the review step, **Then** the workout completes without an incomplete warning.
2. **Given** all work is resolved and the review summary is visible, **When** the lifter completes the workflow, **Then** the final action is clear, intentional, and requires no more than one completion decision from that review step.

### Edge Cases

- If no sets have been logged, the review step still opens and any attempt to finish shows the incomplete warning while allowing Finish anyway.
- If every remaining item has been marked skipped, those items are treated as resolved and no incomplete warning appears solely because they were skipped.
- If an exercise has a mix of logged, skipped, and untouched sets, only untouched planned sets count as unfinished.
- If circuit-style work contains multiple exercises or set items, incomplete detection must evaluate the actual item structure and correctly identify unfinished circuit items rather than relying on a single overall completion flag.
- If a workout includes duplicate exercise names, the unfinished summary must still be understandable enough for the lifter to identify what remains.
- If the list of unfinished items is long, the warning must communicate both the total unfinished count and enough item detail for the lifter to make an informed decision.
- If the lifter navigates away from the review step, the workout remains active unless they explicitly confirm finishing.
- If the lifter repeats the final finish action rapidly, the workout is completed once and must not create duplicate completion effects.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST de-emphasize and/or relocate the finish action so it is not a persistent primary control in the bottom thumb zone during normal set logging.
- **FR-002**: Users MUST be able to intentionally enter a Review & Finish step from an active workout when they are ready to consider ending the session.
- **FR-003**: The system MUST show a pre-completion review summary before any active workout is marked completed.
- **FR-004**: The review summary MUST show, at minimum, total exercises, completed or resolved exercises, unfinished exercises, skipped or resolved items, and sets logged.
- **FR-005**: The review summary MUST allow users to return to the active workout without completing it.
- **FR-006**: The system MUST determine unfinished work from the actual planned item structure and current item statuses, including grouped or circuit-style workout items.
- **FR-007**: The system MUST treat skipped exercises and skipped sets as resolved rather than unfinished.
- **FR-008**: If one or more planned sets remain neither logged nor skipped, the system MUST show an incomplete warning before allowing completion.
- **FR-009**: The incomplete warning MUST clearly summarize progress using the pattern of completed or resolved exercises out of total exercises and MUST identify the exercises with unfinished sets.
- **FR-010**: The incomplete warning MUST offer a Keep going option that keeps the workout active and returns the user to logging.
- **FR-011**: The incomplete warning MUST offer a Finish anyway option that completes the workout without requiring the user to complete or skip remaining work.
- **FR-012**: If all planned work is completed or skipped, the system MUST allow finishing from the review step without showing the incomplete warning.
- **FR-013**: The workout MUST NOT be marked completed merely because the user opened the review step, viewed the summary, or encountered the incomplete warning.
- **FR-014**: The final completion choice MUST be clear enough that a reasonable lifter understands the workout will be marked done after selecting it.
- **FR-015**: The feature MUST preserve all existing logged and skipped workout progress while moving between logging, review, warning, and completion states.

### Key Entities *(include if feature involves data)*

- **Active Workout Session**: The in-progress workout being logged; includes planned exercises, current progress, skipped/resolved state, and completion state.
- **Exercise Item**: A planned exercise within the session; may be completed, skipped/resolved, partially complete, or unfinished.
- **Set Item**: A planned unit of work within an exercise; may be logged, skipped/resolved, or unfinished.
- **Review Summary**: A pre-completion view of session progress, including completed/resolved work, unfinished work, skipped items, and sets logged.
- **Incomplete Warning**: A confirmation prompt shown only when unfinished planned work remains, offering Keep going and Finish anyway choices.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability testing, accidental workout completions during set logging are reduced by at least 80% compared with the previous persistent primary finish control.
- **SC-002**: At least 95% of lifters can intentionally finish a fully completed or fully resolved workout within 10 seconds after choosing the Review & Finish path.
- **SC-003**: In acceptance tests covering standalone and circuit-style workouts, 100% of incomplete finish attempts show an incomplete warning with accurate completed/resolved counts and unfinished exercise names.
- **SC-004**: At least 90% of test participants can correctly identify what remains unfinished from the review or warning before deciding whether to finish.
- **SC-005**: In validation scenarios, 0 workouts are marked completed before the user makes an explicit final finish choice from the review flow.
- **SC-006**: In validation scenarios with skipped exercises or sets, 100% of skipped items are counted as resolved for incomplete-warning decisions.

## Assumptions

- The target user is a lifter actively logging a planned workout session.
- "Resolved" means a planned exercise or set has either been completed/logged or intentionally skipped by the lifter.
- Legitimate early finishes are allowed because lifters may stop for time, fatigue, pain, deloading, or intentional programming reasons.
- The feature applies to active workout completion; changing already completed workout history is out of scope.
- The active session already contains enough user-visible workout structure and progress state to distinguish completed, skipped/resolved, and unfinished items.
- The review and warning text should use exercise names and counts understandable to the lifter, with additional context when names alone could be ambiguous.
