import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/exercises_table.dart';
import 'tables/exercise_notes_table.dart';
import 'tables/exercise_variations_table.dart';
import 'tables/sessions_table.dart';
import 'tables/sets_table.dart';
import 'tables/bodyweight_table.dart';
import 'tables/programs_table.dart';
import 'tables/program_phases_table.dart';
import 'tables/wod_templates_table.dart';
import 'tables/wod_exercise_groups_table.dart';
import 'tables/wod_template_exercises_table.dart';
import 'tables/daily_tasks_table.dart';
import 'tables/daily_task_completions_table.dart';
import 'tables/user_profile_table.dart';
import 'tables/exercise_muscles_table.dart';
import 'daos/exercises_dao.dart';
import 'daos/exercise_notes_dao.dart';
import 'daos/exercise_variations_dao.dart';
import 'daos/programs_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/sets_dao.dart';
import 'daos/bodyweight_dao.dart';
import 'daos/daily_tasks_dao.dart';
import 'daos/user_profile_dao.dart';
import 'daos/muscle_volume_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    WorkoutSessions,
    WorkoutSets,
    BodyweightEntries,
    Programs,
    ProgramPhases,
    WodTemplates,
    WodExerciseGroups,
    WodTemplateExercises,
    DailyTasks,
    DailyTaskCompletions,
    UserProfiles,
    ExerciseMuscles,
    ExerciseNotes,
    ExerciseVariations,
  ],
  daos: [
    ExercisesDao,
    ProgramsDao,
    SessionsDao,
    SetsDao,
    BodyweightDao,
    DailyTasksDao,
    UserProfileDao,
    ExerciseNotesDao,
    ExerciseVariationsDao,
    MuscleVolumeDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor that accepts an explicit [QueryExecutor].
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 21;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(programs);
            await m.createTable(programPhases);
            await m.createTable(wodTemplates);
            await m.createTable(wodTemplateExercises);
            await m.addColumn(workoutSessions, workoutSessions.wodTemplateId);
            await m.addColumn(workoutSessions, workoutSessions.weekNumber);
          }
          if (from < 3) {
            await m.createTable(dailyTasks);
            await m.createTable(dailyTaskCompletions);
          }
          if (from < 4) {
            await m.addColumn(exercises, exercises.isTimed);
            await m.addColumn(workoutSets, workoutSets.durationSeconds);
          }
          if (from < 5) {
            await m.addColumn(wodTemplates, wodTemplates.restSeconds);
          }
          if (from < 6) {
            await m.createTable(wodExerciseGroups);
            await m.addColumn(
                wodTemplateExercises, wodTemplateExercises.groupId);
            await m.addColumn(
                wodTemplateExercises, wodTemplateExercises.restSeconds);
          }
          if (from < 7) {
            await m.addColumn(wodExerciseGroups, wodExerciseGroups.name);
          }
          if (from < 9) {
            await m.createTable(userProfiles);
          }
          if (from < 10) {
            final cols = await customSelect(
              'PRAGMA table_info(user_profiles)',
            ).get();
            final hasWeeklyRate =
                cols.any((r) => r.read<String>('name') == 'weekly_rate_kg');
            if (!hasWeeklyRate) {
              await m.addColumn(userProfiles, userProfiles.weeklyRateKg);
            }
          }
          if (from < 11) {
            await m.addColumn(wodTemplateExercises, wodTemplateExercises.targetRpe);
            await m.addColumn(wodTemplateExercises, wodTemplateExercises.videoUrl);
          }
          if (from < 12) {
            final cols = await customSelect(
              'PRAGMA table_info(wod_template_exercises)',
            ).get();
            final hasCol = cols.any(
              (r) => r.read<String>('name') == 'rest_between_sets_seconds',
            );
            if (!hasCol) {
              await m.addColumn(
                wodTemplateExercises,
                wodTemplateExercises.restBetweenSetsSeconds,
              );
            }
          }
          if (from < 13) {
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final exists =
                tables.any((r) => r.read<String>('name') == 'exercise_muscles');
            if (!exists) {
              await m.createTable(exerciseMuscles);
            }
          }
          if (from < 14) {
            // rpe/notes have been part of the WorkoutSets class for a long time
            // but were never added via a migration, so devices whose
            // workout_sets table was created before those columns existed are
            // missing them — writing rpe/notes then crashes with "no such
            // column". Add them if absent (fresh installs already have them).
            final cols = await customSelect(
              'PRAGMA table_info(workout_sets)',
            ).get();
            final names =
                cols.map((r) => r.read<String>('name')).toSet();
            if (!names.contains('rpe')) {
              await m.addColumn(workoutSets, workoutSets.rpe);
            }
            if (!names.contains('notes')) {
              await m.addColumn(workoutSets, workoutSets.notes);
            }
          }
          if (from < 15) {
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final exists =
                tables.any((r) => r.read<String>('name') == 'exercise_notes');
            if (!exists) {
              await m.createTable(exerciseNotes);
            }
          }
          if (from < 16) {
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final names = tables.map((r) => r.read<String>('name')).toSet();
            if (!names.contains('exercise_variations')) {
              await m.createTable(exerciseVariations);
            }
          }
          if (from < 17) {
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final names = tables.map((r) => r.read<String>('name')).toSet();
            if (!names.contains('exercise_variations')) {
              await m.createTable(exerciseVariations);
            }
          }
          if (from < 18) {
            // RPE → RIR migration: additive, keeps the old rpe/targetRpe
            // columns for one release. RIR = 10 − RPE; nulls stay null.
            //
            // Guard on table/column existence (see the from<14 step above for
            // the same rationale): some devices may be missing these tables
            // or columns depending on their exact upgrade history, and tests
            // seed minimal schemas that don't always include every table.
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final tableNames = tables.map((r) => r.read<String>('name')).toSet();

            if (tableNames.contains('workout_sets')) {
              final cols = await customSelect(
                'PRAGMA table_info(workout_sets)',
              ).get();
              final colNames = cols.map((r) => r.read<String>('name')).toSet();
              if (!colNames.contains('rir')) {
                await m.addColumn(workoutSets, workoutSets.rir);
              }
              if (colNames.contains('rpe')) {
                await customStatement(
                  'UPDATE workout_sets SET rir = 10.0 - rpe WHERE rpe IS NOT NULL;',
                );
              }
            }

            if (tableNames.contains('wod_template_exercises')) {
              final cols = await customSelect(
                'PRAGMA table_info(wod_template_exercises)',
              ).get();
              final colNames = cols.map((r) => r.read<String>('name')).toSet();
              if (!colNames.contains('target_rir')) {
                await m.addColumn(
                    wodTemplateExercises, wodTemplateExercises.targetRir);
              }
              if (colNames.contains('target_rpe')) {
                await customStatement(
                  'UPDATE wod_template_exercises SET target_rir = 10.0 - target_rpe '
                  'WHERE target_rpe IS NOT NULL;',
                );
              }
            }
          }
          if (from < 19) {
            // Weight Goal Coaching Loop: additive nullable columns on
            // user_profiles. Guard on column existence (see the from<10
            // step above for the same rationale — devices may have reached
            // v18 via different upgrade paths, and tests seed minimal
            // schemas).
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final tableNames = tables.map((r) => r.read<String>('name')).toSet();

            if (tableNames.contains('user_profiles')) {
              final cols = await customSelect(
                'PRAGMA table_info(user_profiles)',
              ).get();
              final colNames = cols.map((r) => r.read<String>('name')).toSet();

              if (!colNames.contains('plan_start_date')) {
                await m.addColumn(userProfiles, userProfiles.planStartDate);
              }
              if (!colNames.contains('plan_start_weight_kg')) {
                await m.addColumn(
                    userProfiles, userProfiles.planStartWeightKg);
              }
              if (!colNames.contains('plan_target_date')) {
                await m.addColumn(userProfiles, userProfiles.planTargetDate);
              }
              if (!colNames.contains('weigh_in_interval_days')) {
                await m.addColumn(
                    userProfiles, userProfiles.weighInIntervalDays);
              }
              if (!colNames.contains('weigh_in_reminders_enabled')) {
                await m.addColumn(
                    userProfiles, userProfiles.weighInRemindersEnabled);
              }
              if (!colNames.contains('weigh_in_last_reminder_at')) {
                await m.addColumn(
                    userProfiles, userProfiles.weighInLastReminderAt);
              }
            }
          }
          if (from < 20) {
            // Muscle Taxonomy + Weekly Volume Report: additive-only,
            // non-destructive migration. Never drops tables or deletes
            // exercise_muscles rows — legacy rows are marked is_active = 0
            // instead, and ambiguous exercises are flagged for review.
            // Guarded on table/column existence (see the from<14 step above
            // for the same rationale — devices may have reached v19 via
            // different upgrade paths, and tests seed minimal schemas).
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final tableNames = tables.map((r) => r.read<String>('name')).toSet();

            // `exercises` gets its new review columns whenever the table
            // exists, regardless of whether `exercise_muscles` is present
            // (some upgrade paths/tests exercise `exercises` in isolation).
            if (tableNames.contains('exercises')) {
              final exCols =
                  await customSelect('PRAGMA table_info(exercises)').get();
              final exColNames =
                  exCols.map((r) => r.read<String>('name')).toSet();
              if (!exColNames.contains('muscle_needs_review')) {
                await m.addColumn(exercises, exercises.muscleNeedsReview);
              }
              if (!exColNames.contains('muscle_review_note')) {
                await m.addColumn(exercises, exercises.muscleReviewNote);
              }
            }

            if (tableNames.contains('exercise_muscles')) {
              final emCols = await customSelect(
                'PRAGMA table_info(exercise_muscles)',
              ).get();
              final emColNames = emCols.map((r) => r.read<String>('name')).toSet();

              final roleColumnIsNew = !emColNames.contains('role');
              if (roleColumnIsNew) {
                await m.addColumn(exerciseMuscles, exerciseMuscles.role);
              }
              if (!emColNames.contains('is_active')) {
                await m.addColumn(exerciseMuscles, exerciseMuscles.isActive);
              }

              if (roleColumnIsNew) {
                // Normalize the old sortOrder==0-is-primary convention into
                // the new explicit role column.
                await customStatement(
                  "UPDATE exercise_muscles SET role = 'primary' WHERE sort_order = 0;",
                );
                await customStatement(
                  "UPDATE exercise_muscles SET role = 'secondary' WHERE sort_order > 0;",
                );
              }

              if (tableNames.contains('exercises')) {
                // ── Legacy broad-tag mapping ────────────────────────────
                // Exact 1:1 tags (Chest, Biceps, Triceps, Quads, Hamstrings,
                // Glutes, Calves) are already valid taxonomy names — nothing
                // to migrate for them.

                // Safe renames: singular Front/Rear Delt -> plural taxonomy
                // names. No ambiguity, so no review flag.
                await _migrateLegacyMuscleTag(
                  from: 'Front Delt',
                  to: 'Front Delts',
                  needsReview: false,
                );
                await _migrateLegacyMuscleTag(
                  from: 'Rear Delt',
                  to: 'Rear Delts',
                  needsReview: false,
                );

                // Ambiguous tags: pick the single most likely muscle and
                // flag the exercise for athlete review (FR-016/FR-017).
                await _migrateLegacyMuscleTag(
                  from: 'Back',
                  to: 'Lats',
                  needsReview: true,
                  reviewNote: 'Migrated legacy "Back" to Lats — review for '
                      'Upper Back, Traps, or Spinal Erectors.',
                );
                await _migrateLegacyMuscleTag(
                  from: 'Shoulders',
                  to: 'Side Delts',
                  needsReview: true,
                  reviewNote:
                      'Migrated legacy "Shoulders" to Side Delts — review '
                      'for Front Delts or Rear Delts.',
                );
                await _migrateLegacyMuscleTag(
                  from: 'Core',
                  to: 'Abs',
                  needsReview: true,
                  reviewNote: 'Migrated legacy "Core" to Abs — review for '
                      'Obliques.',
                );

                // Full Body / Cardio: no safe single-muscle mapping exists.
                // Deactivate the legacy rows (never delete them) and flag
                // any exercise left with zero active taxonomy muscles.
                await customStatement(
                  "UPDATE exercise_muscles SET is_active = 0 WHERE muscle = 'Full Body';",
                );
                await customStatement(
                  "UPDATE exercise_muscles SET is_active = 0 WHERE muscle = 'Cardio';",
                );

                const trainableMuscleList =
                    "'Chest','Lats','Upper Back','Traps','Spinal Erectors',"
                    "'Front Delts','Side Delts','Rear Delts','Biceps',"
                    "'Triceps','Forearms','Quads','Hamstrings','Glutes',"
                    "'Adductors','Abductors','Hip Flexors','Calves','Abs',"
                    "'Obliques','Neck'";

                // Full Body: always ambiguous — flag for review whenever an
                // exercise has no other active taxonomy muscle remaining.
                await customStatement(
                  'UPDATE exercises '
                  'SET muscle_needs_review = 1, '
                  '    muscle_review_note = TRIM(COALESCE(muscle_review_note || \' \', \'\') || '
                  "      'Migrated legacy \"Full Body\" tag — assign specific muscles for this "
                  "exercise to count toward muscle volume.') "
                  'WHERE id IN (SELECT DISTINCT exercise_id FROM exercise_muscles WHERE muscle = \'Full Body\') '
                  'AND id NOT IN ('
                  '  SELECT DISTINCT exercise_id FROM exercise_muscles '
                  '  WHERE is_active = 1 AND muscle IN ($trainableMuscleList)'
                  ');',
                );

                // Cardio: default cardio exercises are intentionally
                // muscle-less and should not be flagged; anything else
                // (custom or non-cardio exercises tagged Cardio) with no
                // remaining active taxonomy muscle is flagged for review.
                await customStatement(
                  'UPDATE exercises '
                  'SET muscle_needs_review = 1, '
                  '    muscle_review_note = TRIM(COALESCE(muscle_review_note || \' \', \'\') || '
                  "      'Migrated legacy \"Cardio\" tag — assign specific muscles if this "
                  "exercise should count toward muscle volume.') "
                  'WHERE id IN (SELECT DISTINCT exercise_id FROM exercise_muscles WHERE muscle = \'Cardio\') '
                  'AND id NOT IN ('
                  '  SELECT DISTINCT exercise_id FROM exercise_muscles '
                  '  WHERE is_active = 1 AND muscle IN ($trainableMuscleList)'
                  ') '
                  "AND name NOT IN ('Treadmill Run','Rowing Machine','Jump Rope',"
                  "'Assault Bike','Stairmaster','Cycling');",
                );
              }
            }
          }
          if (from < 21) {
            // Non-destructive exercise deletion: additive `archived` column
            // on exercises. Guarded on table/column existence (see the
            // from<14 step above for the same rationale — devices may have
            // reached v20 via different upgrade paths, and tests seed
            // minimal schemas that don't always include every table).
            final tables = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table'",
            ).get();
            final tableNames = tables.map((r) => r.read<String>('name')).toSet();

            if (tableNames.contains('exercises')) {
              final exCols =
                  await customSelect('PRAGMA table_info(exercises)').get();
              final exColNames =
                  exCols.map((r) => r.read<String>('name')).toSet();
              if (!exColNames.contains('archived')) {
                await m.addColumn(exercises, exercises.archived);
              }
            }
          }
          if (from >= 3 && from < 8) {
            final cols = await customSelect(
              'PRAGMA table_info(daily_tasks)',
            ).get();
            final hasIconName =
                cols.any((r) => r.read<String>('name') == 'icon_name');
            if (!hasIconName) {
              await m.addColumn(dailyTasks, dailyTasks.iconName);
            }
          }
        },
      );

  /// Migrates one legacy broad muscle tag ([from]) to an active v20
  /// taxonomy muscle ([to]) for every exercise that has it, without
  /// deleting the legacy row: the legacy row is marked `is_active = 0` and
  /// a new active row is inserted (idempotently, via `NOT EXISTS`) that
  /// preserves the legacy row's role. When [needsReview] is true, exercises
  /// touched by this mapping are flagged `muscle_needs_review = 1` with
  /// [reviewNote] appended (FR-016/FR-017).
  Future<void> _migrateLegacyMuscleTag({
    required String from,
    required String to,
    required bool needsReview,
    String? reviewNote,
  }) async {
    await customStatement(
      'INSERT INTO exercise_muscles (exercise_id, muscle, sort_order, role, is_active) '
      'SELECT legacy.exercise_id, ?, legacy.sort_order, legacy.role, 1 '
      'FROM exercise_muscles legacy '
      'WHERE legacy.muscle = ? AND legacy.is_active = 1 '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM exercise_muscles existing '
      '  WHERE existing.exercise_id = legacy.exercise_id '
      '    AND existing.muscle = ? AND existing.is_active = 1'
      ');',
      [to, from, to],
    );

    await customStatement(
      'UPDATE exercise_muscles SET is_active = 0 WHERE muscle = ?;',
      [from],
    );

    if (needsReview && reviewNote != null) {
      await customStatement(
        'UPDATE exercises '
        "SET muscle_needs_review = 1, "
        "    muscle_review_note = TRIM(COALESCE(muscle_review_note || ' ', '') || ?) "
        'WHERE id IN (SELECT DISTINCT exercise_id FROM exercise_muscles WHERE muscle = ?);',
        [reviewNote, from],
      );
    }
  }
}


LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
