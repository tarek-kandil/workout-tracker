import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

// Reactive stream of all exercises — any UI watching this rebuilds when data changes
final exercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.exercisesDao.watchAllExercises();
});
