import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';

/// Schema v19 migration test — Weight Goal Coaching Loop.
///
/// Adds nullable plan columns (planStartDate, planStartWeightKg,
/// planTargetDate, weighInIntervalDays, weighInRemindersEnabled,
/// weighInLastReminderAt) to user_profiles. Purely additive: seeds a v18
/// user_profiles row (pre-dating these columns) and verifies:
///   - the new columns exist after migration
///   - existing profile field values are preserved unchanged
///   - the migration is idempotent on a fresh v19 database
const _createUserProfilesV18 = '''
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

void main() {
  test(
    'v18 -> v19 adds nullable weight-goal plan columns and preserves existing profile data',
    () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createUserProfilesV18);
      raw.execute(
        "INSERT INTO user_profiles "
        "(id, name, gender, age, height_cm, weight_kg, target_weight_kg, "
        "fitness_goal, activity_level, weekly_rate_kg) VALUES "
        "(1, 'Alex', 'female', 30, 170.0, 68.0, 62.0, 'lose', 'moderate', 0.5);",
      );
      raw.execute('PRAGMA user_version = 18;');

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the migration to run.
      await db.customSelect('SELECT 1').get();

      final cols =
          await db.customSelect('PRAGMA table_info(user_profiles)').get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('plan_start_date'));
      expect(names, contains('plan_start_weight_kg'));
      expect(names, contains('plan_target_date'));
      expect(names, contains('weigh_in_interval_days'));
      expect(names, contains('weigh_in_reminders_enabled'));
      expect(names, contains('weigh_in_last_reminder_at'));

      // Old row preserved, new columns default to null.
      final profile = await db.userProfileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Alex');
      expect(profile.gender, 'female');
      expect(profile.age, 30);
      expect(profile.heightCm, 170.0);
      expect(profile.weightKg, 68.0);
      expect(profile.targetWeightKg, 62.0);
      expect(profile.fitnessGoal, 'lose');
      expect(profile.activityLevel, 'moderate');
      expect(profile.weeklyRateKg, 0.5);
      expect(profile.planStartDate, isNull);
      expect(profile.planStartWeightKg, isNull);
      expect(profile.planTargetDate, isNull);
      expect(profile.weighInIntervalDays, isNull);
      expect(profile.weighInLastReminderAt, isNull);

      // Row count preserved (no duplication / data loss).
      final rows =
          await db.customSelect('SELECT id FROM user_profiles').get();
      expect(rows, hasLength(1));
    },
  );

  test('v19 migration is idempotent when plan columns already exist', () async {
    // Fresh schema-19 database (onCreate already includes the plan columns);
    // opening again must not error.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final cols =
        await db.customSelect('PRAGMA table_info(user_profiles)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll(<String>[
        'plan_start_date',
        'plan_start_weight_kg',
        'plan_target_date',
        'weigh_in_interval_days',
        'weigh_in_reminders_enabled',
        'weigh_in_last_reminder_at',
      ]),
    );
  });
}
