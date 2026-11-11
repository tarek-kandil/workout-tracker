import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/weight_suggestion.dart';
import 'package:workout_tracker/models/wod_item.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/providers/next_workout_provider.dart';
import 'package:workout_tracker/screens/flash/flash_workouts_screen.dart';
import 'package:workout_tracker/screens/home/home_screen.dart';
import 'package:workout_tracker/services/notification_service.dart';
import 'package:workout_tracker/services/personal_record_detection.dart';
import 'package:workout_tracker/theme/app_theme.dart';

const _createProgramsV21 = '''
  CREATE TABLE programs (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    notes TEXT,
    status INTEGER NOT NULL DEFAULT 0
  );
''';

const _createPhasesV21 = '''
  CREATE TABLE program_phases (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    program_id INTEGER NOT NULL REFERENCES programs(id),
    phase_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    duration_weeks INTEGER NOT NULL
  );
''';

const _createWodTemplatesV21 = '''
  CREATE TABLE wod_templates (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    phase_id INTEGER NOT NULL REFERENCES program_phases(id),
    wod_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    notes TEXT,
    rest_seconds INTEGER NOT NULL DEFAULT 90
  );
''';

const _createWodExerciseGroupsV21 = '''
  CREATE TABLE wod_exercise_groups (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    wod_template_id INTEGER NOT NULL REFERENCES wod_templates(id),
    sort_order INTEGER NOT NULL,
    name TEXT,
    rounds INTEGER NOT NULL DEFAULT 3,
    rest_between_exercises_seconds INTEGER NOT NULL DEFAULT 0,
    rest_between_rounds_seconds INTEGER NOT NULL DEFAULT 90
  );
''';

const _createWodTemplateExercisesV21 = '''
  CREATE TABLE wod_template_exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    wod_template_id INTEGER NOT NULL REFERENCES wod_templates(id),
    exercise_id INTEGER NOT NULL,
    group_id INTEGER REFERENCES wod_exercise_groups(id),
    sort_order INTEGER NOT NULL,
    target_sets INTEGER NOT NULL DEFAULT 3,
    rep_range_min INTEGER NOT NULL DEFAULT 8,
    rep_range_max INTEGER NOT NULL DEFAULT 12,
    notes TEXT,
    rest_seconds INTEGER,
    rest_between_sets_seconds INTEGER,
    target_rpe REAL,
    target_rir REAL,
    video_url TEXT
  );
''';

const _createWorkoutSessionsV21 = '''
  CREATE TABLE workout_sessions (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    date INTEGER NOT NULL,
    workout_name TEXT NOT NULL,
    duration_minutes INTEGER,
    notes TEXT,
    wod_template_id INTEGER REFERENCES wod_templates(id),
    week_number INTEGER
  );
''';

void main() {
  test('v21 -> v22 makes phase_id nullable and preserves existing WOD rows', () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createProgramsV21);
    raw.execute(_createPhasesV21);
    raw.execute(_createWodTemplatesV21);
    raw.execute(_createWodExerciseGroupsV21);
    raw.execute(_createWodTemplateExercisesV21);
    raw.execute(_createWorkoutSessionsV21);
    raw.execute("INSERT INTO programs (id, name, status) VALUES (1, 'Hypertrophy', 0);");
    raw.execute("INSERT INTO program_phases (id, program_id, phase_number, name, duration_weeks) VALUES (10, 1, 1, 'Phase 1', 4);");
    raw.execute("INSERT INTO wod_templates (id, phase_id, wod_number, name, rest_seconds) VALUES (100, 10, 1, 'Day A', 90);");
    raw.execute("INSERT INTO wod_template_exercises (id, wod_template_id, exercise_id, sort_order) VALUES (1, 100, 1, 1);");
    raw.execute('PRAGMA user_version = 21;');

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    // Existing program WOD preserved
    final phaseWods = await db.programsDao.getWodTemplatesForPhase(10);
    expect(phaseWods, hasLength(1));
    expect(phaseWods.first.name, 'Day A');
    expect(phaseWods.first.isArchived, isFalse);

    // Can insert a standalone Flash Workout with phaseId == null
    final flashId = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: 'Daily Mobility',
        restSeconds: const Value(45),
        reminderHour: const Value(8),
        reminderMinute: const Value(30),
      ),
    );
    final flashWorkouts = await db.programsDao.getFlashWorkouts();
    expect(flashWorkouts, hasLength(1));
    expect(flashWorkouts.first.id, flashId);
    expect(flashWorkouts.first.phaseId, isNull);
    expect(flashWorkouts.first.reminderHour, 8);
    expect(flashWorkouts.first.reminderMinute, 30);

    // Program WOD query excludes flash workouts
    final phaseWodsAfter = await db.programsDao.getWodTemplatesForPhase(10);
    expect(phaseWodsAfter, hasLength(1));

    // Deleting the flash workout removes it completely
    await db.programsDao.deleteWodTemplate(flashId);
    expect(await db.programsDao.getFlashWorkouts(), isEmpty);
  });

  test('Reminder schedule formatting handles daily, weekdays, weekends, and custom days', () {
    expect(
      NotificationService.formatReminderSchedule(null, 8, 30),
      'Daily at 08:30',
    );
    expect(
      NotificationService.formatReminderSchedule(0x7F, 8, 30),
      'Daily at 08:30',
    );
    expect(
      NotificationService.formatReminderSchedule(0x1F, 7, 5),
      'Weekdays at 07:05',
    );
    expect(
      NotificationService.formatReminderSchedule(0x60, 10, 0),
      'Weekends at 10:00',
    );
    // Mon (1<<0) + Wed (1<<2) + Fri (1<<4) = 1 + 4 + 16 = 21
    expect(
      NotificationService.formatReminderSchedule(21, 18, 45),
      'Mon, Wed, Fri at 18:45',
    );
  });

  test('Timed progressive overload suggests +5s under 60s and +10s at/above 60s', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final plankId = await db.into(db.exercises).insert(
          ExercisesCompanion.insert(
            name: 'Test Plank',
            category: const Value('Core'),
            isTimed: const Value(true),
          ),
        );
    final flashId = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: 'Core Flash',
      ),
    );
    await db.programsDao.insertWodTemplateExercise(
      WodTemplateExercisesCompanion.insert(
        wodTemplateId: flashId,
        exerciseId: plankId,
        sortOrder: 0,
        targetSets: const Value(2),
        repRangeMin: const Value(30),
        repRangeMax: const Value(45),
      ),
    );

    // Log a session hitting the 45s ceiling on both sets
    final sessionId = await db.sessionsDao.insertSession(
      WorkoutSessionsCompanion.insert(
        date: DateTime(2026, 11, 10),
        workoutName: 'Core Flash',
        wodTemplateId: Value(flashId),
      ),
    );
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: plankId,
      setNumber: 1,
      reps: 0,
      weightKg: 0,
      durationSeconds: const Value(45),
    ));
    await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseId: plankId,
      setNumber: 2,
      reps: 0,
      weightKg: 0,
      durationSeconds: const Value(45),
    ));

    final exercises = await db.exercisesDao.getAllExercises();
    final map = {for (final e in exercises) e.id: e};
    final items = await buildWodItems(db, flashId, map);
    final standalone = items.single as StandaloneWodExercise;

    expect(standalone.entry.suggestion.type, SuggestionType.increase);
    expect(standalone.entry.suggestion.suggestedDurationSeconds, 50); // 45 + 5

    // Duration PR evaluation
    expect(
      evaluateDurationPersonalRecord(
        currentTopDurationSeconds: 45,
        durationSeconds: 50,
      ),
      isTrue,
    );
    expect(
      evaluateDurationPersonalRecord(
        currentTopDurationSeconds: 45,
        durationSeconds: 45,
      ),
      isFalse,
    );
  });

  testWidgets('Create and delete empty flash workout with weekday reminder in FlashWorkoutsScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppThemeData.dark(AppPaletteLibrary.defaultPalette),
          home: const FlashWorkoutsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap 'Add Flash Workout' FAB on FlashWorkoutsScreen
    await tester.tap(find.text('Add Flash Workout'));
    await tester.pumpAndSettle();

    // Enter name, toggle reminder ON (defaults to 08:30 and Every day without typing)
    await tester.enterText(find.byType(TextField).first, 'Mobility');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('08:30'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);

    await tester.tap(find.text('Create & Add Exercises'));
    await tester.pumpAndSettle();

    // Verify WodExerciseSetupScreen opened with no error
    expect(find.text('No exercises yet'), findsOneWidget);

    // Pop WodExerciseSetupScreen back to FlashWorkoutsScreen
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Mobility'), findsOneWidget);
    expect(find.textContaining('Daily at 08:30'), findsOneWidget);

    // Delete the empty flash workout via PopupMenuButton
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Mobility'), findsNothing);
    expect(find.text('No flash workouts yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await db.close();
  });

  testWidgets('HomeScreen only shows Flash Workouts section when non-empty and has no Manage button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppThemeData.dark(AppPaletteLibrary.defaultPalette),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLASH WORKOUTS'), findsNothing);
    expect(find.text('Manage'), findsNothing);
    expect(find.text('+ Create'), findsNothing);

    await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: 'Quick Abs',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLASH WORKOUTS'), findsOneWidget);
    expect(find.text('Quick Abs'), findsOneWidget);
    expect(find.text('Manage'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await db.close();
  });
}
