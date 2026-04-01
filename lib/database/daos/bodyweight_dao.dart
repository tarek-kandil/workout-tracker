import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/bodyweight_table.dart';

part 'bodyweight_dao.g.dart';

@DriftAccessor(tables: [BodyweightEntries])
class BodyweightDao extends DatabaseAccessor<AppDatabase>
    with _$BodyweightDaoMixin {
  BodyweightDao(super.db);

  Stream<BodyweightEntry?> watchLatestBodyweight() =>
      (select(bodyweightEntries)
            ..orderBy([(b) =>
                OrderingTerm(expression: b.date, mode: OrderingMode.desc)])
            ..limit(1))
          .watchSingleOrNull();

  Future<List<BodyweightEntry>> getRecentBodyweights(int n) =>
      (select(bodyweightEntries)
            ..orderBy([(b) =>
                OrderingTerm(expression: b.date, mode: OrderingMode.desc)])
            ..limit(n))
          .get();

  Stream<List<BodyweightEntry>> watchRecentBodyweights(int n) =>
      (select(bodyweightEntries)
            ..orderBy([(b) =>
                OrderingTerm(expression: b.date, mode: OrderingMode.desc)])
            ..limit(n))
          .watch();

  Stream<List<BodyweightEntry>> watchAllBodyweights() =>
      (select(bodyweightEntries)
            ..orderBy([(b) =>
                OrderingTerm(expression: b.date, mode: OrderingMode.desc)]))
          .watch();

  Future<int> insertBodyweight(BodyweightEntriesCompanion entry) =>
      into(bodyweightEntries).insert(entry);

  Future<void> deleteBodyweight(int id) =>
      (delete(bodyweightEntries)..where((b) => b.id.equals(id))).go();
}
