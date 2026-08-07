import 'package:flutter/material.dart';

Widget _cfgBtn(ColorScheme cs, bool enabled, IconData icon, VoidCallback cb) =>
    SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: cs.onSurface.withValues(alpha: enabled ? 0.09 : 0.04),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: enabled ? cb : null,
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Icon(icon, size: 14,
                color: cs.onSurface.withValues(alpha: enabled ? 0.8 : 0.25)),
          ),
        ),
      ),
    );

class ConfigStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;
  const ConfigStepper({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.step = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _cfgBtn(cs, value > min, Icons.remove, () => onChanged((value - step).clamp(min, max))),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        _cfgBtn(cs, value < max, Icons.add, () => onChanged((value + step).clamp(min, max))),
      ]),
    ]);
  }
}
