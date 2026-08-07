import 'package:flutter/material.dart';

class CountdownOverlay extends StatelessWidget {
  final int secondsLeft;
  final String exerciseName;
  final String setLabel;
  final String? circuitNextLabel;

  const CountdownOverlay({super.key, required this.secondsLeft, required this.exerciseName, required this.setLabel, this.circuitNextLabel});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isGo = secondsLeft <= 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('AUTOPILOT', style: TextStyle(color: accent.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          Text(exerciseName, style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          Text(setLabel, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          if (circuitNextLabel != null) ...[
            const SizedBox(height: 4),
            Text(circuitNextLabel!, style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ],
          const SizedBox(height: 48),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isGo ? 'GO!' : '$secondsLeft',
              key: ValueKey(secondsLeft),
              style: TextStyle(color: isGo ? Colors.greenAccent : Colors.white, fontSize: 100, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          const SizedBox(height: 32),
          Text(isGo ? 'Starting...' : 'Get ready', style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      ),
    );
  }
}
