# Rest Timer Pill — UX Redesign

**Date:** 2026-05-05  
**Status:** Approved

## Problem

The current rest timer covers the entire screen (`Positioned.fill` overlay), blocking all interaction with the workout list. Users cannot scroll, swap, skip, or add exercises while resting — they are forced to sit idle until the timer ends or they tap Skip.

## Design

### 1. Pill Widget — Visual

A slim fixed bar (~60 px tall) pinned at `top: 8` inside the body `Stack`, above the `ListView` but below the `AppBar`. It animates in with a slide-down + fade-in when rest starts and slides back up on dismiss.

Layout left-to-right:

```
[ ◷ 1:23  |  Next up: Bench Press · Set 2/3          ⏭ Skip ]
```

- **Left:** small circular arc `CircularProgressIndicator` (shrinks as time runs out) with `MM:SS` countdown beside it, coloured with the app's tertiary colour
- **Centre (Expanded):** `"Next up: [exercise name] · [set label]"` in subdued white — uses the existing `_getNextLabel()` output
- **Right:** small `⏭ Skip` text button — calls `_skipRest()`

Background: `Colors.black.withValues(alpha: 0.82)` with a `BorderRadius.circular(16)` and a 1px white-12 border. Matches the app's dark glass aesthetic.

### 2. Behaviour

- Pill appears the moment `_startRest()` is called
- `ListView` gains `padding.top` of **72 px** while `_resting == true` (reverts to **8 px** when rest ends) so no card is hidden behind the pill
- **"Finish Workout" button is always visible** — `bottomNavigationBar` is no longer set to `null` during rest
- Tapping **⏭ Skip** calls the existing `_skipRest()`; pill dismisses immediately
- When timer hits zero the pill dismisses automatically; the existing beep and autopilot countdown behaviour are unchanged
- `_RestTimerOverlay` widget is deleted entirely

### 3. Notification Bar

No structural change to `_updateNotification()`. The notification body text during rest is updated to use the format `"Next up: [name] · Set X/Y"` to match the pill copy, instead of the current generic next-label string.

## Out of Scope

- Persistent/draggable pill position
- Expanding the pill to show full timer details on tap
- Any changes to rest duration settings
