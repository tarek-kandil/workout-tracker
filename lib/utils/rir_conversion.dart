/// RIR (Reps In Reserve) ↔ RPE (Rate of Perceived Exertion) conversion and
/// shared display helpers.
///
/// RIR = 10 − RPE. The two scales are exact inverses: RPE is "how hard did
/// that feel" (higher = harder, 10 = failure); RIR is "how many more reps
/// could you have done" (lower = harder, 0 = failure).
///
/// Schema v18 added nullable `rir` / `targetRir` columns alongside the
/// existing `rpe` / `targetRpe` columns (kept for one release). New writes
/// dual-write both; reads should prefer `rir` and fall back to converting
/// `rpe`, never converting both (which would be a no-op here, but keeps the
/// intent explicit and guards against future double-conversion bugs).
library;

import 'package:flutter/material.dart';

/// Converts an RPE value to its RIR equivalent.
double rirFromRpe(double rpe) => 10.0 - rpe;

/// Converts an RIR value to its RPE equivalent.
double rpeFromRir(double rir) => 10.0 - rir;

/// Resolves the effective RIR for a row that may only have the legacy [rpe]
/// populated (pre-v18 data, or a device that hasn't synced [rir] yet).
/// Prefers [rir]; falls back to converting [rpe]. Returns null if both are
/// null.
double? effectiveRir(double? rir, double? rpe) {
  if (rir != null) return rir;
  if (rpe != null) return rirFromRpe(rpe);
  return null;
}

/// The ordered RIR values offered by the picker, hardest → easiest.
/// `null` represents the "None" (not recorded) option.
const List<double?> rirPickerValues = [
  null,
  0.0,
  0.5,
  1.0,
  1.5,
  2.0,
  2.5,
  3.0,
  3.5,
  4.0,
  4.5,
  5.0,
];

/// Per-value microcopy shown under the picker / in tooltips.
///
/// Not `const`: double keys can't use primitive equality in constant
/// collections, so this is a runtime-initialized (but still immutable in
/// practice) map.
final Map<double, String> rirMicrocopy = {
  0.0: 'failure',
  0.5: 'near failure',
  1.0: 'one rep left',
  1.5: '1–2 reps left',
  2.0: 'two reps left',
  2.5: '2–3 reps left',
  3.0: 'moderate',
  3.5: 'comfortable',
  4.0: 'easy',
  4.5: 'very easy',
  5.0: 'very easy',
};

/// Formats an RIR value for display: whole numbers with no decimal, halves
/// with one decimal, and "5+" for values at/above 5.
String fmtRir(double rir) {
  if (rir >= 5.0) return '5+';
  return rir == rir.roundToDouble()
      ? rir.toInt().toString()
      : rir.toStringAsFixed(1);
}

/// Semantics-friendly spoken label, e.g. "1 RIR, one rep left".
String rirSemanticsLabel(double rir) {
  final micro = rirMicrocopy[rir];
  final value = fmtRir(rir);
  return micro == null ? '$value RIR' : '$value RIR, $micro';
}

/// Color mapping (inverted vs the old RPE scale — lower RIR is harder and
/// therefore "hotter"): 0–0.5 red, 1–1.5 orange, 2–2.5 yellow, 3 indigo,
/// 3.5+ blue.
Color rirColor(double rir) {
  if (rir <= 0.5) return const Color(0xFFF87171);
  if (rir <= 1.5) return const Color(0xFFFB923C);
  if (rir <= 2.5) return const Color(0xFFFBBF24);
  if (rir <= 3.0) return const Color(0xFF818CF8);
  return const Color(0xFF38BDF8);
}

/// Compact read-only pill for a recorded or target RIR value, e.g. "1.5 RIR"
/// or (with [isTarget]) "Target 2 RIR". Callers should omit this widget
/// entirely when the RIR is null (not recorded) rather than passing a
/// placeholder.
class RirPill extends StatelessWidget {
  final double rir;
  final bool isTarget;
  const RirPill({super.key, required this.rir, this.isTarget = false});

  @override
  Widget build(BuildContext context) {
    final color = rirColor(rir);
    final label =
        isTarget ? 'Target ${fmtRir(rir)} RIR' : '${fmtRir(rir)} RIR';
    final micro = rirMicrocopy[rir];
    return Semantics(
      label: micro == null ? label : '$label, $micro',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}
