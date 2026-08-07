import 'package:flutter/material.dart';

class RpeSheet extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  const RpeSheet({super.key, required this.exerciseName, required this.setNumber});
  @override
  State<RpeSheet> createState() => _RpeSheetState();
}

class _RpeSheetState extends State<RpeSheet> {
  double? _selected;

  static const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];
  static final _rpeLabels = <double, String>{
    6.0: 'Very easy',
    6.5: 'Easy',
    7.0: 'Moderate',
    7.5: 'Somewhat hard',
    8.0: 'Hard, 2–3 reps left',
    8.5: 'Very hard, 1–2 reps left',
    9.0: '1 rep left',
    9.5: 'Could not do more reps',
    10.0: 'Max effort',
  };

  void _select(double rpe) {
    setState(() => _selected = rpe);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(rpe);
    });
  }

  String _label(double rpe) =>
      rpe == rpe.truncateToDouble() ? rpe.toInt().toString() : rpe.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e2030),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('How hard was that?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Set ${widget.setNumber} · ${widget.exerciseName} · optional',
              style: const TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: _rpeValues.map((rpe) {
              final isSelected = _selected == rpe;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _select(rpe),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFBBF24)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _label(rpe),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected == null
                ? const Text(
                    'Tap to log · swipe down to skip',
                    key: ValueKey('hint'),
                    style: TextStyle(fontSize: 9, color: Colors.white24),
                  )
                : Container(
                    key: ValueKey(_selected),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_rpeLabels[_selected] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        Text(
                          'RPE ${_label(_selected!)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
