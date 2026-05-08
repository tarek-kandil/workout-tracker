import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/user_profile_table.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  static const _id = 1;

  Stream<UserProfile?> watchProfile() =>
      (select(userProfiles)..where((t) => t.id.equals(_id)))
          .watchSingleOrNull();

  Future<UserProfile?> getProfile() =>
      (select(userProfiles)..where((t) => t.id.equals(_id)))
          .getSingleOrNull();

  Future<void> upsertProfile(UserProfilesCompanion companion) =>
      into(userProfiles).insertOnConflictUpdate(
        companion.copyWith(id: const Value(_id)),
      );
}
