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

  /// Shows the coaching note as a small popover that grows out of the (i) icon
  /// ([anchorKey]). Swipe it up or sideways (it shrinks back into the icon),
  /// or tap outside, to close. Swiping down does nothing.
  static void showCoachingNotes(
      BuildContext context, WodExerciseEntry entry, WodTemplateExercise te,
      {GlobalKey? anchorKey}) {
    final screen = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final rect = _rectOf(anchorKey);
    final anchor = rect?.center ?? Offset(screen.width / 2, topInset + 56);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close coaching note',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 220),
      // The popover animates itself (scale from the icon), so no default fade.
      transitionBuilder: (ctx, anim, _, child) => child,
      pageBuilder: (ctx, anim, _) => _CoachingNotePopover(
        animation: anim,
        anchor: anchor,
        anchorBottom: rect?.bottom ?? anchor.dy + 16,
        note: te.notes!,
        onClose: () => Navigator.of(ctx).pop(),
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
                      icon: const Icon(Icons.info_outline_rounded, size: 19),
                      onPressed: () => showCoachingNotes(context, entry, te, anchorKey: infoIconKey),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFFFBBF24),
                        backgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.14),
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
              SuggestionBadge(suggestion: entry.suggestion),
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


/// Small note-only popover that scales out of / back into the (i) icon.
class _CoachingNotePopover extends StatefulWidget {
  final Animation<double> animation;
  final Offset anchor; // centre of the (i) icon, in screen coordinates
  final double anchorBottom;
  final String note;
  final VoidCallback onClose;

  const _CoachingNotePopover({
    required this.animation,
    required this.anchor,
    required this.anchorBottom,
    required this.note,
    required this.onClose,
  });

  @override
  State<_CoachingNotePopover> createState() => _CoachingNotePopoverState();
}

class _CoachingNotePopoverState extends State<_CoachingNotePopover> {
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: widget.animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Offset _drag = Offset.zero;

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    // Up or sideways dismisses; downward movement is ignored.
    final dismiss = _drag.dy < -40 || _drag.dx.abs() > 60 || v.dy < -400 || v.dx.abs() > 600;
    if (dismiss) {
      widget.onClose();
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width - 32 < 280.0 ? screen.width - 32 : 280.0;
    final left = (widget.anchor.dx - width / 2).clamp(16.0, screen.width - 16 - width);
    final top = widget.anchorBottom + 8;
    final caretX = (widget.anchor.dx - left - 6).clamp(14.0, width - 26);

    const gold = Color(0xFFFBBF24);
    const surfaceTop = Color(0xFF332811);
    const surfaceBottom = Color(0xFF1F190C);
    const noteTextColor = Color(0xFFFEF3C7);

    final card = Container(
      constraints: BoxConstraints(maxHeight: screen.height * 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [surfaceTop, surfaceBottom],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gold.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1, right: 8),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: gold,
              ),
            ),
            Expanded(
              child: Text(
                widget.note,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: noteTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: AnimatedBuilder(
            animation: _curved,
            builder: (context, child) {
              final t = _curved.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: t,
                // Scale about the icon's centre so it grows out of / shrinks
                // back into the (i).
                child: Transform.scale(
                  scale: 0.02 + 0.98 * t,
                  origin: Offset(widget.anchor.dx - left, widget.anchor.dy - top),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(() {
                _drag = Offset(_drag.dx + d.delta.dx, (_drag.dy + d.delta.dy).clamp(double.negativeInfinity, 0.0));
              }),
              onPanEnd: _onPanEnd,
              child: Transform.translate(
                offset: _drag,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    top: -5,
                    left: caretX,
                    child: Transform.rotate(
                      angle: 0.785398,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: surfaceTop,
                          border: Border(
                            top: BorderSide(
                              color: gold.withValues(alpha: 0.65),
                              width: 1.5,
                            ),
                            left: BorderSide(
                              color: gold.withValues(alpha: 0.65),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  card,
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
