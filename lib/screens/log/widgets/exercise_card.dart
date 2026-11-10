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
  /// Variation + original histories when this exercise was swapped in.
  final List<ExerciseHistory> historyTabs;
  /// Key on the (i) icon so the notes popover can grow out of it.
  final GlobalKey? infoIconKey;

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
    this.historyTabs = const [],
    this.infoIconKey,
  });

  /// Screen-space rect of the widget behind [key], or null if not laid out.
  static Rect? _rectOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Shows the coaching notes as a popover that grows out of the (i) icon
  /// ([anchorKey]); swipe it away, tap outside, or press "Got it" to close.
  static void showCoachingNotes(
      BuildContext context, WodExerciseEntry entry, WodTemplateExercise te,
      {GlobalKey? anchorKey}) {
    final screen = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final rect = _rectOf(anchorKey);
    final anchorX = (rect?.center.dx ?? screen.width / 2).clamp(40.0, screen.width - 40);
    final top = ((rect?.bottom ?? topInset + 56) + 8)
        .clamp(topInset + 8, screen.height * 0.55);
    const hPad = 16.0;
    final alignX = (((anchorX - hPad) / (screen.width - 2 * hPad)) * 2 - 1).clamp(-1.0, 1.0);

    showGeneralDialog(
      context: context,
      barrierDismissible: true, // tap outside to close
      barrierLabel: 'Close coaching notes',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          // Grow from the icon: scale origin = icon's x, top edge of the card.
          child: ScaleTransition(alignment: Alignment(alignX, -1), scale: Tween(begin: 0.4, end: 1.0).animate(curved), child: child),
        );
      },
      pageBuilder: (sheetCtx, _, _) => Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned(
            top: top,
            left: hPad,
            right: hPad,
            child: Stack(clipBehavior: Clip.none, children: [
              // Caret pointing at the icon.
              Positioned(
                top: -6,
                left: anchorX - hPad - 6,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(width: 12, height: 12, color: const Color(0xFF1e2030)),
                ),
              ),
              // Swipe up/down to dismiss.
              Dismissible(
                key: const ValueKey('coaching-notes-popover'),
                direction: DismissDirection.vertical,
                onDismissed: (_) => Navigator.of(sheetCtx).pop(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: screen.height * 0.6),
                  child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1e2030),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        )),
      ),
                ),
              ),
            ]),
          ),
        ]),
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
                      key: infoIconKey,
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      onPressed: () => showCoachingNotes(context, entry, te, anchorKey: infoIconKey),
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
            tabs: historyTabs,
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
