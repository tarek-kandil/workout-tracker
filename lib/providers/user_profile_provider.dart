import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(databaseProvider).userProfileDao.watchProfile();
});
