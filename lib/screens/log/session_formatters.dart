// ─── Formatting helpers shared across the active-session UI ─────────────────────

String fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String fmtRpe(double rpe) =>
    rpe == rpe.roundToDouble() ? rpe.toInt().toString() : rpe.toStringAsFixed(1);

String fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
