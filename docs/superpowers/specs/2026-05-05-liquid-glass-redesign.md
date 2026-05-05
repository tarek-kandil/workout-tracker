# Liquid Glass Redesign — Full App

**Date:** 2026-05-05  
**Status:** Approved

## Goal

Replace all hardcoded colours and ad-hoc glass styling with a centralised theme system (palette + brightness), redesign the home screen in Option B style, and apply consistent glass card surfaces across every screen. The design must support manual dark/light toggle and easy palette swapping in the future.

---

## 1. Theme System

### Files
- `lib/theme/app_theme.dart` — `AppPalette`, `AppPaletteLibrary`, `AppThemeData`
- `lib/providers/theme_provider.dart` — `ThemeNotifier`, `themeProvider`, `brightnessProvider`

### AppPalette
A simple immutable data class:

```dart
class AppPalette {
  final String name;
  final Color primary;    // main accent (buttons, active states, glows)
  final Color secondary;  // highlight accent (gradient pair, rim lights)
  const AppPalette({required this.name, required this.primary, required this.secondary});
}
```

### AppPaletteLibrary
A static list of predefined palettes. The default is **Cobalt/Cyan**:

```dart
class AppPaletteLibrary {
  static const cobaltCyan = AppPalette(
    name: 'Cobalt Cyan',
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF06B6D4),
  );
  // Future palettes added here without touching any other file
  static const all = [cobaltCyan];
  static const defaultPalette = cobaltCyan;
}
```

### AppThemeData
Generates a `ThemeData` from a palette + brightness. All colour decisions are derived from `palette.primary` and `palette.secondary` — no screen or widget contains hardcoded hex values after this change.

Key derivations:
- `ColorScheme.fromSeed(seedColor: palette.primary, brightness: brightness)` as the base
- `primary` overridden to `palette.primary`
- `secondary` overridden to `palette.secondary`
- `surface` / `background`: dark → `#080e1e`-family; light → `#dcedff`-family (tinted from palette)
- `CardTheme`, `FilledButtonTheme`, `AppBarTheme`, `NavigationBarTheme`, `InputDecorationTheme` all defined here — moving them out of `main.dart`

### ThemeNotifier
Riverpod `Notifier<({Brightness brightness, AppPalette palette})>` stored in SharedPreferences keys `theme_brightness` (`dark`/`light`) and `theme_palette` (palette name string).

```dart
final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
```

`ThemeState = ({Brightness brightness, AppPalette palette})`

Expose `toggleBrightness()` and `setPalette(AppPalette)` methods.

### Wiring in main.dart
`MaterialApp` watches `themeProvider`:
```dart
theme: AppThemeData.light(state.palette),
darkTheme: AppThemeData.dark(state.palette),
themeMode: state.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
```

`GlassBackground` blob colours are updated to use `palette.primary` and `palette.secondary` instead of hardcoded Indigo/Sky Blue. Pass them via `InheritedWidget` or read from `themeProvider`.

---

## 2. Shared GlassCard Widget

**File:** `lib/widgets/glass_card.dart`

A single `GlassCard` widget replaces all ad-hoc glass surface styling across the app. Wraps `LiquidGlassContainer` with opinionated defaults derived from the current theme — no parameters needed for the common case:

```dart
GlassCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(16),
  double borderRadius = 20,
  Color? tintColor,   // defaults to Theme primary at 8% opacity
})
```

All screens that currently use `LiquidGlassContainer` directly or hand-roll `Container` + `BackdropFilter` glass cards switch to `GlassCard`.

---

## 3. Home Screen — Option B Layout

**Files modified:** `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/active_program_card.dart`, `lib/screens/home/widgets/next_workout_card.dart`

**Files deleted:** `lib/screens/home/widgets/streak_card.dart`, `lib/screens/home/widgets/bodyweight_card.dart` (content merged into home screen directly)

Layout (top to bottom):
1. **App bar** — large title "Today", no surface tint, floating
2. **Hero card** (`GlassCard`) — "UP NEXT · WEEK X" small badge, workout name (`titleLarge`), detail line (exercise count, est. duration), thin progress bar (% through program week), full-width "Start Workout" `FilledButton`
3. **Stat row** — 3 equal `GlassCard` chips: Streak / Sessions / Week
4. **Daily tasks** — section label "DAILY TASKS", one `GlassCard` row per enabled task (icon + name + unchecked circle)
5. **No-program state** — centred `GlassCard` with icon, message, "Create Program" button

No hardcoded colours anywhere in home widgets — all from `Theme.of(context).colorScheme`.

---

## 4. Shell / Navigation Bar

**File:** `lib/screens/shell_screen.dart`

Update the floating nav bar to derive colours from `Theme.of(context)`:
- Background: `colorScheme.surface.withOpacity(0.65)` instead of hardcoded `0xFF1E293B`
- Border: `colorScheme.outline.withOpacity(0.13)`
- Active indicator: `colorScheme.primary`
- Inactive icon colour: `colorScheme.onSurface.withOpacity(0.45)`

The 3D flip page transition and backdrop blur are preserved as-is.

---

## 5. History Screens

**Files:** `lib/screens/history/session_history_screen.dart`, `lib/screens/history/session_detail_screen.dart`

- Session tiles: switch to `GlassCard` (remove hardcoded `0x26000000` background and `0.09` border)
- Week headers: accent bar uses `colorScheme.primary`
- Session detail: exercise sections and set rows use `colorScheme.surface` / `GlassCard`

---

## 6. Settings Screens

**Files:** `lib/screens/settings/settings_screen.dart` + all settings sub-screens

- `settings_screen.dart`: add **Appearance** section at the top with a dark/light mode toggle row (sun/moon icon + `Switch` wired to `themeProvider.toggleBrightness()`)
- All settings list tiles: derive background from `colorScheme.surface`
- Form inputs: already themed via `InputDecorationTheme` in `AppThemeData`
- Program setup, WOD setup, exercise library: section headers and card surfaces use `GlassCard`

---

## 7. Records Screens

**Files:** `lib/screens/records/personal_records_screen.dart`, `lib/screens/records/exercise_history_screen.dart`

- PR cards and exercise history rows: switch to `GlassCard`
- Accent highlights (PR badge, chart colours) use `colorScheme.primary` / `colorScheme.secondary`

---

## 8. Active Session Screen

**File:** `lib/screens/log/active_session_screen.dart`

The screen was recently redesigned. This pass only removes hardcoded hex values:
- Exercise card border/background colours → `colorScheme.primary`, `colorScheme.surface`
- Circuit card teal → `colorScheme.secondary`
- Rest pill background → `colorScheme.surface.withOpacity(0.85)`
- All `Color(0xFF...)` literals → theme-derived values

The layout and interaction logic are untouched.

---

## 9. Daily Tasks Screen

**File:** `lib/screens/tasks/daily_tasks_screen.dart`

Task rows styled with `GlassCard`. Accent colours from `colorScheme.primary`.

---

## Out of Scope

- User-facing palette picker UI (the system is built for it, but the Settings UI for switching palettes is not included — only the brightness toggle)
- Animated palette transitions
- Per-screen custom palette overrides
- Changing `GlassBackground` blob animations
