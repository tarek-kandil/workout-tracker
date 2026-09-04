import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/screens/log/models/session_models.dart';
import 'package:workout_tracker/screens/log/widgets/numeric_keypad.dart';
import 'package:workout_tracker/screens/log/widgets/set_row.dart';

void main() {
  group('NumericKeypadBuffer', () {
    test('accumulates digits', () {
      var buf = const NumericKeypadBuffer('');
      buf = buf.withDigit('1').withDigit('2').withDigit('5');
      expect(buf.text, '125');
      expect(buf.numericValue, 125.0);
    });

    test('replaces a lone leading zero instead of accumulating', () {
      var buf = const NumericKeypadBuffer('0');
      buf = buf.withDigit('7');
      expect(buf.text, '7');
    });

    test('decimal point is accepted once, seeded with 0 if empty', () {
      var buf = const NumericKeypadBuffer('');
      buf = buf.withDecimalPoint().withDigit('5');
      expect(buf.text, '0.5');
      expect(buf.numericValue, 0.5);

      // A second "." is a no-op.
      buf = buf.withDecimalPoint();
      expect(buf.text, '0.5');
    });

    test('decimal point is ignored when allowDecimal is false', () {
      var buf = const NumericKeypadBuffer('', allowDecimal: false);
      buf = buf.withDecimalPoint().withDigit('9');
      expect(buf.text, '9');
    });

    test('backspace removes the last character, clear wipes everything', () {
      var buf = const NumericKeypadBuffer('12.5');
      buf = buf.backspace();
      expect(buf.text, '12.');
      buf = buf.clear();
      expect(buf.text, '');
    });

    test('backspace on empty buffer is a no-op', () {
      const buf = NumericKeypadBuffer('');
      expect(buf.backspace().text, '');
    });

    test('numericValue accepts a comma as the decimal separator', () {
      const buf = NumericKeypadBuffer('82,5');
      expect(buf.numericValue, 82.5);
    });

    test('numericValue is null for an empty or dangling-dot buffer', () {
      expect(const NumericKeypadBuffer('').numericValue, isNull);
      expect(const NumericKeypadBuffer('.').numericValue, isNull);
    });

    test('respects the max-length guard', () {
      var buf = const NumericKeypadBuffer('');
      for (var i = 0; i < 12; i++) {
        buf = buf.withDigit('9');
      }
      expect(buf.text.length, lessThanOrEqualTo(7));
    });
  });

  group('clampNumericValue', () {
    test('weight clamps to >= 0 but has no upper bound', () {
      expect(clampNumericValue(-5, min: 0, allowDecimal: true), 0);
      expect(clampNumericValue(182.5, min: 0, allowDecimal: true), 182.5);
    });

    test('reps clamp to [1, 999] and round to whole numbers', () {
      expect(clampNumericValue(0, min: 1, max: 999, allowDecimal: false), 1);
      expect(clampNumericValue(5.6, min: 1, max: 999, allowDecimal: false), 6);
      expect(clampNumericValue(5000, min: 1, max: 999, allowDecimal: false), 999);
    });

    test('duration clamps to [5, 3600] and rounds to whole seconds', () {
      expect(clampNumericValue(2, min: 5, max: 3600, allowDecimal: false), 5);
      expect(clampNumericValue(4000, min: 5, max: 3600, allowDecimal: false), 3600);
      expect(clampNumericValue(90.4, min: 5, max: 3600, allowDecimal: false), 90);
    });
  });

  group('NumericKeypadSheet widget', () {
    testWidgets('typing digits then Done commits the typed value', (tester) async {
      NumericKeypadResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showNumericKeypadSheet(
                context,
                title: 'Weight',
                initialValue: 20,
                allowDecimal: true,
                unit: 'kg',
                quickAdjusts: const [-2.5, 2.5],
                min: 0,
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Clear the seeded "20" then type "82.5".
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      await tester.longPress(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('.'));
      await tester.tap(find.text('5'));
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.value, 82.5);
      expect(result!.moveNext, isFalse);
    });

    testWidgets('quick-adjust chip nudges the seeded value', (tester) async {
      NumericKeypadResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showNumericKeypadSheet(
                context,
                title: 'Weight',
                initialValue: 20,
                allowDecimal: true,
                unit: 'kg',
                quickAdjusts: const [-2.5, 2.5],
                min: 0,
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+2.5'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result!.value, 22.5);
    });

    testWidgets('reps/duration mode hides the decimal key and rounds on confirm', (tester) async {
      NumericKeypadResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showNumericKeypadSheet(
                context,
                title: 'Reps',
                initialValue: 8,
                allowDecimal: false,
                unit: 'reps',
                quickAdjusts: const [-1, 1],
                min: 1,
                max: 999,
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('.'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(result!.value, 8);
    });

    testWidgets('Next label and moveNext flag are set when showNextButton is true', (tester) async {
      NumericKeypadResult? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showNumericKeypadSheet(
                context,
                title: 'Weight',
                initialValue: 20,
                allowDecimal: true,
                unit: 'kg',
                quickAdjusts: const [],
                min: 0,
                showNextButton: true,
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Next ›'), findsOneWidget);
      await tester.tap(find.text('Next ›'));
      await tester.pumpAndSettle();

      expect(result!.moveNext, isTrue);
    });

    testWidgets('dismissing the sheet without confirming returns null', (tester) async {
      NumericKeypadResult? result = const NumericKeypadResult(value: -1);
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showNumericKeypadSheet(
                context,
                title: 'Weight',
                initialValue: 20,
                allowDecimal: true,
                unit: 'kg',
                quickAdjusts: const [],
                min: 0,
              );
            },
            child: const Text('open'),
          );
        }),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the scrim above the sheet to dismiss it.
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('SetRow integration', () {
    testWidgets('tapping the weight value opens the keypad and commits via onChanged', (tester) async {
      SetData? committed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetRow(
            setNumber: 1,
            isTimed: false,
            data: SetData(weightKg: 60, reps: 8),
            onChanged: (d) => committed = d,
          ),
        ),
      ));

      await tester.tap(find.text('60 kg'));
      await tester.pumpAndSettle();

      // No system keyboard field should be present.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('+2.5'));
      await tester.pump();
      // Weight always chains to reps next, so the primary action reads
      // "Next ›" rather than "Done".
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.text('Next ›'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(committed, isNotNull);
      expect(committed!.weightKg, 62.5);
      expect(committed!.reps, 8);
    });

    testWidgets('weight "Next" opens the reps keypad and both commits apply', (tester) async {
      final commits = <SetData>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetRow(
            setNumber: 1,
            isTimed: false,
            data: SetData(weightKg: 60, reps: 8),
            onChanged: (d) => commits.add(d),
          ),
        ),
      ));

      await tester.tap(find.text('60 kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next ›'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // The reps keypad should now be open — confirm it without changes.
      expect(find.text('Reps'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(commits.length, 2);
      expect(commits.first.weightKg, 60);
      expect(commits.last.reps, 8);
    });

    testWidgets('duration field rounds and clamps within [5, 3600] seconds', (tester) async {
      SetData? committed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SetRow(
            setNumber: 1,
            isTimed: true,
            data: SetData(weightKg: 0, reps: 0, durationSeconds: 30),
            onChanged: (d) => committed = d,
          ),
        ),
      ));

      await tester.tap(find.text('0:30'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('+15'));
      await tester.tap(find.text('+15'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(committed!.durationSeconds, 60);
      expect(committed!.reps, 0);
    });
  });
}
