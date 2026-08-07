import 'package:flutter/material.dart';
import '../session_formatters.dart';

class RestPill extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final String currentLabel;
  final String nextLabel;
  final VoidCallback onSkip;

  const RestPill({super.key, 
    required this.secondsLeft,
    required this.totalSeconds,
    required this.currentLabel,
    required this.nextLabel,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        SizedBox(
          width: 36, height: 36,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: Colors.white12,
              color: accent,
            ),
            Text(
              fmtSec(secondsLeft),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLabel,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (nextLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nextLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next, size: 14),
          label: const Text('Skip', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
    );
  }
}
