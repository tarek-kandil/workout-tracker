# Liquid Glass Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all hardcoded hex colours with a centralised theme system (AppPalette + Brightness), redesign the home screen in Option B style, and apply consistent glass card surfaces across every screen with manual dark/light toggle.

**Architecture:** Introduce `AppThemeData` (static factory for ThemeData from palette + brightness), `ThemeNotifier` (Riverpod Notifier persisted to SharedPreferences), and `GlassCard` (thin wrapper around `LiquidGlassContainer`). Update `MaterialApp` to drive `theme`/`darkTheme`/`themeMode` from `themeProvider`. Update every widget that hardcodes hex colours to read from `Theme.of(context).colorScheme`.

**Tech Stack:** Flutter, Riverpod (Notifier), SharedPreferences, existing `LiquidGlassContainer`.

---

## File Map

| File | Action |
|---|---|
| `lib/theme/app_theme.dart` | **Create** — AppPalette, AppPaletteLibrary, AppThemeData |
| `lib/providers/theme_provider.dart` | **Create** — ThemeState typedef, ThemeNotifier, themeProvider |
| `lib/widgets/glass_card.dart` | **Create** — GlassCard shared widget |
| `lib/widgets/glass_background.dart` | **Modify** — blob colors from `Theme.of(context)` |
| `lib/widgets/liquid_glass_container.dart` | **Modify** — rim-light from `Theme.of(context).colorScheme.secondary` |
| `lib/main.dart` | **Modify** — wire MaterialApp to themeProvider, remove _buildTheme() |
| `lib/screens/home/home_screen.dart` | **Modify** — Option B layout (hero card, stat row, daily tasks) |
| `lib/screens/home/widgets/next_workout_card.dart` | **Modify** — compact hero card, VibrantText gradient from theme |
| `lib/screens/home/widgets/active_program_card.dart` | **Modify** — VibrantText gradient hardcodes removed |
| `lib/screens/home/widgets/streak_card.dart` | **Delete** — absorbed into home screen stat row |
| `lib/screens/home/widgets/bodyweight_card.dart` | **Delete** — removed from home (was unused in Option B) |
| `lib/screens/shell_screen.dart` | **Modify** — nav bar background from `colorScheme.surface` |
| `lib/screens/history/session_history_screen.dart` | **Modify** — session tiles use theme colours |
| `lib/screens/settings/settings_screen.dart` | **Modify** — add Appearance section with dark/light toggle |
| `lib/screens/records/personal_records_screen.dart` | **Modify** — record tiles use theme colours |
| `lib/screens/log/active_session_screen.dart` | **Modify** — replace hardcoded hex only |
| `lib/screens/tasks/daily_tasks_screen.dart` | **Modify** — dimmed color from theme |

---

### Task 1 — Create `lib/theme/app_theme.dart`

**Files:** Create `lib/theme/app_theme.dart`

- [ ] **Create the file with AppPalette, AppPaletteLibrary, and AppThemeData**

```dart
import 'package:flutter/material.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────

class AppPalette {
  final String name;
  final Color primary;   // main accent (buttons, active states, glows)
  final Color secondary; // highlight accent (gradient pair, rim lights)

  const AppPalette({
    required this.name,
    required this.primary,
    required this.secondary,
  });
}

// ─── Palette library ──────────────────────────────────────────────────────────

class AppPaletteLibrary {
  static const cobaltCyan = AppPalette(
    name: 'Cobalt Cyan',
    primary: Color(0xFF2563EB),
    secondary: Color(0xFF06B6D4),
  );

  static const all = [cobaltCyan];
  static const defaultPalette = cobaltCyan;

  AppPaletteLibrary._();
}

// ─── Theme builder ────────────────────────────────────────────────────────────

class AppThemeData {
  AppThemeData._();

  static ThemeData dark(AppPalette palette) => _build(palette, Brightness.dark);
  static ThemeData light(AppPalette palette) => _build(palette, Brightness.light);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Base colour scheme derived from palette
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      secondary: palette.secondary,
      surface: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F8FF),
    );

    final scaffoldBg = isDark ? const Color(0xFF080E1E) : const Color(0xFFDCEDFF);
    final appBarBg = isDark
        ? const Color(0xCC080E1E) // ~80% opacity deep dark
        : const Color(0xCCDCEDFF); // ~80% opacity light tint

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: isDark ? const Color(0xF2F8FAFC) : const Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? const Color(0xF2F8FAFC) : const Color(0xFF0F172A),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        elevation: 0,
        height: 64,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primary.withValues(alpha: 0.22),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: palette.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.45),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: palette.primary);
          }
          return IconThemeData(
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.45),
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.secondary),
        ),
        isDense: true,
      ),
    );
  }
}
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/theme/app_theme.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 2 — Create `lib/providers/theme_provider.dart`

**Files:** Create `lib/providers/theme_provider.dart`

- [ ] **Create the file with ThemeNotifier and themeProvider**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

typedef ThemeState = ({Brightness brightness, AppPalette palette});

class ThemeNotifier extends Notifier<ThemeState> {
  static const _keyBrightness = 'theme_brightness';
  static const _keyPalette = 'theme_palette';

  @override
  ThemeState build() {
    _loadFromPrefs(); // fire-and-forget — updates state when prefs load
    return (brightness: Brightness.dark, palette: AppPaletteLibrary.defaultPalette);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bStr = prefs.getString(_keyBrightness) ?? 'dark';
    final pName = prefs.getString(_keyPalette) ?? '';
    state = (
      brightness: bStr == 'light' ? Brightness.light : Brightness.dark,
      palette: AppPaletteLibrary.all.firstWhere(
        (p) => p.name == pName,
        orElse: () => AppPaletteLibrary.defaultPalette,
      ),
    );
  }

  Future<void> toggleBrightness() async {
    final newBrightness =
        state.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    state = (brightness: newBrightness, palette: state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyBrightness, newBrightness == Brightness.dark ? 'dark' : 'light');
  }

  Future<void> setPalette(AppPalette palette) async {
    state = (brightness: state.brightness, palette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPalette, palette.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/providers/theme_provider.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 3 — Create `lib/widgets/glass_card.dart`

**Files:** Create `lib/widgets/glass_card.dart`

- [ ] **Create the GlassCard widget**

```dart
import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

/// Opinionated glass card surface. Wraps [LiquidGlassContainer] with
/// defaults derived from the current theme — no parameters needed for the
/// common case.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tintColor; // defaults to Theme primary at 8% opacity

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTint =
        tintColor ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return LiquidGlassContainer(
      borderRadius: borderRadius,
      tintColor: effectiveTint,
      blurSigma: 18,
      padding: padding,
      child: child,
    );
  }
}
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/widgets/glass_card.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 4 — Update `lib/widgets/liquid_glass_container.dart` — rim-light from theme

**Files:** Modify `lib/widgets/liquid_glass_container.dart`

- [ ] **Update `_RimLight` to read `colorScheme.secondary` instead of hardcoded Electric Sky**

Replace the entire `_RimLight` class:

```dart
// ─── Rim-light: gradient border via 0.8px nested padding ──────────────────────

class _RimLight extends StatelessWidget {
  final double borderRadius;
  final Widget child;

  const _RimLight({required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) {
    final rimColor =
        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rimColor,
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.8),
        child: child,
      ),
    );
  }
}
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/widgets/liquid_glass_container.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 5 — Update `lib/widgets/glass_background.dart` — blob colors from theme

**Files:** Modify `lib/widgets/glass_background.dart`

- [ ] **Update `_GlassBackgroundState.build()` to use theme colors for blobs**

Replace the `build` method of `_GlassBackgroundState`:

```dart
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = _ctrl.value;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final cs = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              top: lerpDouble(-60, 20, t),
              right: lerpDouble(-40, 40, t),
              child: _Blob(color: cs.primary, opacity: 0.24, size: 280),
            ),
            Positioned(
              top: lerpDouble(200, 280, t),
              left: lerpDouble(-80, -20, t),
              child: _Blob(color: cs.secondary, opacity: 0.18, size: 240),
            ),
            Positioned(
              bottom: lerpDouble(60, 140, t),
              right: lerpDouble(20, 80, t),
              child: _Blob(color: cs.primary, opacity: 0.15, size: 220),
            ),
          ],
        );
      },
    );
  }
```

Note: `_Blob` takes `color` as a regular (non-const) parameter now — remove the `const` keyword from the `_Blob(...)` calls since `cs.primary` is not a compile-time constant.

Also update the `_Blob` constructor to remove `const` requirement (it already takes non-const Color, so the widget itself is fine — just ensure the callers don't use `const`).

- [ ] **Remove the unused `cs` and `t` variables outside the AnimatedBuilder** — the new build method above has no outer `t` / `cs` declarations. Make sure the replacement matches exactly (the outer variables shown above the AnimatedBuilder were mistakenly included — keep only the AnimatedBuilder's builder content).

The correct final `build` method:

```dart
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final cs = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              top: lerpDouble(-60, 20, t),
              right: lerpDouble(-40, 40, t),
              child: _Blob(color: cs.primary, opacity: 0.24, size: 280),
            ),
            Positioned(
              top: lerpDouble(200, 280, t),
              left: lerpDouble(-80, -20, t),
              child: _Blob(color: cs.secondary, opacity: 0.18, size: 240),
            ),
            Positioned(
              bottom: lerpDouble(60, 140, t),
              right: lerpDouble(20, 80, t),
              child: _Blob(color: cs.primary, opacity: 0.15, size: 220),
            ),
          ],
        );
      },
    );
  }
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/widgets/glass_background.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 6 — Update `lib/main.dart` — wire MaterialApp to themeProvider

**Files:** Modify `lib/main.dart`

- [ ] **Add imports for AppThemeData and themeProvider**

Add at the top with the other imports:

```dart
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
```

- [ ] **Replace `_buildTheme()` function and update `WorkoutTrackerApp.build()`**

Delete the entire `_buildTheme()` function (lines 21–112 in the current file).

Replace the `WorkoutTrackerApp` class:

```dart
class WorkoutTrackerApp extends ConsumerWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.light(themeState.palette),
      darkTheme: AppThemeData.dark(themeState.palette),
      themeMode: themeState.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: const _AppStartup(),
      routes: {
        '/program-setup': (_) => const ProgramSetupScreen(),
      },
    );
  }
}
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/main.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

- [ ] **Commit the theme system (Tasks 1–6)**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/theme/app_theme.dart lib/providers/theme_provider.dart lib/widgets/glass_card.dart lib/widgets/liquid_glass_container.dart lib/widgets/glass_background.dart lib/main.dart && git commit -m "feat: centralised theme system — AppPalette, ThemeNotifier, GlassCard, rim-light from theme"
```

---

### Task 7 — Update `lib/screens/shell_screen.dart` — nav bar from theme

**Files:** Modify `lib/screens/shell_screen.dart`

The nav bar background is currently hardcoded `const Color(0xFF1E293B).withValues(alpha: 0.65)`. Update it to `colorScheme.surface.withValues(alpha: 0.65)`. The `accent` variable already reads from `colorScheme.primary` — keep that.

- [ ] **Update the background color in `_FloatingNavBar.build()`**

In `_FloatingNavBar.build()`, find:

```dart
            color: const Color(0xFF1E293B).withValues(alpha: 0.65),
```

Replace with:

```dart
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/shell_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 8 — Add Appearance section to `lib/screens/settings/settings_screen.dart`

**Files:** Modify `lib/screens/settings/settings_screen.dart`

Add the dark/light toggle at the top of the settings screen as an Appearance section.

- [ ] **Add theme_provider import**

Add to the imports at the top:
```dart
import '../../providers/theme_provider.dart';
import '../../widgets/glass_card.dart';
```

- [ ] **Add Appearance section before the Training group**

In `SettingsScreen.build()`, inside the `ListView` children list, add this block before the `_SectionLabel(label: 'TRAINING')` line:

```dart
              // ── Appearance group ────────────────────────────────────────
              _SectionLabel(label: 'APPEARANCE'),
              const SizedBox(height: 8),
              GlassCard(
                borderRadius: 20,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        ref.watch(themeProvider).brightness == Brightness.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Dark Mode',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Switch(
                        value: ref.watch(themeProvider).brightness ==
                            Brightness.dark,
                        onChanged: (_) =>
                            ref.read(themeProvider.notifier).toggleBrightness(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/settings/settings_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 9 — Update history screen tiles to use theme colours

**Files:** Modify `lib/screens/history/session_history_screen.dart`

The `_SessionTile` widget uses hardcoded `Color(0x26000000)` background and `0.09` border. Update to theme-derived colours and replace `Colors.white.withValues(alpha: 0.4)` empty-state color.

- [ ] **Update `_SessionTile.build()` container decoration**

Find:
```dart
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x26000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
```

Replace with:
```dart
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
```

- [ ] **Update empty-state text color**

Find:
```dart
                        color: Colors.white.withValues(alpha: 0.4),
```

Replace with:
```dart
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/history/session_history_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 10 — Update records screen tiles to use theme colours

**Files:** Modify `lib/screens/records/personal_records_screen.dart`

The `_RecordTile` uses hardcoded `Color(0x26000000)` and `0.09` border.

- [ ] **Update `_RecordTile.build()` container decoration**

Find:
```dart
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x26000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
```

Replace with:
```dart
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
```

- [ ] **Update empty-state text color**

Find:
```dart
                        color: Colors.white.withValues(alpha: 0.4),
```

Replace with:
```dart
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/records/personal_records_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 11 — Update `lib/screens/tasks/daily_tasks_screen.dart` — dimmed color from theme

**Files:** Modify `lib/screens/tasks/daily_tasks_screen.dart`

The `_TaskTile.build()` uses `Colors.white.withValues(alpha: 0.38)` for the strikethrough/dimmed text in dark mode — this is wrong in light mode.

- [ ] **Update `dimmed` color in `_TaskTile.build()`**

Find:
```dart
    final dimmed = Colors.white.withValues(alpha: 0.38);
```

Replace with:
```dart
    final dimmed = theme.colorScheme.onSurface.withValues(alpha: 0.38);
```

- [ ] **Verify no syntax errors**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/tasks/daily_tasks_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

---

### Task 12 — Update `lib/screens/log/active_session_screen.dart` — remove hardcoded hex

**Files:** Modify `lib/screens/log/active_session_screen.dart`

Remove hex-hardcoded colours for the modal sheet background (3 locations) and the circuit teal colour (2 locations).

- [ ] **Replace `Color(0xFF1A1A2E)` bottom sheet backgrounds (3 occurrences)**

These appear inside `showModalBottomSheet` calls. Each occurrence looks like:

```dart
      backgroundColor: const Color(0xFF1A1A2E),
```

Replace all 3 with:
```dart
      backgroundColor: Theme.of(context).colorScheme.surface,
```

Use replace_all for this change (3 identical occurrences).

- [ ] **Replace circuit teal colour — first location (`_CircuitCard`)**

Find (around line 1615):
```dart
    const teal = Color(0xFF14B8A6);
```

Replace with:
```dart
    final teal = Theme.of(context).colorScheme.secondary;
```

- [ ] **Replace circuit teal colour — second location (`_CircuitExerciseSection`)**

Find (around line 1797):
```dart
    const teal = Color(0xFF14B8A6);
```

Replace with:
```dart
    final teal = Theme.of(context).colorScheme.secondary;
```

- [ ] **Replace remaining inline teal hex in circuit divider**

Find:
```dart
          const Divider(height: 1, color: Color(0x1414B8A6)),
```

Replace with:
```dart
          Divider(height: 1, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08)),
```

- [ ] **Replace inline teal hex in loop icon and title**

Find both:
```dart
              const Icon(Icons.loop, size: 14, color: Color(0xFF14B8A6)),
```
and:
```dart
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF14B8A6)),
```

For the icon, replace with:
```dart
              Icon(Icons.loop, size: 14, color: Theme.of(context).colorScheme.secondary),
```

For the text style (inside a widget with `context`), replace with:
```dart
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.secondary),
```

- [ ] **Replace purple add-exercise icon color**

Find:
```dart
          leading: const Icon(Icons.add_circle_outline, color: Colors.purple),
```

Replace with:
```dart
          leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
```

- [ ] **Verify compile**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/log/active_session_screen.dart 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

- [ ] **Commit Tasks 7–12 (non-home screen)**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/shell_screen.dart lib/screens/settings/settings_screen.dart lib/screens/history/session_history_screen.dart lib/screens/records/personal_records_screen.dart lib/screens/tasks/daily_tasks_screen.dart lib/screens/log/active_session_screen.dart && git commit -m "feat: theme-derived colours across all screens — shell, settings, history, records, tasks, active session"
```

---

### Task 13 — Redesign home screen — Option B layout

**Files:** Modify `lib/screens/home/home_screen.dart`, `lib/screens/home/widgets/next_workout_card.dart`, `lib/screens/home/widgets/active_program_card.dart`
**Delete:** `lib/screens/home/widgets/streak_card.dart`, `lib/screens/home/widgets/bodyweight_card.dart`

The new layout:
1. Floating app bar: "Today"
2. Hero card (`NextWorkoutCard` redesigned): "UP NEXT · WEEK X" badge, workout name, summary line, progress bar, "Start Workout"
3. Stat row: 3 `GlassCard` chips (Streak / Sessions / Current Week)
4. Daily tasks section
5. No-program state: centred GlassCard

- [ ] **Rewrite `lib/screens/home/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/program_providers.dart';
import '../../providers/daily_tasks_providers.dart';
import '../../providers/home_providers.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import 'widgets/active_program_card.dart';
import 'widgets/daily_task_home_card.dart';
import 'widgets/next_workout_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramAsync = ref.watch(activeProgramProvider);
    final tasksAsync = ref.watch(dailyTasksProvider);

    return Stack(
      children: [
        const Positioned.fill(child: GlassBackground()),
        CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Today'),
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: activeProgramAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
                data: (program) {
                  final enabledTasks = (tasksAsync.valueOrNull ?? [])
                      .where((t) => t.isEnabled)
                      .toList();
                  if (program == null) {
                    return _buildNoProgramState(context, enabledTasks);
                  }
                  return _buildDashboard(context, ref, enabledTasks);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoProgramState(BuildContext context, List enabledTasks) {
    return SliverList(
      delegate: SliverChildListDelegate([
        GlassCard(
          borderRadius: 32,
          child: Column(
            children: [
              Icon(Icons.fitness_center,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'No Active Program',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Set up a workout program to get started with guided training.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/program-setup'),
                icon: const Icon(Icons.add),
                label: const Text('Create Program'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (enabledTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SectionLabel(label: 'DAILY TASKS'),
          const SizedBox(height: 8),
          ...enabledTasks.expand((t) => [
                DailyTaskHomeCard(task: t),
                const SizedBox(height: 8),
              ]),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildDashboard(
      BuildContext context, WidgetRef ref, List enabledTasks) {
    final streakAsync = ref.watch(workoutStreakProvider);
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final weekAsync = ref.watch(currentProgramWeekProvider);

    final streak = streakAsync.valueOrNull ?? 0;
    final sessions = sessionsAsync.valueOrNull?.length ?? 0;
    final week = weekAsync.valueOrNull ?? 1;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Hero card ────────────────────────────────────────────────────
        const NextWorkoutCard(),
        const SizedBox(height: 12),

        // ── Stat row ─────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Streak', value: '$streak wk')),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Sessions', value: '$sessions')),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Week', value: 'W$week')),
          ],
        ),
        const SizedBox(height: 16),

        // ── Daily tasks ──────────────────────────────────────────────────
        if (enabledTasks.isNotEmpty) ...[
          _SectionLabel(label: 'DAILY TASKS'),
          const SizedBox(height: 8),
          ...enabledTasks.expand((t) => [
                DailyTaskHomeCard(task: t),
                const SizedBox(height: 8),
              ]),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
```

- [ ] **Update `NextWorkoutCard` — remove hardcoded gradient colors in VibrantText**

In `lib/screens/home/widgets/next_workout_card.dart`, find the `VibrantText` for "NEXT UP" with hardcoded gradient:

```dart
                    VibrantText(
                      'NEXT UP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                      gradientColors: const [
                        Color(0xFF38BDF8),
                        Color(0xFF818CF8),
                      ],
                    ),
```

Replace with:
```dart
                    Builder(builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return VibrantText(
                        'NEXT UP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                        gradientColors: [cs.secondary, cs.primary],
                      );
                    }),
```

- [ ] **Update `ActiveProgramCard` — remove hardcoded gradient if any**

In `lib/screens/home/widgets/active_program_card.dart`, the card already reads `primary` and `tertiary` from `Theme.of(context).colorScheme` — no hardcoded gradient hex values. Confirm no `Color(0xFF...)` literals remain in this file:

```bash
grep -n "Color(0x" "/Users/Tarek/Developer/Workout Planner/workout_tracker/lib/screens/home/widgets/active_program_card.dart"
```

If none found, no changes needed.

- [ ] **Delete `streak_card.dart` and `bodyweight_card.dart`**

```bash
rm "/Users/Tarek/Developer/Workout Planner/workout_tracker/lib/screens/home/widgets/streak_card.dart"
rm "/Users/Tarek/Developer/Workout Planner/workout_tracker/lib/screens/home/widgets/bodyweight_card.dart"
```

- [ ] **Verify compile for home screen files**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze lib/screens/home/ 2>&1 | grep -E "^  error" | head -30
```
Expected: no errors.

- [ ] **Full app analyze**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze 2>&1 | grep -E "^  error" | head -30
```
Expected: no errors.

- [ ] **Commit home screen redesign**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add lib/screens/home/ && git commit -m "feat: home screen Option B — hero card, stat row, daily tasks section"
```

---

### Task 14 — Update settings screen section labels and remove remaining hardcoded whites

**Files:** Modify `lib/screens/settings/settings_screen.dart`

The `_SectionLabel` widget uses `Colors.white.withValues(alpha: 0.4)`. Update to `colorScheme.onSurface.withValues(alpha: 0.45)`.

- [ ] **Update `_SectionLabel.build()`**

Find:
```dart
              color: Colors.white.withValues(alpha: 0.4),
```

Replace with:
```dart
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
```

- [ ] **Verify and build**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter analyze 2>&1 | grep -E "^  error" | head -20
```
Expected: no errors.

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && flutter build apk --debug 2>&1 | tail -5
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Final commit**

```bash
cd "/Users/Tarek/Developer/Workout Planner/workout_tracker" && git add -p && git commit -m "feat: liquid glass redesign complete — theme system, Option B home, dark/light toggle across all screens"
```
