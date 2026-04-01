import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/database_provider.dart';
import 'screens/shell_screen.dart';
import 'screens/settings/program_setup_screen.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: WorkoutTrackerApp(),
    ),
  );
}

ThemeData _buildTheme() {
  const seedColor = Color(0xFF3D6BF8);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0D1117),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF161C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFF0D1117),
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0D1117),
      elevation: 0,
      height: 64,
      surfaceTintColor: Colors.transparent,
      indicatorColor: seedColor.withValues(alpha: 0.22),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: seedColor);
        }
        return TextStyle(
            fontSize: 12, color: Colors.white.withValues(alpha: 0.55));
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: seedColor);
        }
        return IconThemeData(color: Colors.white.withValues(alpha: 0.55));
      }),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withValues(alpha: 0.08),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1C2438),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: seedColor),
      ),
      isDense: true,
    ),
  );
}

class WorkoutTrackerApp extends ConsumerWidget {
  const WorkoutTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Workout Tracker',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const _AppStartup(),
      routes: {
        '/program-setup': (_) => const ProgramSetupScreen(),
      },
    );
  }
}

// Handles first-launch seeding before showing the main UI
class _AppStartup extends ConsumerStatefulWidget {
  const _AppStartup();

  @override
  ConsumerState<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<_AppStartup> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await NotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool('exercises_seeded') ?? false;

    if (!seeded) {
      final db = ref.read(databaseProvider);
      await db.exercisesDao.seedExercises(kDefaultExercises);
      await prefs.setBool('exercises_seeded', true);
    }

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const ShellScreen();
  }
}
