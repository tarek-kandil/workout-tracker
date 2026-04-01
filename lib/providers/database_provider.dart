import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

// Single database instance for the entire app — like a singleton service
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
