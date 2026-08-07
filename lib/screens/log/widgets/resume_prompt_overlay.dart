import 'package:flutter/material.dart';

class ResumePromptOverlay extends StatelessWidget {
  final int? savedAtMs;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onDiscard;

  const ResumePromptOverlay({super.key, required this.savedAtMs, required this.onResume, required this.onRestart, required this.onDiscard});

  String get _timeAgo {
    if (savedAtMs == null) return '';
    final diffMs = DateTime.now().millisecondsSinceEpoch - savedAtMs!;
    final minutes = diffMs ~/ 60000;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.fitness_center, size: 52, color: accent),
              const SizedBox(height: 20),
              const Text('Resume Workout?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              if (_timeAgo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Last saved $_timeAgo', style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
              const SizedBox(height: 36),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: onResume,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PromptAction(icon: Icons.restart_alt, label: 'Restart', color: Colors.white70, onTap: onRestart),
                const SizedBox(width: 40),
                PromptAction(icon: Icons.close, label: 'Discard', color: Colors.red.shade300, onTap: onDiscard),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class PromptAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const PromptAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    IconButton.outlined(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.4))),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]);
}
