import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/database_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/shell_screen.dart';
import 'screens/settings/program_setup_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: WorkoutTrackerApp(),
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
