import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/exercises_table.dart';
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
import 'daos/programs_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/sets_dao.dart';
import 'daos/bodyweight_dao.dart';
import 'daos/daily_tasks_dao.dart';
import 'daos/user_profile_dao.dart';

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
  ],
  daos: [
    ExercisesDao,
    ProgramsDao,
    SessionsDao,
    SetsDao,
    BodyweightDao,
    DailyTasksDao,
    UserProfileDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

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
              'SELECT name FROM sqlite_master WHERE type="table"',
            ).get();
            final exists =
                tables.any((r) => r.read<String>('name') == 'exercise_muscles');
            if (!exists) {
              await m.createTable(exerciseMuscles);
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
