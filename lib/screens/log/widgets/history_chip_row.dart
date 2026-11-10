import 'package:flutter/material.dart';
import '../../../database/app_database.dart';
import '../../../utils/rir_conversion.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';

class HistoryChipRow extends StatefulWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final double? prKg;
  final int? prDurationSeconds;
  final bool expanded;
  final VoidCallback onToggle;

  /// Optional named histories (e.g. the variation being done + the exercise it
  /// replaced). When any has sets, they replace [lastSets] in the panel; with
  /// two, a small switch lets the user flip between them.
  final List<ExerciseHistory> tabs;

  const HistoryChipRow({super.key,
    required this.lastSets, required this.isTimed,
    required this.prKg, required this.prDurationSeconds,
    required this.expanded, required this.onToggle,
    this.tabs = const [],
  });

  @override
  State<HistoryChipRow> createState() => _HistoryChipRowState();
}

class _HistoryChipRowState extends State<HistoryChipRow> {
  int _tab = 0;

  List<ExerciseHistory> get _tabs => widget.tabs.where((t) => t.sets.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final hasHistory = tabs.isNotEmpty || widget.lastSets.isNotEmpty;
    final prStr = widget.isTimed
        ? (widget.prDurationSeconds != null && widget.prDurationSeconds! > 0 ? fmtSec(widget.prDurationSeconds!) : null)
        : (widget.prKg != null && widget.prKg! > 0 ? '${fmtW(widget.prKg!)} kg' : null);

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
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Last', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(widget.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 13, color: Colors.white38),
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
                child: Text('${tabs[0].name} · ${fmtShortDate(tabs[0].date)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w600)),
              ),
            _SetsTable(
              sets: tabs.isNotEmpty ? tabs[tabIdx].sets : widget.lastSets,
              isTimed: widget.isTimed,
            ),
          ]),
        ),
      ],
    ]);
  }
}

/// Compact two-way switch: "Variation · 12 Oct" | "Original · 5 Oct".
class _HistorySwitch extends StatelessWidget {
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
                  color: i == selected ? accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: i == selected ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  '${tabs[i].name} · ${fmtShortDate(tabs[i].date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: i == selected ? Colors.white : Colors.white54,
                  ),
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
  final bool isTimed;
  const _SetsTable({required this.sets, required this.isTimed});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (int i = 0; i < sets.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 46, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38))),
            if (!isTimed)
              Expanded(child: Text('${fmtW(sets[i].weightKg)} kg',
                  style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600))),
            Expanded(child: Text(
              isTimed ? fmtSec(sets[i].durationSeconds ?? 0) : '× ${sets[i].reps} reps',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            )),
            if (effectiveRir(sets[i].rir, sets[i].rpe) != null)
              RirPill(rir: effectiveRir(sets[i].rir, sets[i].rpe)!),
          ]),
        ),
    ]);
  }
}
