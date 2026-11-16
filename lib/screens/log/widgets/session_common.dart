import 'package:flutter/material.dart';
import '../../../models/weight_suggestion.dart';
import '../session_formatters.dart';

// ─── Shared leaf widgets for the active-session cards ───────────────────────────

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 3),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
  );
}

class ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;
  final bool strikethrough;
  final Color? accent;
  const ReadOnlyField({super.key, required this.label, required this.value, this.dim = false, this.strikethrough = false, this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: dim ? 0.03 : 0.07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.3)),
      Text(value, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: accent ?? Colors.white.withValues(alpha: dim ? 0.3 : 0.9),
        decoration: strikethrough ? TextDecoration.lineThrough : null,
      )),
    ]),
  );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const ActionTile({super.key, required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
    );
  }
}

class TimedSetInput extends StatelessWidget {
  final bool running;
  final int elapsed;
  final bool stopped;
  final int target;
  final bool isCircuit;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const TimedSetInput({super.key, 
    required this.running, required this.elapsed, required this.stopped,
    required this.target, this.isCircuit = false,
    required this.onStart, required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (stopped)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(fmtSec(elapsed), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text('logged', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.38))),
        ])
      else if (running)
        Column(children: [
          Text(fmtSec(elapsed), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w300, color: Colors.white)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          ),
        ])
      else
        Column(children: [
          Text('Target: ${fmtSec(target)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.45))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_circle_outlined),
            label: Text(isCircuit ? 'Start Circuit' : 'Start Timer'),
          )),
        ]),
    ]);
  }
}

class SuggestionBadge extends StatelessWidget {
  final WeightSuggestion suggestion;
  const SuggestionBadge({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    if (suggestion.type == SuggestionType.noHistory) {
      return const SizedBox.shrink();
    }

    final isTimed = suggestion.suggestedDurationSeconds != null;
    final Color accent;
    final Color bgTint;
    final String tagLabel;

    switch (suggestion.type) {
      case SuggestionType.increase:
        accent = const Color(0xFF34D399);
        bgTint = const Color(0xFF064E3B);
        tagLabel = isTimed ? '↑ TIME' : '↑ WEIGHT';
      case SuggestionType.increaseReps:
        accent = const Color(0xFF38BDF8);
        bgTint = const Color(0xFF0C4A6E);
        tagLabel = '↑ REPS';
      case SuggestionType.maintain:
      case SuggestionType.noHistory:
        accent = const Color(0xFF818CF8);
        bgTint = const Color(0xFF1E1B4B);
        tagLabel = 'HOLD';
      case SuggestionType.decrease:
        accent = const Color(0xFFFBBF24);
        bgTint = const Color(0xFF451A03);
        tagLabel = isTimed ? '↓ TIME' : '↓ WEIGHT';
    }

    final String targetLabel;
    if (isTimed) {
      targetLabel = fmtSec(suggestion.suggestedDurationSeconds!);
    } else if (suggestion.suggestedReps != null) {
      targetLabel = '× ${suggestion.suggestedReps}';
    } else if (suggestion.suggestedKg != null) {
      targetLabel = '${fmtW(suggestion.suggestedKg!)} kg';
    } else {
      targetLabel = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgTint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              tagLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: accent,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (targetLabel.isNotEmpty) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                targetLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
