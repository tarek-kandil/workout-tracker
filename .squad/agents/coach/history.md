# Coach — History

## Project Context (seeded 2026-09-04)

- **Project:** workout_tracker — a Flutter app for structured, progressive-overload training.
- **Requested by:** tarek-kandil
- **Domain model:** programs → phases (e.g. Hypertrophy, Strength, each with a `weekCount`) → WOD templates (one per session slot, `restSeconds` default 90) → template exercises (targetSets, repRangeMin/Max — reps or seconds for timed).
- **Exercise library:** global, seeded on first launch; categories Push/Pull/Legs/Core/Cardio/Other; `isTimed` distinguishes duration vs weight+reps.
- **Tracked outcomes:** session history and personal records.
- **My mandate:** Drive training features grounded in real coaching — progressive overload, periodization, sane defaults — and feed requirements to Lead (specs) and Flutter (build).

## Feature ideas backlog

- (seed) Progression suggestions based on prior session performance.
- (seed) Deload / auto-regulation cues.

## Log

- 2026-09-04 — Team assembled. Ready to shape training features.
- 2026-09-04T19:00:37+02:00 — Defined RPE→RIR semantics: RIR = 10−RPE, lower is harder, 0–5 practical range, logged and target effort remain distinct.
- 2026-09-04T19:41:59+02:00 — Defined weight-goal coaching loop defaults: trend-weight checks, pace guardrails, two-check-in confirmation, and ±150/±100 kcal nudges.
