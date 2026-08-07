import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercise_notes_table.dart';

part 'exercise_notes_dao.g.dart';

@DriftAccessor(tables: [ExerciseNotes])
class ExerciseNotesDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseNotesDaoMixin {
  ExerciseNotesDao(super.db);

  Future<int> addNote(int exerciseId, String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(note, 'note', 'Exercise note cannot be empty');
    }
    return into(exerciseNotes).insert(
      ExerciseNotesCompanion.insert(exerciseId: exerciseId, note: trimmed),
    );
  }

  Future<List<ExerciseNote>> getNotesForExercise(int exerciseId) =>
      (select(exerciseNotes)
            ..where((n) => n.exerciseId.equals(exerciseId))
            ..orderBy([
              (n) => OrderingTerm(
                expression: n.createdAt,
                mode: OrderingMode.desc,
              ),
              (n) => OrderingTerm(expression: n.id, mode: OrderingMode.desc),
            ]))
          .get();

  Future<void> deleteNote(int id) =>
      (delete(exerciseNotes)..where((n) => n.id.equals(id))).go();
}
