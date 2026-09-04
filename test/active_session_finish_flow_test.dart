import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/models/next_wod_result.dart';
import 'package:workout_tracker/models/weight_suggestion.dart';
import 'package:workout_tracker/models/wod_item.dart';
import 'package:workout_tracker/providers/database_provider.dart';
import 'package:workout_tracker/screens/log/active_session_screen.dart';
import 'package:workout_tracker/screens/log/widgets/check_circle_button.dart';
import 'package:workout_tracker/screens/log/widgets/circuit_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance =
        _FakeFlutterLocalNotificationsPlatform();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'standalone workout with all sets logged finishes without incomplete warning',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final squat = await builder.addStandalone('Back Squat', sets: 2);
          return _SavedProgress.completeStandalone(
            wodId: builder.wodId,
            exerciseIds: [squat.exercise.id],
            loggedSetsByExercise: {
              squat.exercise.id: [
                _setJson(weight: 100, reps: 5),
                _setJson(weight: 102.5, reps: 5),
              ],
            },
            currentSetIdx: 2,
          );
        },
      );

      await _openReview(tester);

      expect(find.text('Review & Finish'), findsOneWidget);
      expect(find.text('1 of 1 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Completed / resolved'), '1');
      expect(_statValue(tester, 'Sets logged'), '2');
      expect(find.text('Finish with unfinished work?'), findsNothing);

      await _tapReviewFinish(tester);
      await tester.pump();

      expect(find.text('Finish with unfinished work?'), findsNothing);
      await _finishOverlay(tester);
      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'circuit final round registers complete before finish warning decision',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit(
            'Conditioning Circuit',
            ['Burpee', 'Kettlebell Swing'],
            rounds: 2,
            repRangeMin: 0,
            repRangeMax: 0,
          );
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 1,
            circuitExIdx: 1,
            sets: {
              for (final entry in circuit.exercises)
                '${entry.exercise.id}': [_setJson(), _setJson()],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );

      await tester.tap(
        find.descendant(
          of: find.byType(CheckCircleButton),
          matching: find.byIcon(Icons.check),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      await _openReview(tester);

      expect(find.text('2 of 2 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Completed / resolved'), '2');

      await _tapReviewFinish(tester);
      await tester.pump();

      expect(find.text('Finish with unfinished work?'), findsNothing);
      await _finishOverlay(tester);
      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'mixed logged skipped and untouched sets only treats untouched planned sets as unfinished',
    (tester) async {
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final press = await builder.addStandalone('Overhead Press', sets: 3);
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 1,
            circuitExIdx: 0,
            sets: {
              '${press.exercise.id}': [
                _setJson(weight: 45, reps: 8),
                _setJson(),
                _setJson(),
              ],
            },
            items: [
              _standaloneItemJson(press, skippedSets: [2]),
            ],
          );
        },
      );

      await _openReview(tester);

      expect(find.text('0 of 1 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Sets logged'), '1');
      expect(find.text('Unfinished (1)'), findsOneWidget);
      expect(find.text('• Overhead Press'), findsOneWidget);

      await _tapReviewFinish(tester);
      await tester.pumpAndSettle();

      expect(find.text('Finish with unfinished work?'), findsOneWidget);
      expect(find.textContaining('completed 0 of 1 exercises'), findsOneWidget);
      expect(find.text('• Overhead Press'), findsOneWidget);
    },
  );

  testWidgets(
    'fully skipped exercises and sets are resolved and finish without warning',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final accessory = await builder.addStandalone('Cable Fly', sets: 2);
          final curls = await builder.addStandalone('Hammer Curl', sets: 2);
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 1,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              '${accessory.exercise.id}': [_setJson(), _setJson()],
              '${curls.exercise.id}': [_setJson(), _setJson()],
            },
            items: [
              _standaloneItemJson(accessory, skipped: true),
              _standaloneItemJson(curls, skippedSets: [0, 1]),
            ],
          );
        },
      );

      await _openReview(tester);

      expect(find.text('2 of 2 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Skipped'), '1');
      expect(find.text('Unfinished (1)'), findsNothing);

      await _tapReviewFinish(tester);
      await tester.pump();

      expect(find.text('Finish with unfinished work?'), findsNothing);
      await _finishOverlay(tester);
      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'incomplete warning names unfinished exercises and keep going versus finish anyway work',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final bench = await builder.addStandalone('Bench Press');
          final row = await builder.addStandalone('Barbell Row');
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 1,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              '${bench.exercise.id}': [_setJson(weight: 80, reps: 6)],
              '${row.exercise.id}': [_setJson()],
            },
            items: [_standaloneItemJson(bench), _standaloneItemJson(row)],
          );
        },
      );

      await _openReview(tester);
      expect(await _sessionCount(harness.db), 0);

      await _tapReviewFinish(tester);
      await tester.pumpAndSettle();

      expect(find.text('Finish with unfinished work?'), findsOneWidget);
      expect(find.textContaining('completed 1 of 2 exercises'), findsOneWidget);
      expect(find.text('• Barbell Row'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Keep going'));
      await tester.pumpAndSettle();

      expect(find.text('Finish with unfinished work?'), findsNothing);
      expect(find.text('Barbell Row'), findsOneWidget);
      expect(await _sessionCount(harness.db), 0);

      await _openReview(tester);
      await _tapReviewFinish(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Finish anyway'));
      await tester.pump();

      await _finishOverlay(tester);
      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'opening review does not complete and rapid final finish still creates one session',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final deadlift = await builder.addStandalone('Deadlift');
          return _SavedProgress.completeStandalone(
            wodId: builder.wodId,
            exerciseIds: [deadlift.exercise.id],
            loggedSetsByExercise: {
              deadlift.exercise.id: [_setJson(weight: 140, reps: 3)],
            },
            currentSetIdx: 1,
          );
        },
      );

      await _openReview(tester);
      expect(find.text('Review & Finish'), findsOneWidget);
      expect(await _sessionCount(harness.db), 0);

      final finishButton = find.widgetWithText(FilledButton, 'Finish');
      await tester.tap(finishButton);
      await tester.tap(finishButton, warnIfMissed: false);
      await tester.pump();

      await _finishOverlay(tester);
      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'duplicate unfinished exercise names retain count and visible entries',
    (tester) async {
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final first = await builder.addStandalone('Single Arm Row');
          final second = await builder.addStandalone('Single Arm Row');
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              '${first.exercise.id}': [_setJson()],
              '${second.exercise.id}': [_setJson()],
            },
            items: [_standaloneItemJson(first), _standaloneItemJson(second)],
          );
        },
      );

      await _openReview(tester);

      expect(find.text('0 of 2 exercises done'), findsOneWidget);
      expect(find.text('Unfinished (2)'), findsOneWidget);
      expect(find.text('• Single Arm Row'), findsNWidgets(2));

      await _tapReviewFinish(tester);
      await tester.pumpAndSettle();

      expect(find.text('Finish with unfinished work?'), findsOneWidget);
      expect(find.textContaining('completed 0 of 2 exercises'), findsOneWidget);
      expect(find.text('• Single Arm Row'), findsNWidgets(2));
    },
  );

  testWidgets(
    'removing circuit exercises keeps neighbors, drops empty circuit, and finish works',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit('Removal Circuit', [
            'Air Squat',
            'Push-up',
            'Sit-up',
          ], rounds: 1);
          final finisher = await builder.addStandalone('Cool Down Walk');
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 1,
            setIdx: 1,
            circuitExIdx: 0,
            sets: {
              for (final entry in circuit.exercises)
                '${entry.exercise.id}': [_setJson(weight: 10, reps: 10)],
              '${finisher.exercise.id}': [_setJson()],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
              _standaloneItemJson(finisher),
            ],
          );
        },
      );

      await _removeCircuitExerciseByName(tester, 'Push-up');
      expect(find.text('Air Squat'), findsOneWidget);
      expect(find.text('Push-up'), findsNothing);
      expect(find.text('Sit-up'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _removeCircuitExerciseByName(tester, 'Air Squat');
      expect(find.text('Air Squat'), findsNothing);
      expect(find.text('Sit-up'), findsOneWidget);
      expect(find.text('Removal Circuit'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _removeCircuitExerciseByName(tester, 'Sit-up');
      expect(find.text('Removal Circuit'), findsNothing);
      expect(find.text('Sit-up'), findsNothing);
      expect(find.text('Cool Down Walk'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _openReview(tester);
      expect(find.text('1 of 1 exercises done'), findsOneWidget);
      await _tapReviewFinish(tester);
      await tester.pump();
      expect(find.text('Finish with unfinished work?'), findsNothing);
      await _finishOverlay(tester);

      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'removing a completed middle circuit exercise preserves completion summary counts',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit('Summary Circuit', [
            'Power Clean',
            'Front Squat',
            'Jerk',
          ], rounds: 1);
          final cooldown = await builder.addStandalone('Cooldown Walk');
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 1,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              '${circuit.exercises[0].exercise.id}': [
                _setJson(weight: 60, reps: 3),
              ],
              '${circuit.exercises[1].exercise.id}': [
                _setJson(weight: 70, reps: 3),
              ],
              '${circuit.exercises[2].exercise.id}': [
                _setJson(weight: 65, reps: 3),
              ],
              '${cooldown.exercise.id}': [_setJson()],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
              _standaloneItemJson(cooldown, skipped: true),
            ],
          );
        },
      );
      await _removeCircuitExerciseByName(tester, 'Front Squat');

      await _openReview(tester);
      expect(find.text('3 of 3 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Completed / resolved'), '3');
      expect(_statValue(tester, 'Sets logged'), '2');
      expect(_statValue(tester, 'Skipped'), '1');
      expect(find.text('• Front Squat'), findsNothing);

      await _tapReviewFinish(tester);
      await tester.pump();
      expect(find.text('Finish with unfinished work?'), findsNothing);
      await _finishOverlay(tester);

      expect(await _sessionCount(harness.db), 1);
      expect(await _setCount(harness.db), 2);
      expect(await _setCountForExerciseName(harness.db, 'Front Squat'), 0);
    },
  );

  testWidgets(
    'removing the active circuit exercise lands on a valid neighbor',
    (tester) async {
      final harness = await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit('Active Removal Circuit', [
            'Step-up',
            'Lunge',
            'Box Jump',
          ], rounds: 1);
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 0,
            circuitExIdx: 1,
            sets: {
              '${circuit.exercises[0].exercise.id}': [
                _setJson(weight: 20, reps: 8),
              ],
              '${circuit.exercises[1].exercise.id}': [
                _setJson(weight: 20, reps: 8),
              ],
              '${circuit.exercises[2].exercise.id}': [_setJson()],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );

      await _removeCircuitExerciseByName(tester, 'Lunge');
      expect(find.text('Lunge'), findsNothing);
      expect(_sectionHasNowBadge('Box Jump'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _completeVisibleSet(tester);
      await _openReview(tester);
      expect(find.text('2 of 2 exercises done'), findsOneWidget);
      await _tapReviewFinish(tester);
      await tester.pump();
      await _finishOverlay(tester);

      expect(await _sessionCount(harness.db), 1);
    },
  );

  testWidgets(
    'circuit exercise swap sheet exposes variations and regenerates set data',
    (tester) async {
      late Exercise weightedVariation;
      late Exercise timedVariation;
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit(
            'Swap Circuit',
            ['Bench Press', 'Plank'],
            rounds: 2,
            timedExerciseNames: {'Plank'},
            repRangeMin: 30,
            repRangeMax: 30,
          );
          weightedVariation = await builder.addLibraryExercise(
            'Dumbbell Bench Press',
          );
          timedVariation = await builder.addLibraryExercise(
            'Side Plank',
            isTimed: true,
          );
          await builder.addVariation(
            circuit.exercises[0].exercise.id,
            weightedVariation.id,
          );
          await builder.addVariation(
            circuit.exercises[1].exercise.id,
            timedVariation.id,
          );
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              '${circuit.exercises[0].exercise.id}': [
                _setJson(weight: 80, reps: 8),
                _setJson(weight: 82.5, reps: 8),
              ],
              '${circuit.exercises[1].exercise.id}': [
                _setJson(duration: 30),
                _setJson(duration: 35),
              ],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );

      await _openCircuitExerciseActions(tester, 'Bench Press');
      await tester.tap(find.text('Swap Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Swap Exercise'), findsOneWidget);
      expect(find.text('Similar movements for Bench Press'), findsOneWidget);
      expect(find.text('Dumbbell Bench Press'), findsOneWidget);
      expect(find.text('Weighted'), findsOneWidget);
      expect(find.text('Other exercise…'), findsOneWidget);

      await tester.tap(find.text('Dumbbell Bench Press'));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsNothing);
      expect(find.text('Dumbbell Bench Press'), findsOneWidget);
      expect(await _savedSetsForAsync(weightedVariation.id), [
        {'w': 0.0, 'r': 0, 'd': 0},
        {'w': 0.0, 'r': 0, 'd': 0},
      ]);

      await _openCircuitExerciseActions(tester, 'Plank');
      await tester.tap(find.text('Swap Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Side Plank'), findsOneWidget);
      expect(find.text('Timed'), findsOneWidget);
      expect(find.text('Other exercise…'), findsOneWidget);

      await tester.tap(find.text('Side Plank'));
      await tester.pumpAndSettle();
      expect(find.text('Plank'), findsNothing);
      expect(find.text('Side Plank'), findsOneWidget);
      expect(await _savedSetsForAsync(timedVariation.id), [
        {'w': 0.0, 'r': 0, 'd': 0},
        {'w': 0.0, 'r': 0, 'd': 0},
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'done circuit rounds expose edit affordances while the active round stays inline',
    (tester) async {
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit(
            'Edit Circuit',
            ['Barbell Row', 'Hollow Hold'],
            rounds: 2,
            timedExerciseNames: {'Hollow Hold'},
            repRangeMin: 30,
            repRangeMax: 30,
          );
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 1,
            circuitExIdx: 0,
            sets: {
              '${circuit.exercises[0].exercise.id}': [
                _setJson(weight: 80, reps: 5),
                _setJson(weight: 82.5, reps: 5),
              ],
              '${circuit.exercises[1].exercise.id}': [
                _setJson(duration: 30),
                _setJson(duration: 0),
              ],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );
      expect(find.byKey(const ValueKey('round-input-1')), findsOneWidget);
      expect(
        find.descendant(
          of: _circuitExerciseSection('Barbell Row'),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _circuitExerciseSection('Hollow Hold'),
          matching: find.byIcon(Icons.edit),
        ),
        findsOneWidget,
      );

      await tester.tap(_roundLabelInSection('Barbell Row', 2));
      await tester.pumpAndSettle();
      expect(find.text('Edit Round 2'), findsNothing);
      expect(find.byKey(const ValueKey('round-input-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logged circuit round saves update values and can trigger PR overlay',
    (tester) async {
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit(
            'Save Edit Circuit',
            ['Barbell Row', 'Hollow Hold'],
            rounds: 2,
            timedExerciseNames: {'Hollow Hold'},
            repRangeMin: 30,
            repRangeMax: 30,
          );
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 1,
            circuitExIdx: 0,
            sets: {
              '${circuit.exercises[0].exercise.id}': [
                _setJson(weight: 80, reps: 5),
                _setJson(weight: 82.5, reps: 5),
              ],
              '${circuit.exercises[1].exercise.id}': [
                _setJson(duration: 30),
                _setJson(duration: 0),
              ],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );

      await tester.tap(_roundLabelInSection('Barbell Row', 1));
      await tester.pumpAndSettle();
      expect(find.text('Edit Round 1'), findsOneWidget);
      await tester.enterText(_textFieldByLabel('Weight (kg)'), '90');
      await tester.enterText(_textFieldByLabel('Reps'), '6');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('NEW PR!'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('90 kg'), findsOneWidget);
      expect(
        _readOnlyValueInSection('Barbell Row', 'REPS', '6'),
        findsOneWidget,
      );

      await tester.tap(_roundLabelInSection('Hollow Hold', 1));
      await tester.pumpAndSettle();
      expect(find.text('Edit Round 1'), findsOneWidget);
      await tester.enterText(_textFieldByLabel('Duration (seconds)'), '45');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        _readOnlyValueInSection('Hollow Hold', 'DURATION', '0:45'),
        findsOneWidget,
      );
      expect(find.text('NEW PR!'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'circuit-level actions add after circuit, skip circuit, remove circuit, and omit swap',
    (tester) async {
      await _pumpActiveSession(
        tester,
        configure: (builder) async {
          final circuit = await builder.addCircuit('Action Circuit', [
            'Bear Crawl',
            'Jumping Jack',
          ], rounds: 1);
          await builder.addLibraryExercise('Battle Ropes', isTimed: true);
          return _SavedProgress(
            wodId: builder.wodId,
            itemIdx: 0,
            setIdx: 0,
            circuitExIdx: 0,
            sets: {
              for (final entry in circuit.exercises)
                '${entry.exercise.id}': [_setJson()],
            },
            items: [
              {'type': 'circuit', 'groupId': circuit.groupId, 'skipped': false},
            ],
          );
        },
      );

      await _openCircuitActions(tester, 'Action Circuit');
      expect(find.text('Add Exercise'), findsOneWidget);
      expect(find.text('Skip Circuit'), findsOneWidget);
      expect(find.text('Remove Circuit'), findsOneWidget);
      expect(find.text('Swap Exercise'), findsNothing);

      await tester.tap(find.text('Add Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Add Exercise'), findsOneWidget);
      await tester.tap(find.text('Battle Ropes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Workout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Just for this workout'));
      await tester.pumpAndSettle();

      expect(find.text('Battle Ropes'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Action Circuit')).dy,
        lessThan(tester.getTopLeft(find.text('Battle Ropes')).dy),
      );

      await _openCircuitActions(tester, 'Action Circuit');
      await tester.tap(find.text('Skip Circuit'));
      await tester.pumpAndSettle();
      await _openReview(tester);
      expect(find.text('2 of 3 exercises done'), findsOneWidget);
      expect(_statValue(tester, 'Skipped'), '2');
      await tester.tap(find.widgetWithText(TextButton, 'Keep logging'));
      await tester.pumpAndSettle();

      await _openCircuitActions(tester, 'Action Circuit');
      await tester.tap(find.text('Remove Circuit'));
      await tester.pumpAndSettle();

      expect(find.text('Action Circuit'), findsNothing);
      expect(find.text('Bear Crawl'), findsNothing);
      expect(find.text('Jumping Jack'), findsNothing);
      expect(find.text('Battle Ropes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_Harness> _pumpActiveSession(
  WidgetTester tester, {
  required Future<_SavedProgress> Function(_WorkoutBuilder builder) configure,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final builder = _WorkoutBuilder(db);
  await builder.seedBaseWorkout();
  final savedProgress = await configure(builder);
  SharedPreferences.setMockInitialValues({
    'workout_progress_${builder.wodId}': jsonEncode(savedProgress.toJson()),
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ActiveSessionScreen(result: builder.result(), autoResume: true),
      ),
    ),
  );
  await tester.pumpAndSettle();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });

  return _Harness(db);
}

Future<void> _openReview(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Finish'));
  await tester.pumpAndSettle();
}

Future<void> _tapReviewFinish(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
  await tester.pumpAndSettle();
}

Future<void> _finishOverlay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pumpAndSettle();
}

String _statValue(WidgetTester tester, String label) {
  final row = tester.widget<Row>(
    find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
  );
  final value = row.children.whereType<Text>().last.data;
  expect(value, isNotNull);
  return value!;
}

Future<int> _sessionCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS count FROM workout_sessions')
      .getSingle();
  return row.read<int>('count');
}

Future<int> _setCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS count FROM workout_sets')
      .getSingle();
  return row.read<int>('count');
}

Future<int> _setCountForExerciseName(
  AppDatabase db,
  String exerciseName,
) async {
  final row = await db
      .customSelect(
        '''
        SELECT COUNT(*) AS count
        FROM workout_sets ws
        JOIN exercises e ON e.id = ws.exercise_id
        WHERE e.name = ?
        ''',
        variables: [Variable.withString(exerciseName)],
      )
      .getSingle();
  return row.read<int>('count');
}

Future<void> _completeVisibleSet(WidgetTester tester) async {
  await tester.tapAt(tester.getCenter(find.byType(CheckCircleButton).last));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Finder _circuitCard(String circuitName) => find.ancestor(
  of: find.text(circuitName),
  matching: find.byType(CircuitCard),
);

Finder _circuitExerciseSection(String exerciseName) => find.ancestor(
  of: find.text(exerciseName),
  matching: find.byType(CircuitExerciseSection),
);

Finder _sectionHasNowBadge(String exerciseName) => find.descendant(
  of: _circuitExerciseSection(exerciseName),
  matching: find.text('▶ NOW'),
);

Finder _roundLabelInSection(String exerciseName, int roundNumber) =>
    find.descendant(
      of: _circuitExerciseSection(exerciseName),
      matching: find.text('Round $roundNumber'),
    );

Finder _readOnlyValueInSection(
  String exerciseName,
  String label,
  String value,
) => find.descendant(
  of: _circuitExerciseSection(exerciseName),
  matching: find.ancestor(
    of: find.text(value),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Column &&
          widget.children.any((child) => child is Text && child.data == label),
    ),
  ),
);

Finder _textFieldByLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _openCircuitActions(
  WidgetTester tester,
  String circuitName,
) async {
  await tester.tap(
    find
        .descendant(
          of: _circuitCard(circuitName),
          matching: find.byIcon(Icons.more_horiz),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openCircuitExerciseActions(
  WidgetTester tester,
  String exerciseName,
) async {
  await tester.tap(
    find.descendant(
      of: _circuitExerciseSection(exerciseName),
      matching: find.byIcon(Icons.more_horiz),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _removeCircuitExerciseByName(
  WidgetTester tester,
  String exerciseName,
) async {
  await _openCircuitExerciseActions(tester, exerciseName);
  final remove = find.text('Remove from Circuit');
  if (remove.evaluate().isNotEmpty) {
    await tester.tap(remove);
  } else {
    await tester.tap(find.text('Remove (last · removes circuit)'));
  }
  await tester.pumpAndSettle();
}

Future<List<Map<String, Object?>>> _savedSetsForAsync(int exerciseId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('workout_progress_100');
  expect(raw, isNotNull);
  final saved = jsonDecode(raw!) as Map<String, dynamic>;
  final sets = (saved['sets'] as Map<String, dynamic>)['$exerciseId'] as List;
  return sets
      .map((set) => Map<String, Object?>.from(set as Map))
      .toList(growable: false);
}

Map<String, Object> _setJson({
  double weight = 0,
  int reps = 0,
  int duration = 0,
}) => {'w': weight, 'r': reps, 'd': duration};

Map<String, Object?> _standaloneItemJson(
  WodExerciseEntry entry, {
  bool skipped = false,
  List<int> skippedSets = const [],
}) => {
  'type': 'standalone',
  'exerciseId': entry.templateExercise.exerciseId,
  'isAdHoc': false,
  'skipped': skipped,
  'skippedSets': skippedSets,
};

class _Harness {
  final AppDatabase db;

  _Harness(this.db);
}

class _SavedProgress {
  final int wodId;
  final int itemIdx;
  final int setIdx;
  final int circuitExIdx;
  final Map<String, List<Map<String, Object>>> sets;
  final List<Map<String, Object?>> items;

  _SavedProgress({
    required this.wodId,
    required this.itemIdx,
    required this.setIdx,
    required this.circuitExIdx,
    required this.sets,
    required this.items,
  });

  factory _SavedProgress.completeStandalone({
    required int wodId,
    required List<int> exerciseIds,
    required Map<int, List<Map<String, Object>>> loggedSetsByExercise,
    required int currentSetIdx,
  }) {
    return _SavedProgress(
      wodId: wodId,
      itemIdx: 0,
      setIdx: currentSetIdx,
      circuitExIdx: 0,
      sets: {for (final id in exerciseIds) '$id': loggedSetsByExercise[id]!},
      items: [
        for (final id in exerciseIds)
          {
            'type': 'standalone',
            'exerciseId': id,
            'isAdHoc': false,
            'skipped': false,
            'skippedSets': <int>[],
          },
      ],
    );
  }

  Map<String, Object?> toJson() => {
    'itemIdx': itemIdx,
    'setIdx': setIdx,
    'circuitExIdx': circuitExIdx,
    'sets': sets,
    'items': items,
    'savedAt': DateTime(2026, 9, 4, 12).millisecondsSinceEpoch,
  };
}

class _WorkoutBuilder {
  final AppDatabase db;
  final int programId = 1;
  final int phaseId = 10;
  final int wodId = 100;

  int _nextExerciseId = 1;
  int _nextTemplateExerciseId = 1000;
  int _nextGroupId = 2000;
  final List<WodItem> _items = [];

  _WorkoutBuilder(this.db);

  Future<void> seedBaseWorkout() async {
    await db.customSelect('SELECT 1').get();
    await db
        .into(db.programs)
        .insert(
          ProgramsCompanion.insert(
            id: Value(programId),
            name: 'QA Program',
            status: const Value(0),
          ),
        );
    await db
        .into(db.programPhases)
        .insert(
          ProgramPhasesCompanion.insert(
            id: Value(phaseId),
            programId: programId,
            phaseNumber: 1,
            name: 'Base',
            durationWeeks: 4,
          ),
        );
    await db
        .into(db.wodTemplates)
        .insert(
          WodTemplatesCompanion.insert(
            id: Value(wodId),
            phaseId: phaseId,
            wodNumber: 1,
            name: 'QA Workout',
            restSeconds: const Value(0),
          ),
        );
  }

  Future<WodExerciseEntry> addStandalone(
    String name, {
    int sets = 1,
    int repRangeMin = 6,
    int repRangeMax = 10,
    bool isTimed = false,
  }) async {
    final entry = await _addExercise(
      name,
      sortOrder: _items.length,
      sets: sets,
      repRangeMin: repRangeMin,
      repRangeMax: repRangeMax,
      isTimed: isTimed,
    );
    _items.add(StandaloneWodExercise(entry: entry, restSeconds: 0));
    return entry;
  }

  Future<WodCircuit> addCircuit(
    String name,
    List<String> exerciseNames, {
    required int rounds,
    int repRangeMin = 6,
    int repRangeMax = 10,
    Set<String> timedExerciseNames = const {},
  }) async {
    final groupId = _nextGroupId++;
    await db
        .into(db.wodExerciseGroups)
        .insert(
          WodExerciseGroupsCompanion.insert(
            id: Value(groupId),
            wodTemplateId: wodId,
            sortOrder: _items.length,
            name: Value(name),
            rounds: Value(rounds),
            restBetweenExercisesSeconds: const Value(0),
            restBetweenRoundsSeconds: const Value(0),
          ),
        );
    final entries = <WodExerciseEntry>[];
    for (int i = 0; i < exerciseNames.length; i++) {
      entries.add(
        await _addExercise(
          exerciseNames[i],
          sortOrder: i,
          sets: 1,
          repRangeMin: repRangeMin,
          repRangeMax: repRangeMax,
          groupId: groupId,
          isTimed: timedExerciseNames.contains(exerciseNames[i]),
        ),
      );
    }
    final circuit = WodCircuit(
      groupId: groupId,
      name: name,
      rounds: rounds,
      restBetweenExercisesSeconds: 0,
      restBetweenRoundsSeconds: 0,
      exercises: entries,
    );
    _items.add(circuit);
    return circuit;
  }

  Future<WodExerciseEntry> _addExercise(
    String name, {
    required int sortOrder,
    required int sets,
    required int repRangeMin,
    required int repRangeMax,
    int? groupId,
    bool isTimed = false,
  }) async {
    final exerciseId = _nextExerciseId++;
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: Value(exerciseId),
            name: name,
            category: const Value('Strength'),
            isTimed: Value(isTimed),
          ),
        );
    final templateExerciseId = _nextTemplateExerciseId++;
    await db
        .into(db.wodTemplateExercises)
        .insert(
          WodTemplateExercisesCompanion.insert(
            id: Value(templateExerciseId),
            wodTemplateId: wodId,
            exerciseId: exerciseId,
            sortOrder: sortOrder,
            groupId: Value(groupId),
            targetSets: Value(sets),
            repRangeMin: Value(repRangeMin),
            repRangeMax: Value(repRangeMax),
            restSeconds: const Value(0),
            restBetweenSetsSeconds: const Value(0),
          ),
        );
    return WodExerciseEntry(
      templateExercise: WodTemplateExercise(
        id: templateExerciseId,
        wodTemplateId: wodId,
        exerciseId: exerciseId,
        sortOrder: sortOrder,
        groupId: groupId,
        targetSets: sets,
        repRangeMin: repRangeMin,
        repRangeMax: repRangeMax,
        restSeconds: 0,
        restBetweenSetsSeconds: 0,
      ),
      exercise: Exercise(
        id: exerciseId,
        name: name,
        category: 'Strength',
        isTimed: isTimed,
        muscleNeedsReview: false,
        muscleReviewNote: null,
      ),
      suggestion: WeightSuggestion.noHistory,
    );
  }

  Future<Exercise> addLibraryExercise(
    String name, {
    bool isTimed = false,
    String category = 'Strength',
  }) async {
    final exerciseId = _nextExerciseId++;
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: Value(exerciseId),
            name: name,
            category: Value(category),
            isTimed: Value(isTimed),
          ),
        );
    return Exercise(
      id: exerciseId,
      name: name,
      category: category,
      isTimed: isTimed,
      muscleNeedsReview: false,
      muscleReviewNote: null,
    );
  }

  Future<void> addVariation(int exerciseId, int variationExerciseId) =>
      db.exerciseVariationsDao.addVariation(exerciseId, variationExerciseId);

  NextWodResult result() => NextWodResult(
    program: const Program(id: 1, name: 'QA Program', status: 0),
    phase: const ProgramPhase(
      id: 10,
      programId: 1,
      phaseNumber: 1,
      name: 'Base',
      durationWeeks: 4,
    ),
    phaseIndex: 1,
    totalPhases: 1,
    wodTemplate: const WodTemplate(
      id: 100,
      phaseId: 10,
      wodNumber: 1,
      name: 'QA Workout',
      restSeconds: 0,
    ),
    weekNumberInProgram: 1,
    totalProgramWeeks: 4,
    items: List.unmodifiable(_items),
  );
}

class _FakeFlutterLocalNotificationsPlatform
    extends FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancel(int id) async {}
}
