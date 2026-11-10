import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/screens/log/models/session_models.dart';
import 'package:workout_tracker/screens/log/widgets/history_chip_row.dart';

WorkoutSet _set(int n, double kg, int reps) => WorkoutSet(
      id: n, sessionId: 1, exerciseId: 1, setNumber: n, reps: reps,
      weightKg: kg, durationSeconds: null, rpe: null, rir: null, notes: null,
    );

void main() {
  Widget host(List<ExerciseHistory> tabs, {List<WorkoutSet> last = const []}) => MaterialApp(
        home: Scaffold(
          body: HistoryChipRow(
            lastSets: last, isTimed: false, prKg: null, prDurationSeconds: null,
            expanded: true, onToggle: () {}, tabs: tabs,
          ),
        ),
      );

  testWidgets('two histories show a switch and flip between logs', (tester) async {
    await tester.pumpWidget(host([
      ExerciseHistory(name: 'Cable Row', date: DateTime(2026, 10, 12), sets: [_set(1, 40, 10)]),
      ExerciseHistory(name: 'Barbell Row', date: DateTime(2026, 10, 5), sets: [_set(1, 70, 8)]),
    ]));

    expect(find.text('Cable Row · 12 Oct'), findsOneWidget);
    expect(find.text('Barbell Row · 5 Oct'), findsOneWidget);
    expect(find.text('40 kg'), findsOneWidget);
    expect(find.text('70 kg'), findsNothing);

    await tester.tap(find.text('Barbell Row · 5 Oct'));
    await tester.pump();
    expect(find.text('70 kg'), findsOneWidget);
    expect(find.text('40 kg'), findsNothing);
  });

  testWidgets('a single history shows a caption instead of a switch', (tester) async {
    await tester.pumpWidget(host([
      ExerciseHistory(name: 'Cable Row', date: DateTime(2026, 10, 12), sets: const []),
      ExerciseHistory(name: 'Barbell Row', date: DateTime(2026, 10, 5), sets: [_set(1, 70, 8)]),
    ]));
    expect(find.text('Barbell Row · 5 Oct'), findsOneWidget);
    expect(find.text('Cable Row · 12 Oct'), findsNothing);
    expect(find.text('70 kg'), findsOneWidget);
  });

  testWidgets('without tabs it falls back to lastSets', (tester) async {
    await tester.pumpWidget(host(const [], last: [_set(1, 55, 6)]));
    expect(find.text('55 kg'), findsOneWidget);
  });
}
