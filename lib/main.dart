import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/database_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/weight_goal_providers.dart';
import 'screens/shell_screen.dart';
import 'screens/settings/program_setup_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load theme prefs so ThemeNotifier starts with the correct state —
  // avoids a dark→light flash on apps that have saved light mode.
  final prefs = await SharedPreferences.getInstance();
  final initialTheme = ThemeNotifier.preload(prefs);

  runApp(
    ProviderScope(
      overrides: [
        themeProvider.overrideWith(() => ThemeNotifier(initialTheme)),
      ],
      child: const WorkoutTrackerApp(),
    ),
  );
}

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
    // Configure audio to play in background (when app is locked/backgrounded)
    await AudioPlayer.global.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gain,
        contentType: AndroidContentType.sonification,
        isSpeakerphoneOn: false,
        stayAwake: true,
      ),
    ));

    await NotificationService.init();

    // Roll the weigh-in reminder forward on every app start when a plan
    // exists — cheap no-op (cancels) when there's no active plan.
    await ref.read(weightGoalActionsProvider).rescheduleReminder();

    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool('exercises_seeded') ?? false;

    if (!seeded) {
      final db = ref.read(databaseProvider);
      await db.exercisesDao.seedExercises(kDefaultExercises);
      await prefs.setBool('exercises_seeded', true);
    }

    final musclesSeeded = prefs.getBool('muscles_seeded_v1') ?? false;
    if (!musclesSeeded) {
      final db = ref.read(databaseProvider);
      final dao = db.exercisesDao;

      // 1. Insert exercises that don't exist yet (by name).
      final existingByName = await dao.getExerciseIdsByName();
      for (final companion in kDefaultExercises) {
        final name = companion.name.value;
        if (!existingByName.containsKey(name)) {
          final newId = await dao.insertExercise(companion);
          existingByName[name] = newId;
        }
      }

      // 2. Seed muscle assignments for every exercise in kExerciseMuscles.
      for (final entry in kExerciseMuscles.entries) {
        final id = existingByName[entry.key];
        if (id != null) {
          await dao.setMusclesForExercise(id, entry.value);
        }
      }

      await prefs.setBool('muscles_seeded_v1', true);
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
