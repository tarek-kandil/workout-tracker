import 'package:flutter/material.dart';
import '../../../database/app_database.dart';
import '../../../models/next_wod_result.dart';
import '../../../models/wod_item.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';
import 'session_common.dart';
import 'history_chip_row.dart';
import 'set_row.dart';
import 'check_circle_button.dart';

class RoundRowItem extends StatelessWidget {
  final int roundIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final SetData data;
  final void Function(SetData)? onChanged;

  const RoundRowItem({super.key, 
    required this.roundIndex, required this.isTimed,
    required this.isActive, required this.isDone,
    required this.data, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 54, child: Text('Round ${roundIndex + 1}', style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          color: isActive ? teal : Colors.white.withValues(alpha: isDone ? 0.4 : 0.2),
        ))),
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13, color: isDone ? teal : isActive ? accent : Colors.white24),
        const SizedBox(width: 8),
        if (isActive && onChanged != null)
          Expanded(child: SetRow(
            key: ValueKey('round-input-$roundIndex'),
            setNumber: roundIndex + 1, isTimed: isTimed,
            data: data, onChanged: onChanged!,
          ))
        else ...[
          if (!isTimed) ...[
            Expanded(child: ReadOnlyField(label: 'WEIGHT',
                value: data.weightKg > 0 ? '${fmtW(data.weightKg)} kg' : '—', dim: !isDone)),
            const SizedBox(width: 6),
          ],
          Expanded(child: ReadOnlyField(
            label: isTimed ? 'DURATION' : 'REPS',
            value: isTimed ? (data.durationSeconds > 0 ? fmtSec(data.durationSeconds) : '—')
                           : (data.reps > 0 ? '${data.reps}' : '—'),
            dim: !isDone,
          )),
        ],
      ]),
    );
  }
}

class CircuitExerciseSection extends StatelessWidget {
  final WodExerciseEntry exercise;
  final int rounds;
  final bool isCurrentExercise;
  final int currentRound;
  final List<SetData> setData;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;

  const CircuitExerciseSection({super.key, 
    required this.exercise, required this.rounds,
    required this.isCurrentExercise, required this.currentRound,
    required this.setData, required this.lastSets,
    required this.prKg, required this.prDurationSeconds,
    required this.historyExpanded, required this.onToggleHistory,
    required this.onSetDataChanged, required this.onDoneSet,
    required this.onStartTimer, required this.onStopTimer,
    required this.onShowActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
  });

  @override
  Widget build(BuildContext context) {
    final te = exercise.templateExercise;
    final isTimed = exercise.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isCurrentExercise) StatusBadge(label: '▶ NOW', color: accent),
            Text(exercise.exercise.name,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Text(
              isTimed ? fmtSec(te.repRangeMin) : '${te.repRangeMax} reps',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ])),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 18),
            onPressed: onShowActions,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
          ),
        ]),
        const SizedBox(height: 6),
        HistoryChipRow(
          lastSets: lastSets, isTimed: isTimed,
          prKg: prKg, prDurationSeconds: prDurationSeconds,
          expanded: historyExpanded, onToggle: onToggleHistory,
        ),
        const SizedBox(height: 8),
        for (int r = 0; r < rounds; r++)
          RoundRowItem(
            roundIndex: r, isTimed: isTimed,
            isActive: isCurrentExercise && r == currentRound,
            isDone: r < currentRound || (!isCurrentExercise && r < setData.length &&
                (isTimed ? setData[r].durationSeconds > 0 : setData[r].reps > 0)),
            data: r < setData.length ? setData[r] : SetData(weightKg: 0, reps: 0),
            onChanged: isCurrentExercise && r == currentRound ? (d) => onSetDataChanged(r, d) : null,
          ),
        if (isCurrentExercise && onDoneSet != null) ...[
          const SizedBox(height: 10),
          if (isTimed)
            TimedSetInput(
              running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
              target: te.repRangeMin, isCircuit: true,
              onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
            )
          else
            Center(child: CheckCircleButton(
              key: ValueKey('circ-check-${te.exerciseId}-$currentRound'),
              onDone: onDoneSet!,
            )),
        ],
      ]),
    );
  }
}

class CircuitCard extends StatelessWidget {
  final WodCircuit circuit;
  final CardState cardState;
  final int itemIndex;
  final int currentItemIdx;
  final int currentSetIdx;
  final int currentCircuitExIdx;
  final Map<int, List<SetData>> setData;
  final Map<int, List<WorkoutSet>> lastSets;
  final Map<int, double?> prData;
  final Map<int, int?> prDurationData;
  final Map<int, bool> historyExpanded;
  final void Function(int) onToggleHistory;
  final void Function(int, int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowCircuitActions;
  final void Function(int) onShowExerciseActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final int? dragIndex;

  const CircuitCard({super.key, 
    required this.circuit, required this.cardState, required this.itemIndex,
    required this.currentItemIdx, required this.currentSetIdx,
    required this.currentCircuitExIdx, required this.setData, required this.lastSets,
    required this.prData, required this.prDurationData, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onShowCircuitActions, required this.onShowExerciseActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;
    final isActive = cardState == CardState.active && itemIndex == currentItemIdx;
    final isDone = cardState == CardState.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: isDone ? 0.04 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? teal.withValues(alpha: 0.55) : isDone ? Colors.green.withValues(alpha: 0.25) : teal.withValues(alpha: 0.18),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [BoxShadow(color: teal.withValues(alpha: 0.12), blurRadius: 12)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Circuit header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            Icon(Icons.loop, size: 14, color: teal),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                circuit.name != null && circuit.name!.isNotEmpty ? circuit.name! : 'Circuit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: teal),
              ),
              Text(
                '${circuit.rounds} rounds · ${circuit.restBetweenRoundsSeconds}s rest between rounds',
                style: TextStyle(fontSize: 9, color: teal.withValues(alpha: 0.6)),
              ),
            ])),
            if (isDone) const StatusBadge(label: '✓ DONE', color: Colors.green),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.drag_handle, size: 20, color: Colors.white24),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 18),
              onPressed: onShowCircuitActions,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
            ),
          ]),
        ),
        Divider(height: 1, color: teal.withValues(alpha: 0.08)),
        for (int exIdx = 0; exIdx < circuit.exercises.length; exIdx++) ...[
          CircuitExerciseSection(
            exercise: circuit.exercises[exIdx],
            rounds: circuit.rounds,
            isCurrentExercise: isActive && exIdx == currentCircuitExIdx,
            currentRound: isActive ? currentSetIdx : -1,
            setData: setData[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
            lastSets: lastSets[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
            prKg: prData[circuit.exercises[exIdx].templateExercise.exerciseId],
            prDurationSeconds: prDurationData[circuit.exercises[exIdx].templateExercise.exerciseId],
            historyExpanded: historyExpanded[circuit.exercises[exIdx].templateExercise.exerciseId] ?? false,
            onToggleHistory: () => onToggleHistory(circuit.exercises[exIdx].templateExercise.exerciseId),
            onSetDataChanged: (r, d) => onSetDataChanged(circuit.exercises[exIdx].templateExercise.exerciseId, r, d),
            onDoneSet: isActive && exIdx == currentCircuitExIdx ? onDoneSet : null,
            onStartTimer: isActive && exIdx == currentCircuitExIdx ? onStartTimer : null,
            onStopTimer: isActive && exIdx == currentCircuitExIdx ? onStopTimer : null,
            onShowActions: () => onShowExerciseActions(exIdx),
            timedRunning: isActive && exIdx == currentCircuitExIdx ? timedRunning : false,
            timedElapsed: isActive && exIdx == currentCircuitExIdx ? timedElapsed : 0,
            timedStopped: isActive && exIdx == currentCircuitExIdx ? timedStopped : false,
          ),
          if (exIdx < circuit.exercises.length - 1)
            const Divider(height: 1, color: Color(0x08FFFFFF)),
        ],
        const SizedBox(height: 6),
      ]),
    );
  }
}
