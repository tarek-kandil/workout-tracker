# Work Routing

How to decide who handles what.

## Routing Table

| Work Type | Route To | Examples |
|-----------|----------|----------|
| Project understanding, architecture, spec authoring (Spec Kit) | Lead | "How does the WOD schema work?", "Write a spec for X", "plan this feature" |
| Code review, decomposition, work routing | Lead | "review this PR", "break this feature into tasks" |
| Flutter/Dart implementation, UI, Riverpod, Drift, charts, audio, notifications | Flutter | "build the log screen", "add a provider", "fix this widget", "write a migration" |
| Fitness/training features & methodology, progressive overload, UX for lifters | Coach | "add progression suggestions", "how should deloads work?", "new training feature idea" |
| UI/UX, usability, visual design, accessibility, design review, "Liquid Glass" theme | Designer | "is this screen usable?", "improve the dashboard layout", "review the design of X", "accessibility check" |
| Bug reproduction, tests, edge cases, quality gate | Tester | "reproduce this crash", "write tests for X", "does this break migrations?" |
| Verification, devil's advocate, pre-mortem | Fact Checker | "is this claim true?", "what could go wrong with this plan?" |
| RAI / content safety | Rai | "is this safe to ship?", "RAI check" |


## Issue Routing

| Label | Action | Who |
|-------|--------|-----|
| `squad` | Triage: analyze issue, assign `squad:{member}` label | Lead |
| `squad:{name}` | Pick up issue and complete the work | Named member |

### How Issue Assignment Works

1. When a GitHub issue gets the `squad` label, the **Lead** triages it — analyzing content, assigning the right `squad:{member}` label, and commenting with triage notes.
2. When a `squad:{member}` label is applied, that member picks up the issue in their next session.
3. Members can reassign by removing their label and adding another member's label.
4. The `squad` label is the "inbox" — untriaged issues waiting for Lead review.

## Rules

1. **Eager by default** — spawn all agents who could usefully start work, including anticipatory downstream work.
2. **Scribe always runs** after substantial work, always as `mode: "background"`. Never blocks.
3. **Quick facts → coordinator answers directly.** Don't spawn an agent for "what port does the server run on?"
4. **When two agents could handle it**, pick the one whose domain is the primary concern.
5. **"Team, ..." → fan-out.** Spawn all relevant agents in parallel as `mode: "background"`.
6. **Anticipate downstream work.** If a feature is being built, spawn the tester to write test cases from requirements simultaneously.
7. **Issue-labeled work** — when a `squad:{member}` label is applied to an issue, route to that member. The Lead handles all `squad` (base label) triage.
