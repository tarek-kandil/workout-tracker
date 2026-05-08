import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      secondary: palette.secondary,
      surface: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F8FF),
    );

    final scaffoldBg =
        isDark ? const Color(0xFF080E1E) : const Color(0xFFDCEDFF);
    final appBarBg = isDark
        ? const Color(0xCC080E1E)
        : const Color(0xCCDCEDFF);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: GoogleFonts.spaceGroteskTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
