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
    return (
      brightness: Brightness.dark,
      palette: AppPaletteLibrary.defaultPalette,
    );
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
    final newBrightness = state.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    state = (brightness: newBrightness, palette: state.palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyBrightness,
      newBrightness == Brightness.dark ? 'dark' : 'light',
    );
  }

  Future<void> setPalette(AppPalette palette) async {
    state = (brightness: state.brightness, palette: palette);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPalette, palette.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
