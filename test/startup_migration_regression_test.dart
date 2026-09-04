import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/providers/weight_goal_providers.dart';

/// Regression test for the "app doesn't start" production bug on the
/// bug-fixes-aug-2026 release (real device data, upgrading from schema v17
/// straight to v19).
///
/// Reproduces the REAL upgrade path with realistic data: a v17
/// user_profiles row (no plan columns), workout_sets rows WITH an rpe
/// value, wod_template_exercises rows WITH a target_rpe value, and some
/// bodyweight_entries — then forces the v17 -> v19 migration and exercises
/// the startup reschedule logic (`WeightGoalActions.rescheduleReminder()`)
/// against the migrated database, both with no plan and with a plan set.
const _createUserProfilesV17 = '''
  CREATE TABLE user_profiles (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    gender TEXT NOT NULL DEFAULT 'male',
    age INTEGER,
    height_cm REAL,
    weight_kg REAL,
    target_weight_kg REAL,
    fitness_goal TEXT NOT NULL DEFAULT 'maintain',
    activity_level TEXT NOT NULL DEFAULT 'moderate',
    weekly_rate_kg REAL
  );
''';

const _createWorkoutSetsV17 = '''
  CREATE TABLE workout_sets (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    duration_seconds INTEGER,
    rpe REAL,
    notes TEXT
  );
''';

const _createWodTemplateExercisesV17 = '''
  CREATE TABLE wod_template_exercises (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    wod_template_id INTEGER NOT NULL,
    exercise_id INTEGER NOT NULL,
    sort_order INTEGER NOT NULL,
    group_id INTEGER,
    target_sets INTEGER NOT NULL DEFAULT 3,
    rep_range_min INTEGER NOT NULL DEFAULT 6,
    rep_range_max INTEGER NOT NULL DEFAULT 12,
    notes TEXT,
    rest_seconds INTEGER,
    rest_between_sets_seconds INTEGER,
    target_rpe REAL,
    video_url TEXT
  );
''';

const _createBodyweightEntriesV17 = '''
  CREATE TABLE bodyweight_entries (
    id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    date INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    notes TEXT
  );
''';

/// Builds an in-memory v17 database seeded with realistic data, matching
/// the shape a real upgrading user's device would have.
AppDatabase _openRealisticV17Database() {
  final raw = sqlite3.openInMemory();
  raw.execute(_createUserProfilesV17);
  raw.execute(_createWorkoutSetsV17);
  raw.execute(_createWodTemplateExercisesV17);
  raw.execute(_createBodyweightEntriesV17);

  raw.execute(
    "INSERT INTO user_profiles "
    "(id, name, gender, age, height_cm, weight_kg, target_weight_kg, "
    "fitness_goal, activity_level, weekly_rate_kg) VALUES "
    "(1, 'Alex', 'female', 30, 170.0, 68.0, 62.0, 'lose', 'moderate', 0.5);",
  );
  raw.execute(
    'INSERT INTO workout_sets '
    '(id, session_id, exercise_id, set_number, reps, weight_kg, rpe) VALUES '
    '(1, 1, 1, 1, 5, 100.0, 8.0);',
  );
  raw.execute(
    'INSERT INTO wod_template_exercises '
    '(id, wod_template_id, exercise_id, sort_order, target_rpe) VALUES '
    '(1, 1, 1, 1, 8.0);',
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  final aWeekAgo =
      DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
  raw.execute(
    'INSERT INTO bodyweight_entries (id, date, weight_kg, notes) VALUES '
    "(1, $aWeekAgo, 69.0, NULL), "
    "(2, $now, 68.0, NULL);",
  );
  raw.execute('PRAGMA user_version = 17;');

  return AppDatabase.forTesting(NativeDatabase.opened(raw));
}

void main() {
  test(
    'v17 -> v19 migrates realistic real-device data without throwing',
    () async {
      final db = _openRealisticV17Database();
      addTearDown(db.close);

      // Force the migration to run — this is the FIRST database access
      // during a real app startup (see rescheduleReminder in main.dart).
      await db.customSelect('SELECT 1').get();

      final setsCols =
          await db.customSelect('PRAGMA table_info(workout_sets)').get();
      final setsNames = setsCols.map((r) => r.read<String>('name')).toSet();
      expect(setsNames, contains('rir'));

      final teCols = await db
          .customSelect('PRAGMA table_info(wod_template_exercises)')
          .get();
      final teNames = teCols.map((r) => r.read<String>('name')).toSet();
      expect(teNames, contains('target_rir'));

      final profileCols =
          await db.customSelect('PRAGMA table_info(user_profiles)').get();
      final profileNames =
          profileCols.map((r) => r.read<String>('name')).toSet();
      expect(profileNames, contains('plan_start_date'));
      expect(profileNames, contains('weigh_in_interval_days'));

      // Backfill sanity: rir = 10 - rpe, target_rir = 10 - target_rpe.
      final set = await db
          .customSelect('SELECT rpe, rir FROM workout_sets WHERE id = 1')
          .getSingle();
      expect(set.read<double?>('rpe'), 8.0);
      expect(set.read<double?>('rir'), 2.0);

      final te = await db
          .customSelect(
            'SELECT target_rpe, target_rir FROM wod_template_exercises WHERE id = 1',
          )
          .getSingle();
      expect(te.read<double?>('target_rpe'), 8.0);
      expect(te.read<double?>('target_rir'), 2.0);

      final profile = await db.userProfileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Alex');
      expect(profile.planStartDate, isNull); // no plan yet — additive/null
    },
  );

  test(
    'rescheduleReminder() completes without throwing on a migrated v17->v19 DB with NO plan',
    () async {
      final db = _openRealisticV17Database();
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // force migration

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      // This is the exact call added right after NotificationService.init()
      // in main.dart's startup chain. It must never throw, or the app's
      // `_ready` flag is never set and the spinner never resolves.
      await expectLater(
        container.read(weightGoalActionsProvider).rescheduleReminder(),
        completes,
      );
    },
  );

  test(
    'rescheduleReminder() completes without throwing on a migrated v17->v19 DB WITH a plan set',
    () async {
      final db = _openRealisticV17Database();
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get(); // force migration

      // Simulate a user who had already set up a plan pre-upgrade in a
      // hypothetical build, or sets one up post-upgrade.
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion(
          fitnessGoal: const Value('lose'),
          targetWeightKg: const Value(62.0),
          planStartDate:
              Value(DateTime.now().subtract(const Duration(days: 14))),
          planStartWeightKg: const Value(69.0),
          planTargetDate:
              Value(DateTime.now().add(const Duration(days: 70))),
          weighInIntervalDays: const Value(7),
          weighInRemindersEnabled: const Value(true),
        ),
      );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(weightGoalActionsProvider).rescheduleReminder(),
        completes,
      );
    },
  );
}
