import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/utils/constants.dart';
import 'package:workout_tracker/utils/exercise_deduplicator.dart';

void main() {
  group('normalizeExerciseSignature', () {
    test('all canonical Global Catalog exercises have unique normalized signatures (zero collisions)', () {
      expect(kGlobalExerciseCatalog.length, 201);
      final bySig = <String, String>{};
      for (final seed in kGlobalExerciseCatalog) {
        final sig = normalizeExerciseSignature(seed.name);
        expect(sig, isNotEmpty, reason: 'Empty signature for ${seed.name}');
        final existing = bySig[sig];
        expect(
          existing,
          isNull,
          reason: 'Signature collision "$sig" between "$existing" and "${seed.name}"',
        );
        bySig[sig] = seed.name;
      }
    });

    test('includes rope, straight-bar, and V-bar (triangle) cable handle variations and matches synonyms in search', () {
      final names = kGlobalExerciseCatalog.map((e) => e.name).toSet();
      expect(names, containsAll([
        'Tricep Pushdowns',
        'Rope Tricep Pushdowns',
        'Straight-Bar Tricep Pushdowns',
        'V-Bar Tricep Pushdowns',
        'EZ-Bar Tricep Pushdowns',
        'Reverse-Grip Tricep Pushdowns',
        'Single-Arm Tricep Pushdowns',
        'Overhead Cable Tricep Extensions',
        'Rope Overhead Cable Tricep Extensions',
        'Straight-Bar Overhead Cable Tricep Extensions',
        'V-Bar Overhead Cable Tricep Extensions',
        'EZ-Bar Overhead Cable Tricep Extensions',
        'Single-Arm Overhead Cable Tricep Extensions',
        'Rope Cable Hammer Curls',
        'Straight-Bar Cable Curls',
        'EZ-Bar Cable Curls',
        'Single-Arm Cable Curls',
        'V-Bar Lat Pulldowns',
        'Single-Arm Lat Pulldowns',
        'Rope Straight-Arm Pulldowns',
        'V-Bar Seated Cable Rows',
        'Straight-Bar Seated Cable Rows',
      ]));

      // Synonym search: "triangle" finds V-Bar variants; "straight handle" finds Straight-Bar
      expect(matchesExerciseSearch('V-Bar Tricep Pushdowns', 'triangle'), isTrue);
      expect(matchesExerciseSearch('V-Bar Overhead Cable Tricep Extensions', 'triangle tricep'), isTrue);
      expect(matchesExerciseSearch('Straight-Bar Tricep Pushdowns', 'straight handle'), isTrue);
      expect(matchesExerciseSearch('DB Bench Press', 'dumbbell bench'), isTrue);

      // Deduplication shorthands map "Triangle pushdown" -> V-Bar Tricep Pushdowns
      expect(
        normalizeExerciseSignature('Triangle handle tricep pushdown'),
        normalizeExerciseSignature('V-Bar Tricep Pushdowns'),
      );
      expect(
        normalizeExerciseSignature('Straight handle pushdowns'),
        normalizeExerciseSignature('Straight-Bar Tricep Pushdowns'),
      );
    });

    test('maps spelling, plural, hyphen, equipment, and shorthand variants to canonical signatures', () {
      expect(
        normalizeExerciseSignature('Lats pulldown'),
        normalizeExerciseSignature('Lat Pulldowns'),
      );
      expect(
        normalizeExerciseSignature('Lat pull-down'),
        normalizeExerciseSignature('Lat Pulldowns'),
      );
      expect(
        normalizeExerciseSignature('Pullups'),
        normalizeExerciseSignature('Pull-Ups'),
      );
      expect(
        normalizeExerciseSignature('Push ups'),
        normalizeExerciseSignature('Push-Ups'),
      );
      expect(
        normalizeExerciseSignature('Dumbbell Bench Press'),
        normalizeExerciseSignature('DB Bench Press'),
      );
      expect(
        normalizeExerciseSignature('Incline DB Press'),
        normalizeExerciseSignature('Incline DB Bench Press'),
      );
      expect(
        normalizeExerciseSignature('RDL'),
        normalizeExerciseSignature('Romanian Deadlifts'),
      );
      expect(
        normalizeExerciseSignature('Military Press'),
        normalizeExerciseSignature('Overhead Press'),
      );
    });
  });

  group('ExercisesDao.deduplicateLegacyExercisesV1 & mergeExerciseInto', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('automatically merges active and archived duplicate exercises (moving sets, WODs, challenges, notes, variations) while preserving truly custom exercises', () async {
      await db.exercisesDao.syncGlobalCatalogV1();

      final canonicalAll = await db.exercisesDao.getAllExercises();
      final latPulldowns =
          canonicalAll.firstWhere((e) => e.name == 'Lat Pulldowns');
      final dbBench =
          canonicalAll.firstWhere((e) => e.name == 'DB Bench Press');
      final bbRows = canonicalAll.firstWhere((e) => e.name == 'BB Rows');

      // 1. Active duplicate: "Lats pulldown" with logged sets, WOD entry, challenge, note, and custom variation
      final latsDupId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(
          name: 'Lats pulldown',
          notes: const Value('Use mag grip'),
        ),
      );
      // 2. Archived duplicate: "Dumbbell Bench Press" with logged sets
      final archivedDbBenchId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(
          name: 'Dumbbell Bench Press',
          archived: const Value(true),
        ),
      );
      // 3. Truly custom exercise that should NOT be auto-merged
      final customMachineId = await db.exercisesDao.insertExercise(
        ExercisesCompanion.insert(name: 'Gym Custom Nautilus Pullover #2'),
      );

      final sessionId = await db.sessionsDao.insertSession(
        WorkoutSessionsCompanion.insert(
          date: DateTime(2026, 11, 20),
          workoutName: 'Upper A',
        ),
      );
      await db.setsDao.insertSet(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: latsDupId,
          setNumber: 1,
          weightKg: 75,
          reps: 10,
        ),
      );
      await db.setsDao.insertSet(
        WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: archivedDbBenchId,
          setNumber: 1,
          weightKg: 40,
          reps: 8,
        ),
      );

      // Attach a WOD template entry, note, challenge, and variation to latsDupId
      final wodId = await db.programsDao.insertWodTemplate(
        WodTemplatesCompanion.insert(wodNumber: 1, name: 'Flash Pull'),
      );
      await db.programsDao.insertWodTemplateExercise(
        WodTemplateExercisesCompanion.insert(
          wodTemplateId: wodId,
          exerciseId: latsDupId,
          sortOrder: 0,
        ),
      );
      await db.exerciseNotesDao.addNote(latsDupId, 'Keep chest tall');
      await db.into(db.challenges).insert(
            ChallengesCompanion.insert(
              exerciseId: latsDupId,
              targetWeightKg: const Value(90),
              targetReps: const Value(8),
            ),
          );
      await db.exerciseVariationsDao.addVariation(latsDupId, bbRows.id);

      // Preview impact before merge
      final impact = await db.exercisesDao.previewMergeImpact(latsDupId);
      expect(impact.setCount, 1);
      expect(impact.templateCount, 1);
      expect(impact.challengeCount, 1);
      expect(impact.noteCount, 1);

      // Run automatic deduplication
      final mergedCount = await db.exercisesDao.deduplicateLegacyExercisesV1();
      expect(mergedCount, 2);

      final afterAll = await db.exercisesDao.getAllExercisesIncludingArchived();
      final afterNames = afterAll.map((e) => e.name).toSet();
      expect(afterNames.contains('Lats pulldown'), isFalse);
      expect(afterNames.contains('Dumbbell Bench Press'), isFalse);
      expect(afterNames.contains('Gym Custom Nautilus Pullover #2'), isTrue);

      // Verify sets moved onto canonical Lat Pulldowns & DB Bench Press
      final sets = await db.setsDao.getSetsForSession(sessionId);
      expect(
        sets.map((s) => s.exerciseId).toSet(),
        equals({latPulldowns.id, dbBench.id}),
      );

      // Verify WOD entry, challenge, note, inline note, and variation moved onto Lat Pulldowns
      final wodEntries = await db.programsDao.getAllTemplateExercises(wodId);
      expect(wodEntries.single.exerciseId, latPulldowns.id);

      final notes = await db.exerciseNotesDao.getNotesForExercise(latPulldowns.id);
      expect(notes.single.note, 'Keep chest tall');

      final refreshedLat =
          afterAll.firstWhere((e) => e.id == latPulldowns.id);
      expect(refreshedLat.notes, 'Use mag grip');

      final challenges = await db.select(db.challenges).get();
      expect(challenges.single.exerciseId, latPulldowns.id);

      final latVars =
          await db.exerciseVariationsDao.getVariations(latPulldowns.id);
      expect(latVars.map((v) => v.id), contains(bbRows.id));

      // Manual merge of custom exercise into Lat Pulldowns works too
      await db.exercisesDao.mergeExerciseInto(
        sourceId: customMachineId,
        targetId: latPulldowns.id,
      );
      final finalAll = await db.exercisesDao.getAllExercisesIncludingArchived();
      expect(
        finalAll.any((e) => e.id == customMachineId),
        isFalse,
      );
    });
  });
}
