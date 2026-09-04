import 'package:flutter/material.dart';
import '../../../database/app_database.dart';
import '../../../utils/rir_conversion.dart';
import '../session_formatters.dart';

class HistoryChipRow extends StatelessWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final double? prKg;
  final int? prDurationSeconds;
  final bool expanded;
  final VoidCallback onToggle;

  const HistoryChipRow({super.key, 
    required this.lastSets, required this.isTimed,
    required this.prKg, required this.prDurationSeconds,
    required this.expanded, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasHistory = lastSets.isNotEmpty;
    final prStr = isTimed
        ? (prDurationSeconds != null && prDurationSeconds! > 0 ? fmtSec(prDurationSeconds!) : null)
        : (prKg != null && prKg! > 0 ? '${fmtW(prKg!)} kg' : null);

    if (!hasHistory && prStr == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (hasHistory)
          GestureDetector(
            onTap: onToggle,
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
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 13, color: Colors.white38),
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
      if (expanded && hasHistory) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (int i = 0; i < lastSets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 46, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38))),
                  if (!isTimed)
                    Expanded(child: Text('${fmtW(lastSets[i].weightKg)} kg',
                        style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(
                    isTimed ? fmtSec(lastSets[i].durationSeconds ?? 0) : '× ${lastSets[i].reps} reps',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  )),
                  if (effectiveRir(lastSets[i].rir, lastSets[i].rpe) != null)
                    RirPill(rir: effectiveRir(lastSets[i].rir, lastSets[i].rpe)!),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}
