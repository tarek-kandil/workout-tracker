# Squad Team

> workout_tracker

## Coordinator

| Name | Role | Notes |
|------|------|-------|
| Squad | Coordinator | Routes work, enforces handoffs and reviewer gates. |

## Members

| Name | Role | Charter | Status |
|------|------|---------|--------|
| Lead | Lead / App Architect | .squad/agents/lead/charter.md | 🏗️ Active |
| Flutter | Flutter Engineer | .squad/agents/flutter/charter.md | 📱 Active |
| Coach | Fitness Domain Expert | .squad/agents/coach/charter.md | 💪 Active |
| Tester | QA / Test Engineer | .squad/agents/tester/charter.md | 🧪 Active |
| Designer | UI/UX Designer | .squad/agents/designer/charter.md | 🎨 Active |
| Scribe | Session Logger & Memory | .squad/agents/scribe/charter.md | 📋 Built-in |
| Ralph | Work Monitor | .squad/agents/ralph/charter.md | 🔄 Built-in |
| Rai | RAI Reviewer | .squad/agents/Rai/charter.md | 🛡️ Built-in |
| Fact Checker | Verification & Devil's Advocate | .squad/agents/fact-checker/charter.md | 🔍 Built-in |

## Coding Agent

<!-- copilot-auto-assign: false -->

| Name | Role | Charter | Status |
|------|------|---------|--------|
| @copilot | Coding Agent | — | 🤖 Coding Agent |

### Capabilities

**🟢 Good fit — auto-route when enabled:**
- Bug fixes with clear reproduction steps
- Test coverage (adding missing tests, fixing flaky tests)
- Lint/format fixes and code style cleanup
- Dependency updates and version bumps
- Small isolated features with clear specs
- Boilerplate/scaffolding generation
- Documentation fixes and README updates

**🟡 Needs review — route to @copilot but flag for squad member PR review:**
- Medium features with clear specs and acceptance criteria
- Refactoring with existing test coverage
- API endpoint additions following established patterns
- Migration scripts with well-defined schemas

**🔴 Not suitable — route to squad member instead:**
- Architecture decisions and system design
- Multi-system integration requiring coordination
- Ambiguous requirements needing clarification
- Security-critical changes (auth, encryption, access control)
- Performance-critical paths requiring benchmarking
- Changes requiring cross-team discussion

## Project Context

- **Project:** workout_tracker
- **Created:** 2026-09-04
