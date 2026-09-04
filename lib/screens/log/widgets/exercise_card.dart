import 'package:flutter/material.dart';
import '../../../database/app_database.dart';
import '../../../models/next_wod_result.dart';
import '../../../utils/rir_conversion.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';
import 'session_common.dart';
import 'history_chip_row.dart';
import 'set_row.dart';
import 'check_circle_button.dart';

class ExerciseCard extends StatelessWidget {
  final WodExerciseEntry entry;
  final CardState cardState;
  final int itemIndex;
  final int? dragIndex;
  final List<SetData> setData;
  final int currentSetIdx;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final Set<int> skippedSets;
  final bool isAdHoc;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final void Function(int) onSkipSet;
  final void Function(int) onEditSet;
  final VoidCallback onShowActions;

  const ExerciseCard({super.key, 
    required this.entry, required this.cardState, required this.itemIndex,
    this.dragIndex,
    required this.setData, required this.currentSetIdx, required this.lastSets,
    required this.prKg, required this.prDurationSeconds, required this.skippedSets,
    required this.isAdHoc, required this.timedRunning, required this.timedElapsed,
    required this.timedStopped, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onSkipSet, required this.onEditSet, required this.onShowActions,
  });

  static void _showCoachingNotes(
      BuildContext context, WodExerciseEntry entry, WodTemplateExercise te) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1e2030),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(entry.exercise.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            const Text('Coaching Notes',
                style: TextStyle(fontSize: 10, color: Colors.white38)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                te.notes!,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5),
              ),
            ),
            if (effectiveRir(te.targetRir, te.targetRpe) != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target RIR',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text(
                    fmtRir(effectiveRir(te.targetRir, te.targetRpe)!),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: rirColor(effectiveRir(te.targetRir, te.targetRpe)!)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    final isTimed = entry.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;
    final isActive = cardState == CardState.active;
    final isDone = cardState == CardState.completed;

    final borderColor = isActive
        ? accent.withValues(alpha: 0.6)
        : isDone ? Colors.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08);
    final bgColor = isActive
        ? accent.withValues(alpha: 0.09)
        : isDone ? Colors.green.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
        boxShadow: isActive ? [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: 1)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isActive) StatusBadge(label: '▶ NOW', color: accent)
              else if (isDone) const StatusBadge(label: '✓ DONE', color: Colors.green)
              else if (isAdHoc) const StatusBadge(label: '＋ added', color: Colors.orange),
              Text(entry.exercise.name,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                isTimed ? '${te.targetSets} sets · ${fmtSec(te.repRangeMin)}'
                        : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (te.notes != null && te.notes!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      onPressed: () => _showCoachingNotes(context, entry, te),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.white38,
                      ),
                    ),
                  if (dragIndex != null)
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Icon(Icons.drag_handle, size: 20, color: Colors.white24),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: onShowActions,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white38,
                    ),
                  ),
                ],
              ),
              if (!isTimed) SuggestionBadge(suggestion: entry.suggestion),
            ]),
          ]),
          const SizedBox(height: 8),
          // History chip
          HistoryChipRow(
            lastSets: lastSets, isTimed: isTimed,
            prKg: prKg, prDurationSeconds: prDurationSeconds,
            expanded: historyExpanded, onToggle: onToggleHistory,
          ),
          const SizedBox(height: 10),
          if (isActive && effectiveRir(te.targetRir, te.targetRpe) != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set ${currentSetIdx + 1} / ${te.targetSets}',
                  style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3)),
                ),
                RirPill(
                  rir: effectiveRir(te.targetRir, te.targetRpe)!,
                  isTarget: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Set rows
          ...List.generate(te.targetSets, (setIdx) {
            final isSetActive = isActive && setIdx == currentSetIdx;
            final isSetDone = (isActive && setIdx < currentSetIdx) ||
                (isDone && !skippedSets.contains(setIdx));
            final isSetSkipped = skippedSets.contains(setIdx);
            return SetRowItem(
              key: ValueKey('set-${te.exerciseId}-$itemIndex-$setIdx'),
              setIndex: setIdx, isTimed: isTimed,
              isActive: isSetActive, isDone: isSetDone, isSkipped: isSetSkipped,
              canSkip: !isSetActive && !isSetDone && !isSetSkipped && isActive,
              data: setIdx < setData.length ? setData[setIdx] : SetData(weightKg: 0, reps: 0),
              onChanged: isSetActive ? (data) => onSetDataChanged(setIdx, data) : null,
              onSkip: () => onSkipSet(setIdx),
              onEdit: isSetDone ? () => onEditSet(setIdx) : null,
            );
          }),
          // Done button / timer
          if (isActive && onDoneSet != null) ...[
            const SizedBox(height: 12),
            if (isTimed)
              TimedSetInput(
                running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
                target: te.repRangeMin, isCircuit: false,
                onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
              )
            else
              Center(child: CheckCircleButton(
                key: ValueKey('check-${entry.exercise.id}-$currentSetIdx'),
                onDone: onDoneSet!,
              )),
          ],
        ]),
      ),
    );
  }
}
