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
import 'tables/wod_template_exercises_table.dart';
import 'tables/daily_tasks_table.dart';
import 'tables/daily_task_completions_table.dart';
import 'daos/exercises_dao.dart';
import 'daos/programs_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/sets_dao.dart';
import 'daos/bodyweight_dao.dart';
import 'daos/daily_tasks_dao.dart';

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
    WodTemplateExercises,
    DailyTasks,
    DailyTaskCompletions,
  ],
  daos: [
    ExercisesDao,
    ProgramsDao,
    SessionsDao,
    SetsDao,
    BodyweightDao,
    DailyTasksDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Create the 4 new program tables
            await m.createTable(programs);
            await m.createTable(programPhases);
            await m.createTable(wodTemplates);
            await m.createTable(wodTemplateExercises);
            // Add program-linking columns to existing sessions — nullable so old rows are unaffected
            await m.addColumn(workoutSessions, workoutSessions.wodTemplateId);
            await m.addColumn(workoutSessions, workoutSessions.weekNumber);
          }
          if (from < 3) {
            await m.createTable(dailyTasks);
            await m.createTable(dailyTaskCompletions);
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
