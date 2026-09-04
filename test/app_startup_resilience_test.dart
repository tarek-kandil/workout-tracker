import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/main.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/providers/weight_goal_providers.dart';

/// A [QueryExecutor] whose every operation throws, simulating a database
/// that genuinely cannot be opened/migrated (e.g. a corrupt file or a
/// migration step that fails on real device data).
class _AlwaysThrowingExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  QueryExecutor beginExclusive() => throw StateError('db unavailable');

  @override
  TransactionExecutor beginTransaction() =>
      throw StateError('db unavailable');

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      throw StateError('db unavailable');

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      throw StateError('db unavailable');

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      throw StateError('db unavailable');

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      throw StateError('db unavailable');

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) =>
      throw StateError('db unavailable');

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      throw StateError('db unavailable');

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) =>
      throw StateError('db unavailable');
}

/// Regression tests for the "infinite spinner" production bug fix.
///
/// `runAppStartup` (extracted from `_AppStartupState._initialize` in
/// main.dart) must always resolve to a [StartupResult] — never hang and
/// never let a non-critical step's exception escape uncaught — except when
/// the database itself cannot be opened/migrated, which is the one
/// genuinely fatal case.
class _ThrowingWeightGoalActions extends WeightGoalActions {
  _ThrowingWeightGoalActions(super.ref);

  @override
  Future<void> rescheduleReminder() async {
    throw Exception('injected failure: reschedule always throws');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'runAppStartup reaches ready even though notifications/audio plugin '
    'calls throw in the test harness (unmocked platform channels) — this '
    'reproduces the exact unguarded-async-chain bug from main.dart',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final result = await runAppStartup(container);

      expect(result.success, isTrue);
      expect(result.fatalError, isNull);
    },
  );

  test(
    'runAppStartup still reaches ready when the weigh-in reminder '
    'reschedule throws (injected failure) — it is fire-and-forget and off '
    'the critical path',
    () async {
      // Give the notifications plugin a working fake so this test isolates
      // the injected reschedule failure specifically.
      FlutterLocalNotificationsPlatform.instance =
          _FakeFlutterLocalNotificationsPlatform();

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          weightGoalActionsProvider
              .overrideWith((ref) => _ThrowingWeightGoalActions(ref)),
        ],
      );
      addTearDown(container.dispose);

      final result = await runAppStartup(container);

      expect(result.success, isTrue);
      expect(result.fatalError, isNull);

      // Let the fire-and-forget reschedule's caught exception settle before
      // the test tears down the container.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    },
  );

  test(
    'runAppStartup reports a fatal StartupResult when the database itself '
    'cannot be opened/migrated (the one case that must show an error '
    'screen instead of booting into a broken state)',
    () async {
      final db = AppDatabase.forTesting(_AlwaysThrowingExecutor());

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final result = await runAppStartup(container);

      expect(result.success, isFalse);
      expect(result.fatalError, isNotNull);
    },
  );
}

class _FakeFlutterLocalNotificationsPlatform
    extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancel(int id) async {}
}
