# Feature Specification: Weight Goal Coaching Loop

**Feature Branch**: `bug-fixes-aug-2026`

**Created**: 2026-09-04

**Status**: Draft

**Input**: User description: "Body-weight logging should become more extensive and useful: create a cohesive Weight Hub where the user can set a desired weight and target duration, see the calorie intake and macro suggestions needed to reach it, receive configurable weigh-in reminders, log interval weigh-ins, understand whether progress is on track, get plain-language eat-more/eat-less guidance, and optionally see this status from the home screen."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set a Weight Goal and Get a Plan (Priority: P1)

As a user, I want a Weight Hub that replaces the current basic body-weight settings list so I can define a desired weight, target date or duration, and weigh-in cadence, then immediately understand the pace, daily calorie target, and macro suggestions needed to reach the goal safely.

**Why this priority**: This is the foundation of the coaching loop. Without a goal plan, weigh-in guidance, reminders, and the home tile cannot provide meaningful progress feedback.

**Independent Test**: Can be fully tested by opening Weight Hub from Settings, entering goal details, reviewing the live plan readout, saving the plan, leaving the screen, and returning to confirm the plan is still visible and understandable.

**Acceptance Scenarios**:

1. **Given** the user has no active weight goal plan, **When** they open the body-weight entry point from Settings, **Then** they see the Weight Hub with a clear empty state and an action to set a weight goal.
2. **Given** the user starts goal setup, **When** they choose lose, build, or maintain, enter current weight, desired weight, target date or duration, and weigh-in cadence, **Then** the app shows a live readout of required weekly pace, daily calorie target, and protein, fat, and carbohydrate suggestions before saving.
3. **Given** the user's selected loss pace is faster than 0.5 kg per week but slower than 1.0 kg per week, **When** the live readout updates, **Then** the app shows a caution state explaining that the pace may be aggressive.
4. **Given** the user's selected loss pace is 1.0 kg per week or faster, **When** the live readout updates or the user attempts to save, **Then** the app marks the pace as not recommended and offers to extend the timeframe or use a recommended pace while still allowing the user to save anyway.
5. **Given** the user's selected muscle-gain pace is faster than 0.25 kg per week but slower than 0.75 kg per week, **When** the live readout updates, **Then** the app shows a caution state explaining that the pace may be aggressive.
6. **Given** the user's selected muscle-gain pace is 0.75 kg per week or faster, **When** the live readout updates or the user attempts to save, **Then** the app marks the pace as not recommended and offers to extend the timeframe or use a recommended pace while still allowing the user to save anyway.
7. **Given** the user saves a valid goal plan, **When** they return to Weight Hub later, **Then** the current-plan overview shows the desired weight, target date or duration, planned pace, daily calorie target, macro suggestions, and selected weigh-in cadence.

---

### User Story 2 - Log a Weigh-in and Receive Coaching Guidance (Priority: P2)

As a user following a weight goal, I want to log my body weight at each reminder interval and immediately see whether my progress is on track, behind, ahead, too fast, unsafe, or provisional, along with a plain-language calorie adjustment suggestion when needed.

**Why this priority**: The feature becomes useful when logged weigh-ins close the feedback loop and convert progress data into clear nutrition guidance.

**Independent Test**: Can be fully tested by creating a goal plan, logging weigh-ins across multiple intervals, and confirming the post-save result explains actual progress versus expected progress with the correct coaching status and suggested adjustment behavior.

**Acceptance Scenarios**:

1. **Given** an active goal plan exists, **When** the user opens Weight Hub, **Then** they can log a new weigh-in from a prominent action without losing access to the current plan overview, trend chart, edit-goal action, or weigh-in history.
2. **Given** the user logs a weigh-in and only one reading is available for the current plan, **When** the app shows coaching guidance, **Then** the status is labelled provisional and explains that a single scale reading can be noisy.
3. **Given** multiple recent weigh-ins exist, **When** the user saves a new weigh-in, **Then** the app evaluates progress using a short-term trend based on recent weigh-ins within approximately 7 days rather than relying on only the newest reading.
4. **Given** actual progress since plan start is within a small tolerance band of expected progress, **When** the user saves a weigh-in, **Then** the app classifies the user as On Track and explains that no calorie change is needed.
5. **Given** the user is cutting and progress is behind target for one check-in, **When** the user saves a weigh-in, **Then** the app suggests eating about 150 kcal/day less but labels it as a suggestion that is not yet confirmed.
6. **Given** the user is cutting and progress is behind target for two consecutive check-ins in the same direction, **When** the second off-track weigh-in is saved, **Then** the app confirms the suggestion to eat about 150 kcal/day less.
7. **Given** the user is building muscle and progress is behind target for two consecutive check-ins in the same direction, **When** the second off-track weigh-in is saved, **Then** the app confirms the suggestion to eat about 150 kcal/day more.
8. **Given** the user is ahead of target or losing/gaining too fast for two consecutive check-ins in the same direction, **When** the second off-track weigh-in is saved, **Then** the app confirms a suggestion of about 100 kcal/day in the opposite direction of the excess pace.
9. **Given** a new weigh-in has been saved, **When** the result screen or summary appears, **Then** it includes a plain-language sentence such as "You are on track," "You may need to eat a little more," or "You may need to eat a little less," plus an actual-versus-expected trend summary.

---

### User Story 3 - See Progress and Reminders from Home (Priority: P3)

As a user, I want a home-screen tile and reminder notifications so I know my latest weight, trend, on-track status, days until the next weigh-in, and today's calorie target without hunting through Settings.

**Why this priority**: The home tile and reminders make the coaching loop visible and timely, increasing follow-through after the goal plan exists.

**Independent Test**: Can be fully tested by creating a plan, changing weigh-in cadence, logging or skipping due dates, and confirming the home tile and reminder copy reflect the correct state.

**Acceptance Scenarios**:

1. **Given** no active weight goal plan exists, **When** the home screen is shown, **Then** the tile displays an empty state with "Set a weight goal" and opens Weight Hub when tapped.
2. **Given** an active plan exists, **When** the home screen is shown, **Then** the tile displays latest weight, short-term trend, color-coded on-track status, days until next weigh-in or a "Log due" nudge if overdue, and today's calorie target.
3. **Given** the tile is tapped in any state, **When** Weight Hub opens, **Then** the user lands in the appropriate context for setting a goal, reviewing progress, or logging a due weigh-in.
4. **Given** the default reminder cadence has not been changed, **When** a plan is saved, **Then** the next weigh-in reminder is scheduled for 7 days after the plan start or latest weigh-in.
5. **Given** the user selects a cadence such as every 3 days, weekly, every 2 weeks, or a custom cadence, **When** a plan is saved or edited, **Then** reminders follow that cadence.
6. **Given** a weigh-in is due, **When** the reminder is shown, **Then** the notification copy prompts the user to log a new body weight and reinforces that the check-in keeps their weight goal plan accurate.
7. **Given** the user is overdue for a weigh-in, **When** they view the tile or Weight Hub, **Then** the app shows an overdue nudge without changing the plan automatically.

---

### User Story 4 - Handle Plateaus, Maintenance, and Goal Completion (Priority: P4)

As a user, I want the app to recognize when my trend is flat, when my maintenance goal is stable, and when I reach my target so I know whether to adjust, extend the date, or switch to maintenance.

**Why this priority**: These states make the coaching loop feel complete after the core plan, logging, and reminder flows are in place.

**Independent Test**: Can be fully tested by simulating logged weigh-ins that produce a flat trend, stable maintenance trend, or target-weight achievement, then confirming the app presents the expected guidance without modifying the plan without consent.

**Acceptance Scenarios**:

1. **Given** the user's short-term trend is flat for approximately 2 consecutive check-ins while pursuing loss or muscle gain, **When** the coaching status is shown, **Then** the app identifies a possible plateau and suggests adjusting calories or extending the target date.
2. **Given** the user has a maintenance goal, **When** their trend stays within ±max(0.5 kg, 1% of body weight), **Then** the app classifies the plan as On Track for maintenance.
3. **Given** the user's trend is within a small band of the desired target weight, **When** the coaching status is shown, **Then** the app celebrates the goal reached state and offers to switch to maintenance with updated calorie and macro targets.
4. **Given** the user chooses not to switch to maintenance after reaching the goal, **When** they return to Weight Hub, **Then** the app preserves the existing plan and continues to show the reached-goal state until the user edits or replaces the plan.

### Edge Cases

- If no active plan exists, Weight Hub and the home tile must show a clear "Set a weight goal" state rather than coaching guidance.
- If only one reading exists for the plan, the coaching status must be labelled provisional and must not confirm a calorie adjustment.
- If a weigh-in is overdue, the app must nudge the user to log without assuming progress, moving the target date, or changing calorie targets automatically.
- If the selected pace enters caution or not-recommended ranges, the app must explain the risk, show safer alternatives, and still allow "save anyway."
- If progress is flat for approximately 2 consecutive check-ins, the app must identify a possible plateau and suggest either calorie adjustment or date extension.
- If the user reaches the desired weight within a small target band, the app must celebrate and offer a switch to maintenance.
- If the target date is in the past, the app must prevent saving until the user chooses a future date or valid duration.
- If desired weight equals current weight, the app must treat the plan as maintenance unless the user changes the desired weight or goal direction.
- If existing weight history is present before this feature, the app must preserve it and make it available in the upgraded history experience.
- If a newly logged weight is very different from the recent trend, the app must include it in history but avoid confirming calorie changes from that single noisy reading alone.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a Weight Hub experience for body-weight planning and progress, accessible from the existing Settings entry point that currently leads to body-weight settings.
- **FR-002**: The Weight Hub MUST show a current-plan overview, trend chart comparing actual weight against the projected goal line, log-weigh-in action, edit-goal action, and weigh-in history when an active plan exists.
- **FR-003**: The Weight Hub MUST show a clear empty state with an action to set a weight goal when no active plan exists.
- **FR-004**: Users MUST be able to create and edit a weight goal plan with goal direction, current weight, desired weight, target date or duration, and weigh-in reminder cadence.
- **FR-005**: Goal direction MUST support losing weight, building weight or muscle, and maintaining weight, reusing the user's existing profile goal when available.
- **FR-006**: The default weigh-in reminder cadence MUST be weekly, meaning 7 days between planned weigh-ins, unless the user chooses another cadence.
- **FR-007**: Users MUST be able to choose common cadence options including every 3 days, weekly, every 2 weeks, and a custom cadence.
- **FR-008**: During goal setup, the app MUST show a live readout of required weekly pace, daily calorie target, and macro suggestions for protein, fat, and carbohydrates before the user saves.
- **FR-009**: For fat-loss goals, the app MUST show a caution state when the required pace is faster than 0.5 kg per week and MUST show a not-recommended state when the required pace is 1.0 kg per week or faster.
- **FR-010**: For muscle-gain goals, the app MUST show a caution state when the required pace is faster than 0.25 kg per week and MUST show a not-recommended state when the required pace is 0.75 kg per week or faster.
- **FR-011**: When a selected pace is not recommended, the app MUST warn the user, offer to extend the timeframe, offer to use a recommended pace, and still allow the user to save anyway after acknowledging the warning.
- **FR-012**: The app MUST prevent saving a goal plan with a target date in the past.
- **FR-013**: The app MUST treat desired weight equal to current weight as a maintenance plan unless the user changes the desired weight or goal direction.
- **FR-014**: Users MUST be able to log a body-weight entry from Weight Hub and receive coaching guidance after saving.
- **FR-015**: Coaching guidance MUST use a short-term trend based on recent weigh-ins within approximately 7 days whenever enough readings exist, rather than relying only on the latest reading.
- **FR-016**: If only one reading exists for the active plan, coaching guidance MUST be labelled provisional and MUST explain that a single scale reading can be noisy.
- **FR-017**: At each weigh-in, the app MUST compare actual progress since plan start with expected progress for the same date and classify the result as On Track, Behind, Ahead, Too Fast, Unsafe, Plateau, Maintenance On Track, or Goal Reached as applicable.
- **FR-018**: The app MUST use a small tolerance band around the planned rate when deciding whether progress is On Track so normal scale fluctuations do not create unnecessary warnings.
- **FR-019**: For maintenance goals, On Track MUST mean the user remains within ±max(0.5 kg, 1% of body weight) of the maintenance reference weight.
- **FR-020**: When a cutting plan is behind target, the app MUST suggest eating about 150 kcal/day less; when a building plan is behind target, the app MUST suggest eating about 150 kcal/day more.
- **FR-021**: When a user is ahead of target or moving too fast, the app MUST suggest about 100 kcal/day in the opposite direction of the excess pace.
- **FR-022**: The app MUST NOT confirm a calorie-adjustment suggestion from one off-track check-in; confirmation requires two consecutive off-track check-ins in the same direction.
- **FR-023**: When the short-term trend is flat for approximately 2 consecutive check-ins during a loss or build goal, the app MUST identify a possible plateau and suggest adjusting calories or extending the target date.
- **FR-024**: When the user reaches the desired weight within a small target band, the app MUST celebrate the achievement and offer to switch to maintenance with updated calorie and macro targets.
- **FR-025**: The app MUST NOT automatically change the user's goal plan, calorie target, macro suggestions, or target date based on weigh-in results without the user's explicit choice.
- **FR-026**: The app MUST show post-weigh-in guidance in plain language, including whether the user likely needs to eat more, eat less, stay the course, extend the target date, or consider maintenance.
- **FR-027**: The home screen MUST include a Weight Goal tile that opens Weight Hub when tapped.
- **FR-028**: When an active plan exists, the home tile MUST show latest weight, short-term trend, on-track status with a clear visual status treatment, days until next weigh-in or a "Log due" nudge when overdue, and today's calorie target.
- **FR-029**: When no active plan exists, the home tile MUST show an empty state inviting the user to set a weight goal.
- **FR-030**: When the goal is reached, the home tile MUST show a reached-goal state and provide a path into Weight Hub to review maintenance options.
- **FR-031**: The app MUST send weigh-in reminder notifications according to the user's selected cadence, with copy that prompts logging a new body weight and explains that the check-in keeps the plan accurate.
- **FR-032**: The app MUST preserve existing body-weight history with zero data loss and include prior entries in the upgraded history experience where they are relevant to the user.
- **FR-033**: Saved plans, cadence choices, weigh-ins, coaching statuses, and goal-reached or plateau states MUST remain available after the user closes and reopens the app.
- **FR-034**: The app MUST allow the user to edit or replace an active goal plan without deleting historical weigh-ins.

### Key Entities *(include if feature involves data)*

- **Weight Goal Plan**: The user's active body-weight objective, including goal direction, starting weight, desired weight, target date or duration, planned pace, calorie target, macro suggestions, weigh-in cadence, and current lifecycle state such as active, reached, or maintenance.
- **Weigh-in Entry**: A dated body-weight reading recorded by the user, used for history, trend calculation, reminder scheduling, and actual-versus-expected progress comparisons.
- **Coaching Status**: The plain-language interpretation of progress at a check-in, including status category, confidence level such as provisional or confirmed, actual-versus-expected summary, and suggested next action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can set a weight goal, choose a target duration, and see daily calorie and macro targets in under 1 minute during usability testing.
- **SC-002**: 95% of goal setup attempts with a future target date and valid weights result in a saved plan that is visible in Weight Hub after leaving and returning.
- **SC-003**: After each saved weigh-in for an active plan, the user sees a clear coaching status and eat-more, eat-less, stay-the-course, extend-date, or maintenance suggestion within the same flow.
- **SC-004**: 100% of unsafe-pace attempts show the required caution or not-recommended warning before save while preserving the user's ability to save after acknowledgement.
- **SC-005**: 100% of one-reading coaching states are labelled provisional and do not confirm calorie changes.
- **SC-006**: Calorie adjustment suggestions are confirmed only after two consecutive off-track check-ins in the same direction in all tested loss and build scenarios.
- **SC-007**: Existing body-weight history is preserved with zero loss when the upgraded Weight Hub is introduced.
- **SC-008**: The home tile accurately reflects plan state, latest weight, due or overdue status, on-track status, and today's calorie target in all tested no-plan, active-plan, overdue, and goal-reached states.
- **SC-009**: Reminder notifications appear on the selected cadence in all tested cadence options: every 3 days, weekly, every 2 weeks, and custom.
- **SC-010**: At least 80% of users in a stakeholder review can correctly explain from the Weight Hub whether they should eat more, eat less, stay the course, or adjust the timeframe.

## Assumptions

- The app has one active user profile whose existing goal, target, and pace information can seed the Weight Hub where applicable.
- The feature uses the app's existing calorie and macro recommendation approach so the new readouts remain consistent with current profile recommendations.
- Reminder notifications are delivered by the app on the user's device and do not require a human coach or server-side coaching service.
- Body weight is measured in kilograms for this feature.
- A "small tolerance band" for on-track status is intentionally narrow enough to prevent misleading guidance but broad enough to absorb normal day-to-day scale fluctuation; exact calibration can be finalized during planning and testing without changing the product intent.
- A "small target band" for goal reached means close enough to the desired weight that the user can reasonably transition to maintenance without requiring the scale to match the target exactly.
- The first version focuses on one active weight goal plan at a time, while preserving all prior weigh-ins for history and trend context.
