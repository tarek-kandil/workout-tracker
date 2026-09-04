import 'dart:async';

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

/// A short timeout applied to non-critical native/plugin calls during
/// startup so a hung platform channel can never leave the app stuck on the
/// splash spinner forever.
const _nonCriticalStepTimeout = Duration(seconds: 5);

/// Outcome of [runAppStartup]. Startup only ever reports [fatalError] when
/// the local database itself cannot be opened/migrated — every other step
/// is non-critical and swallows its own errors so the app can always boot.
class StartupResult {
  final bool success;
  final Object? fatalError;

  const StartupResult.ready()
      : success = true,
        fatalError = null;

  const StartupResult.fatal(Object error)
      : success = false,
        fatalError = error;
}

/// Runs the full app-startup sequence. Extracted from [_AppStartupState] so
/// it can be exercised directly in tests via a plain [ProviderContainer]
/// instead of a full widget tree.
///
/// Every non-critical step below (audio context, notifications init,
/// first-launch seeding, weigh-in reminder reschedule) is wrapped in its
/// own try/catch so a single failure can never abort the others or block
/// the app from reaching [ShellScreen] — this is what caused the
/// production "infinite spinner" bug (an unguarded async chain where any
/// throw meant `_ready` was never set). Only a database open/migration
/// failure is treated as fatal.
Future<StartupResult> runAppStartup(ProviderContainer container) async {
  // (a) Configure audio to play in background (when app is locked/backgrounded).
  try {
    await AudioPlayer.global
        .setAudioContext(AudioContext(
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
        ))
        .timeout(_nonCriticalStepTimeout);
  } catch (e) {
    debugPrint('Startup: audio context setup failed (non-fatal): $e');
  }

  // (b) Notifications init — non-critical.
  try {
    await NotificationService.init().timeout(_nonCriticalStepTimeout);
  } catch (e) {
    debugPrint('Startup: NotificationService.init failed (non-fatal): $e');
  }

  // Critical: the database must open and migrate cleanly, or the app is
  // genuinely unusable — this is the one case where we surface an error
  // screen instead of booting into a broken state.
  final db = container.read(databaseProvider);
  try {
    // Forces any pending schema migration to run now, on startup, rather
    // than on whatever screen happens to touch the DB first.
    await db.customSelect('SELECT 1').get();
  } catch (e) {
    debugPrint('Startup: database open/migration failed (fatal): $e');
    return StartupResult.fatal(e);
  }

  // First-launch seeding (exercises + muscles) — non-critical. If it
  // throws partway, don't hang and don't set the "seeded" flags, so it
  // simply retries on the next launch.
  try {
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool('exercises_seeded') ?? false;

    if (!seeded) {
      await db.exercisesDao.seedExercises(kDefaultExercises);
      await prefs.setBool('exercises_seeded', true);
    }

    final musclesSeeded = prefs.getBool('muscles_seeded_v1') ?? false;
    if (!musclesSeeded) {
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

    // Muscle Taxonomy + Weekly Volume Report (schema v20): re-sync every
    // default exercise's active muscle assignments to the new 21-muscle,
    // role-aware taxonomy. Runs once per install regardless of whether
    // muscles_seeded_v1 already ran (that flag may predate this feature and
    // would otherwise skip re-seeding for upgraded installs). Non-
    // destructive: setMusclesForExercise never deletes rows, it deactivates
    // the previous active assignment and inserts the new one, and clears
    // any stale "needs review" flag for exercises with an exact v2 mapping.
    final musclesSeededV2 = prefs.getBool('muscles_seeded_v2') ?? false;
    if (!musclesSeededV2) {
      final dao = db.exercisesDao;
      final existingByName = await dao.getExerciseIdsByName();

      for (final companion in kDefaultExercises) {
        final name = companion.name.value;
        if (!existingByName.containsKey(name)) {
          final newId = await dao.insertExercise(companion);
          existingByName[name] = newId;
        }
      }

      for (final entry in kExerciseMuscles.entries) {
        final id = existingByName[entry.key];
        if (id != null) {
          await dao.setMusclesForExercise(id, entry.value);
        }
      }

      await prefs.setBool('muscles_seeded_v2', true);
    }
  } catch (e) {
    debugPrint(
      'Startup: first-launch seeding failed, will retry next launch (non-fatal): $e',
    );
  }

  // (c) Roll the weigh-in reminder forward when a plan exists — cheap
  // no-op (cancels) when there's no active plan. Explicitly non-essential:
  // fire-and-forget it AFTER startup reports ready, fully off the critical
  // path, guarded by its own try/catch so it can never affect boot.
  unawaited(() async {
    try {
      await container
          .read(weightGoalActionsProvider)
          .rescheduleReminder()
          .timeout(_nonCriticalStepTimeout);
    } catch (e) {
      debugPrint(
        'Startup: weigh-in reminder reschedule failed (non-fatal): $e',
      );
    }
  }());

  return const StartupResult.ready();
}

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
  Object? _fatalError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final result = await runAppStartup(container);
    // Guarantee we always resolve out of the spinner state, one way or the
    // other — there is no code path that leaves it spinning forever.
    if (!mounted) return;
    setState(() {
      _ready = result.success;
      _fatalError = result.fatalError;
    });
  }

  void _retry() {
    setState(() {
      _ready = false;
      _fatalError = null;
    });
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    if (_fatalError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Workout Tracker couldn\'t start.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_fatalError',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const ShellScreen();
  }
}
