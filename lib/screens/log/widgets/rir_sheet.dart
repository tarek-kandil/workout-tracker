import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rir_conversion.dart';

/// Which context the sheet is being shown in — controls title/subtitle
/// copy only; the picker itself is identical.
enum RirSheetMode { logged, target }

/// Result popped by [RirSheet].
///
/// `null` (the sheet itself, not this class) means the user dismissed the
/// sheet without making a choice — callers should leave any existing value
/// untouched. A non-null [RirPick] with [rir] == null means the user
/// explicitly tapped "None", clearing/opting out of recording effort.
class RirPick {
  final double? rir;
  const RirPick(this.rir);
}

/// Bottom sheet for picking an RIR (Reps In Reserve) value.
///
/// Replaces the old RPE sheet: RIR = 10 − RPE, and the scale is inverted —
/// lower RIR means harder (0 = failure) rather than higher = harder.
class RirSheet extends StatefulWidget {
  final RirSheetMode mode;
  final String? exerciseName;
  final int? setNumber;
  final double? initialRir;

  const RirSheet({
    super.key,
    this.mode = RirSheetMode.logged,
    this.exerciseName,
    this.setNumber,
    this.initialRir,
  });

  @override
  State<RirSheet> createState() => _RirSheetState();
}

class _RirSheetState extends State<RirSheet> {
  static const _hintPrefKey = 'rir_transition_hint_dismissed';

  double? _selected;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialRir;
    _maybeShowTransitionHint();
  }

  Future<void> _maybeShowTransitionHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_hintPrefKey) ?? false;
    if (!dismissed && mounted) setState(() => _showHint = true);
  }

  Future<void> _dismissHint() async {
    setState(() => _showHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hintPrefKey, true);
  }

  void _select(double? rir) {
    setState(() => _selected = rir);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(RirPick(rir));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTarget = widget.mode == RirSheetMode.target;
    final title = isTarget ? 'Target RIR' : 'How many reps were left?';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E2030), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(
            isTarget
                ? 'How hard this should be. Most working sets use 1–3 RIR.'
                : 'Set ${widget.setNumber} · ${widget.exerciseName} · optional',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          if (_showHint) ...[
            _TransitionHint(onDismiss: _dismissHint),
            const SizedBox(height: 12),
          ],
          const Text(
            'Lower RIR = harder · 0 = failure',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white38,
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 10),
          RirChipRow(
            selected: _selected,
            onSelected: _select,
            emphasizeQuickPicks: isTarget,
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
                : _SelectedSummary(key: ValueKey(_selected), rir: _selected!),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable RIR chip row, hardest (None, then 0) on the left
/// to easiest (5+) on the right.
class RirChipRow extends StatelessWidget {
  final double? selected;
  final ValueChanged<double?> onSelected;
  final bool emphasizeQuickPicks;

  const RirChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
    this.emphasizeQuickPicks = false,
  });

  // Not `const`: double elements can't use primitive equality in constant
  // collections.
  static final _quickPicks = {1.0, 2.0, 3.0};

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rirPickerValues.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final value = rirPickerValues[i];
          return _RirChip(
            value: value,
            isSelected: value == selected,
            emphasize: emphasizeQuickPicks &&
                value != null &&
                _quickPicks.contains(value),
            onTap: () => onSelected(value),
          );
        },
      ),
    );
  }
}

class _RirChip extends StatelessWidget {
  final double? value; // null = "None"
  final bool isSelected;
  final bool emphasize;
  final VoidCallback onTap;

  const _RirChip({
    required this.value,
    required this.isSelected,
    required this.emphasize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = value == null ? Colors.white54 : rirColor(value!);
    final label = value == null ? 'None' : fmtRir(value!);
    final semanticsLabel = value == null
        ? 'Clear RIR, effort not recorded'
        : rirSemanticsLabel(value!);

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.symmetric(horizontal: emphasize ? 14 : 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.10),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: value == null
                ? Icon(Icons.remove_circle_outline,
                    size: 18, color: isSelected ? color : Colors.white38)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        Icon(Icons.check, size: 12, color: color),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: emphasize ? 13 : 12,
                          fontWeight: isSelected || emphasize
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? color
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TransitionHint extends StatelessWidget {
  final VoidCallback onDismiss;
  const _TransitionHint({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.swap_vert_rounded, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Switched from RPE: RIR is inverted — lower RIR means harder. '
              'RIR = 10 − RPE.',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.3),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close, size: 14, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  final double rir;
  const _SelectedSummary({super.key, required this.rir});

  @override
  Widget build(BuildContext context) {
    final color = rirColor(rir);
    final micro = rirMicrocopy[rir] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(micro, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          Text(
            '${fmtRir(rir)} RIR',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
