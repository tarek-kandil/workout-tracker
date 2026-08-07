import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/services/personal_record_detection.dart';

void main() {
  group('evaluateWeightPersonalRecord', () {
    test('counts the first non-empty weighted set as a PR', () {
      final result = evaluateWeightPersonalRecord(
        currentTopWeightKg: null,
        bestRepsAtCurrentTopWeight: 0,
        weightKg: 40,
        reps: 8,
      );

      expect(result.isPersonalRecord, isTrue);
      expect(result.isNewTopWeight, isTrue);
    });

    test('does not count empty or zero-rep sets', () {
      expect(
        evaluateWeightPersonalRecord(
          currentTopWeightKg: null,
          bestRepsAtCurrentTopWeight: 0,
          weightKg: 0,
          reps: 8,
        ).isPersonalRecord,
        isFalse,
      );
      expect(
        evaluateWeightPersonalRecord(
          currentTopWeightKg: 100,
          bestRepsAtCurrentTopWeight: 5,
          weightKg: 100,
          reps: 0,
        ).isPersonalRecord,
        isFalse,
      );
    });

    test('counts heavier weight as a PR', () {
      final result = evaluateWeightPersonalRecord(
        currentTopWeightKg: 100,
        bestRepsAtCurrentTopWeight: 5,
        weightKg: 102.5,
        reps: 3,
      );

      expect(result.isPersonalRecord, isTrue);
      expect(result.isNewTopWeight, isTrue);
    });

    test('counts more reps at the current top weight as a PR', () {
      final result = evaluateWeightPersonalRecord(
        currentTopWeightKg: 100,
        bestRepsAtCurrentTopWeight: 5,
        weightKg: 100,
        reps: 6,
      );

      expect(result.isPersonalRecord, isTrue);
      expect(result.isMoreRepsAtTopWeight, isTrue);
    });

    test('does not count same top weight with fewer reps', () {
      final result = evaluateWeightPersonalRecord(
        currentTopWeightKg: 100,
        bestRepsAtCurrentTopWeight: 5,
        weightKg: 100,
        reps: 4,
      );

      expect(result.isPersonalRecord, isFalse);
    });
  });
}
