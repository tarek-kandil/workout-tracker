import 'package:flutter/material.dart';
import '../../../database/app_database.dart';
import '../../../models/exercise_tracking_mode.dart';
import '../../../utils/rir_conversion.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';

class HistoryChipRow extends StatefulWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final ExerciseTrackingMode trackingMode;
  final double? prKg;
  final int? prDurationSeconds;
  final bool expanded;
  final VoidCallback onToggle;

  /// Optional named histories (e.g. the card's exercise + its most recently
  /// performed variation). When any has sets, they replace [lastSets] in the
  /// panel; with two, a compact switch lets the user flip between them while
  /// subtly highlighting whichever variation was performed last time.
  final List<ExerciseHistory> tabs;

  const HistoryChipRow({super.key,
    required this.lastSets,
    this.isTimed = false,
    ExerciseTrackingMode? trackingMode,
    required this.prKg, required this.prDurationSeconds,
    required this.expanded, required this.onToggle,
    this.tabs = const [],
  }) : trackingMode = trackingMode ??
            (isTimed
                ? ExerciseTrackingMode.timed
                : ExerciseTrackingMode.weightedReps);

  @override
  State<HistoryChipRow> createState() => _HistoryChipRowState();
}

class _HistoryChipRowState extends State<HistoryChipRow> {
  static const _lastDoneHighlight = Color(0xFF34D399);

  int _tab = 0;

  List<ExerciseHistory> get _tabs =>
      widget.tabs.where((t) => t.sets.isNotEmpty).toList();

  @override
  void didUpdateWidget(covariant HistoryChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNames = oldWidget.tabs.map((t) => t.name).join('|');
    final newNames = widget.tabs.map((t) => t.name).join('|');
    if (oldNames != newNames) {
      _tab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final hasHistory = tabs.isNotEmpty || widget.lastSets.isNotEmpty;
    final lastWasVariation =
        tabs.isNotEmpty && tabs.first.isLastDone && tabs.first.isVariation;

    final String? prStr;
    switch (widget.trackingMode) {
      case ExerciseTrackingMode.timed:
        prStr = (widget.prDurationSeconds != null &&
                widget.prDurationSeconds! > 0)
            ? fmtSec(widget.prDurationSeconds!)
            : null;
      case ExerciseTrackingMode.bodyweightReps:
        final bestReps = widget.lastSets.fold<int>(
            0, (m, s) => s.reps > m ? s.reps : m);
        prStr = bestReps > 0 ? '$bestReps reps' : null;
      case ExerciseTrackingMode.weightedReps:
        prStr = (widget.prKg != null && widget.prKg! > 0)
            ? '${fmtW(widget.prKg!)} kg'
            : null;
    }

    if (!hasHistory && prStr == null) return const SizedBox.shrink();

    final tabIdx = _tab.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (hasHistory)
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: lastWasVariation
                    ? _lastDoneHighlight.withValues(alpha: 0.09)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lastWasVariation
                      ? _lastDoneHighlight.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (lastWasVariation) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: _lastDoneHighlight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  'Last',
                  style: TextStyle(
                    fontSize: 11,
                    color: lastWasVariation
                        ? Colors.white.withValues(alpha: 0.85)
                        : Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  widget.expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 13,
                  color: Colors.white38,
                ),
              ]),
            ),
          ),
        if (hasHistory && prStr != null) const SizedBox(width: 8),
        if (prStr != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Text('PR $prStr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber)),
          ),
      ]),
      if (widget.expanded && hasHistory) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (tabs.length > 1)
              _HistorySwitch(
                tabs: tabs,
                selected: tabIdx,
                onSelect: (i) => setState(() => _tab = i),
              )
            else if (tabs.length == 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tabs[0].isLastDone && tabs[0].isVariation) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _lastDoneHighlight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        '${tabs[0].name} · ${fmtShortDate(tabs[0].date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: (tabs[0].isLastDone && tabs[0].isVariation)
                              ? Colors.white70
                              : Colors.white38,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (tabs[0].isLastDone && tabs[0].isVariation) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _lastDoneHighlight.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LAST',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: _lastDoneHighlight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            _SetsTable(
              sets: tabs.isNotEmpty ? tabs[tabIdx].sets : widget.lastSets,
              trackingMode:
                  tabs.isNotEmpty ? tabs[tabIdx].trackingMode : widget.trackingMode,
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Compact two-way switch: "Variant B · 25 Nov [LAST]" | "Ex A · 18 Nov".
class _HistorySwitch extends StatelessWidget {
  static const _lastDoneHighlight = Color(0xFF34D399);

  final List<ExerciseHistory> tabs;
  final int selected;
  final ValueChanged<int> onSelect;
  const _HistorySwitch({required this.tabs, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        for (int i = 0; i < tabs.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: i == selected
                      ? accent.withValues(alpha: 0.18)
                      : (tabs[i].isLastDone
                          ? _lastDoneHighlight.withValues(alpha: 0.06)
                          : Colors.white.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == selected
                        ? accent.withValues(alpha: 0.5)
                        : (tabs[i].isLastDone
                            ? _lastDoneHighlight.withValues(alpha: 0.26)
                            : Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (tabs[i].isLastDone) ...[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: _lastDoneHighlight,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        '${tabs[i].name} · ${fmtShortDate(tabs[i].date)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              i == selected ? FontWeight.w700 : FontWeight.w600,
                          color: i == selected
                              ? Colors.white
                              : (tabs[i].isLastDone
                                  ? Colors.white.withValues(alpha: 0.80)
                                  : Colors.white54),
                        ),
                      ),
                    ),
                    if (tabs[i].isLastDone) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _lastDoneHighlight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LAST',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: _lastDoneHighlight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _SetsTable extends StatelessWidget {
  final List<WorkoutSet> sets;
  final ExerciseTrackingMode trackingMode;
  const _SetsTable({required this.sets, required this.trackingMode});

  @override
  Widget build(BuildContext context) {
    final isTimed = trackingMode == ExerciseTrackingMode.timed;
    final showWeight = trackingMode == ExerciseTrackingMode.weightedReps;
    return Column(children: [
      for (int i = 0; i < sets.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 46, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38))),
            if (showWeight)
              Expanded(child: Text('${fmtW(sets[i].weightKg)} kg',
                  style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600))),
            Expanded(child: Text(
              isTimed ? fmtSec(sets[i].durationSeconds ?? 0) : '${showWeight ? '× ' : ''}${sets[i].reps} reps',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            )),
            if (effectiveRir(sets[i].rir, sets[i].rpe) != null)
              RirPill(rir: effectiveRir(sets[i].rir, sets[i].rpe)!),
          ]),
        ),
    ]);
  }
}
