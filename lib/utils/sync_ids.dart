import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Fixed namespace URL used to derive deterministic UUID v5 identifiers for
/// global library records so every device and the backend share identical IDs.
const String _kGlobalNamespace = 'https://workout-tracker.app/global/v1';

/// Generates a random RFC-4122 UUID v4 for user-created local records.
String generateUuidV4() => _uuid.v4();

/// Deterministic UUID v5 for a global catalog exercise identified by
/// [canonicalKey] (e.g. `'bench_press'`).
String globalExerciseSyncId(String canonicalKey) =>
    _uuid.v5(Namespace.url.value, '$_kGlobalNamespace/exercise/$canonicalKey');

/// Deterministic UUID v5 for an active muscle assignment on a global catalog
/// exercise.
String globalExerciseMuscleSyncId(
  String canonicalKey,
  String role,
  String muscle,
) =>
    _uuid.v5(
      Namespace.url.value,
      '$_kGlobalNamespace/exercise-muscle/$canonicalKey/$role/$muscle',
    );

/// Deterministic UUID v5 for a symmetric variation link between two global
/// catalog exercises (order-independent).
String globalExerciseVariationSyncId(String keyA, String keyB) {
  final minKey = keyA.compareTo(keyB) <= 0 ? keyA : keyB;
  final maxKey = keyA.compareTo(keyB) <= 0 ? keyB : keyA;
  return _uuid.v5(
    Namespace.url.value,
    '$_kGlobalNamespace/exercise-variation/$minKey/$maxKey',
  );
}
