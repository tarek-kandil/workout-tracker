import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/exercise_muscle_seed.dart';
import 'package:workout_tracker/models/exercise_tracking_mode.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/providers/muscle_volume_provider.dart';
import 'package:workout_tracker/utils/constants.dart';

void main() {
  group('Global Exercise Catalog v1 invariants', () {
    test('keys, names, naming rules, 21-muscle coverage, and variation cliques are valid', () {
      expect(kGlobalExerciseCatalog.length, greaterThanOrEqualTo(180));

      final seenKeys = <String>{};
      final seenNames = <String>{};
      final seenLegacy = <String>{};
      final primaryCountByMuscle = <String, int>{
        for (final m in kTrainableMuscles) m: 0,
      };

      final snakeCase = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

      for (final seed in kGlobalExerciseCatalog) {
        expect(
          snakeCase.hasMatch(seed.key),
          isTrue,
          reason: 'Invalid snake_case key: ${seed.key}',
        );
        expect(
          seenKeys.add(seed.key),
          isTrue,
          reason: 'Duplicate canonical key: ${seed.key}',
        );
        expect(
          seenNames.add(seed.name),
          isTrue,
          reason: 'Duplicate exercise name: ${seed.name}',
        );

        // Enforce naming conventions: never spell out Dumbbell/Barbell, and
        // capitalize every word segment (including after hyphens).
        expect(seed.name.toLowerCase().contains('dumbbell'), isFalse,
            reason: '${seed.name} should use DB');
        expect(seed.name.toLowerCase().contains('barbell'), isFalse,
            reason: '${seed.name} should use BB');

        for (final word in seed.name.split(' ')) {
          for (final seg in word.split('-')) {
            expect(seg, isNotEmpty, reason: 'Empty segment in ${seed.name}');
            final first = seg[0];
            expect(
              first == first.toUpperCase(),
              isTrue,
              reason: 'Uncapitalized segment "$seg" in "${seed.name}"',
            );
          }
        }

        for (final legacy in seed.legacyNames) {
          expect(
            seenLegacy.add(legacy.toLowerCase()),
            isTrue,
            reason: 'Duplicate legacy alias: $legacy',
          );
        }

        if (seed.isCardio) {
          expect(seed.mode, ExerciseTrackingMode.timed);
          expect(seed.muscles, isEmpty);
        } else {
          expect(seed.muscles, isNotEmpty,
              reason: '${seed.name} is missing muscle assignments');
          final primaries = seed.muscles
              .where((m) => m.role == ExerciseMuscleRole.primary)
              .toList();
          expect(primaries, hasLength(1),
              reason: '${seed.name} must have exactly 1 primary muscle');
          for (final m in seed.muscles) {
            expect(
              kTrainableMuscles.contains(m.muscle),
              isTrue,
              reason: '${seed.name} references unknown muscle "${m.muscle}"',
            );
          }
          final p = primaries.single.muscle;
          primaryCountByMuscle[p] = (primaryCountByMuscle[p] ?? 0) + 1;
        }
      }

      // Every single one of the 21 trainable muscles must have >= 2 primary exercises.
      for (final m in kTrainableMuscles) {
        expect(
          primaryCountByMuscle[m]!,
          greaterThanOrEqualTo(2),
          reason: 'Muscle "$m" has fewer than 2 primary exercises',
        );
      }

      // Every name in variation cliques must exist in the catalog.
      for (final group in kDefaultExerciseVariationGroups) {
        expect(group.length, greaterThanOrEqualTo(2));
        for (final name in group) {
          expect(
            seenNames.contains(name),
            isTrue,
            reason: 'Variation group references missing exercise "$name"',
          );
        }
      }
    });
  });

  group('ExercisesDao.syncGlobalCatalogV1', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
      ]);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('fresh sync populates catalog, muscles, variations, and 0 unmapped exercises, idempotently', () async {
      await db.exercisesDao.syncGlobalCatalogV1();

      final all = await db.exercisesDao.getAllExercises();
      expect(all.length, kGlobalExerciseCatalog.length);
      expect(all.every((e) => e.canonicalKey != null), isTrue);

      final unmapped = await container.read(unmappedExerciseCountProvider.future);
      expect(unmapped, 0);

      final byName = {for (final e in all) e.name: e};
      final benchVars = await db.exerciseVariationsDao
          .getVariations(byName['Bench Press']!.id);
      final benchVarNames = benchVars.map((e) => e.name).toSet();
      expect(benchVarNames, containsAll([
        'DB Bench Press',
        'Smith Machine Bench Press',
        'Wide-Grip Bench Press',
        'Push-Ups',
      ]));

      final dragonVars = await db.exerciseVariationsDao
          .getVariations(byName['Dragon Flags']!.id);
      expect(
        dragonVars.map((e) => e.name),
        containsAll(['Hanging Leg Raises', 'Reverse Crunches', 'Toes-To-Bar']),
      );

      final landmineVars = await db.exerciseVariationsDao
          .getVariations(byName['Single-Arm Landmine Press']!.id);
      expect(
        landmineVars.map((e) => e.name),
        contains('Single-Arm DB Shoulder Press'),
      );

      // Idempotent second run
      await db.exercisesDao.syncGlobalCatalogV1();
      final afterSecond = await db.exercisesDao.getAllExercises();
      expect(afterSecond.length, kGlobalExerciseCatalog.length);
    });

    test('upgrades legacy exercise names in-place preserving IDs, sets, notes, and custom exercises', () async {
      final squatId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: 'Squat'),
      );
      final flyId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: 'Dumbbell Fly'),
      );
      final abWheelId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(
          name: 'Ab Wheel Rollout',
          trackingMode: const Value('bodyweight_reps'),
        ),
      );
      final legCurlId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: 'Leg Curl'),
      );
      final nordicUnweightedId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(
          name: 'Nordic Curl',
          trackingMode: const Value('weighted_reps'),
        ),
      );
      final customId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: 'My Custom Zercher Carry'),
      );
      await db.exercisesDao.setMusclesForExercise(
        customId,
        const [ExerciseMuscleSeed.primary('Quads')],
      );

      // Log a workout set + note on legacy 'Squat'
      final sessionId = await db.sessionsDao.insertSession(
        WorkoutSessionsCompanion.insert(
          date: DateTime(2026, 11, 1),
          workoutName: 'Leg Day',
        ),
      );
      await db.setsDao.insertSet(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: squatId,
          setNumber: 1,
          weightKg: 140.0,
          reps: 5,
        ),
      );
      await db.exerciseNotesDao.addNote(squatId, 'Hit parallel cleanly');

      await db.exercisesDao.syncGlobalCatalogV1();

      final all = await db.exercisesDao.getAllExercises();
      final byId = {for (final e in all) e.id: e};
      final byName = {for (final e in all) e.name: e};

      // In-place renames kept exact same IDs!
      expect(byId[squatId]!.name, 'Back Squats');
      expect(byId[squatId]!.canonicalKey, 'back_squats');
      expect(byId[flyId]!.name, 'DB Flys');
      expect(byId[abWheelId]!.name, 'Kneeling Ab Wheel Rollouts');
      expect(byId[legCurlId]!.name, 'Seated Leg Curls');
      expect(byName.containsKey('Lying Leg Curls'), isTrue);

      // Nordic Curl without weighted sets switched to bodyweight_reps
      expect(byId[nordicUnweightedId]!.name, 'Nordic Curls');
      expect(byId[nordicUnweightedId]!.trackingMode, 'bodyweight_reps');

      // Anatomy fix applied: Back Squats has Quads primary + Glutes/Adductors/Spinal Erectors secondary (no Hamstrings/Abs)
      final squatMuscles = await db.exercisesDao.getMusclesForExercise(squatId);
      expect(squatMuscles.first.muscle, 'Quads');
      expect(
        squatMuscles.skip(1).map((m) => m.muscle).toSet(),
        equals({'Glutes', 'Adductors', 'Spinal Erectors'}),
      );

      // History & notes still attached to squatId
      final notes = await db.exerciseNotesDao.getNotesForExercise(squatId);
      expect(notes.single.note, 'Hit parallel cleanly');
      final sets = await (db.select(db.workoutSets)
            ..where((s) => s.exerciseId.equals(squatId)))
          .get();
      expect(sets.single.weightKg, 140.0);

      // Custom exercise untouched (canonicalKey == null, custom muscles intact)
      expect(byId[customId]!.name, 'My Custom Zercher Carry');
      expect(byId[customId]!.canonicalKey, isNull);
      final customMuscles =
          await db.exercisesDao.getMusclesForExercise(customId);
      expect(customMuscles.single.muscle, 'Quads');
    });

    test('v26 -> v27 migration adds canonical_key column to exercises', () async {
      final raw = sqlite3.openInMemory();
      raw.execute('''
        CREATE TABLE exercises (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL DEFAULT 'Other',
          notes TEXT NULL,
          is_timed INTEGER NOT NULL DEFAULT 0,
          tracking_mode TEXT NOT NULL DEFAULT 'weighted_reps',
          muscle_needs_review INTEGER NOT NULL DEFAULT 0,
          muscle_review_note TEXT NULL,
          archived INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute("INSERT INTO exercises (id, name) VALUES (1, 'Bench Press');");
      raw.execute('PRAGMA user_version = 26;');

      final migDb = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(migDb.close);

      final rows = await migDb.exercisesDao.getAllExercises();
      expect(rows.single.name, 'Bench Press');
      expect(rows.single.canonicalKey, isNull);
    });
  });
}
