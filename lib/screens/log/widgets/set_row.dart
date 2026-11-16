import 'package:flutter/material.dart';
import '../../../models/weight_suggestion.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';
import 'numeric_keypad.dart';
import 'session_common.dart';

class SetRowItem extends StatelessWidget {
  final int setIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final bool isSkipped;
  final bool canSkip;
  final SetData data;
  final WeightSuggestion? suggestion;
  final void Function(SetData)? onChanged;
  final VoidCallback onSkip;
  final VoidCallback? onEdit;

  const SetRowItem({
    super.key,
    required this.setIndex, required this.isTimed,
    required this.isActive, required this.isDone, required this.isSkipped,
    required this.canSkip, required this.data,
    this.suggestion,
    required this.onChanged, required this.onSkip, this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPress: canSkip ? onSkip : null,
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 46, child: Text('Set ${setIndex + 1}', style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? accent : Colors.white.withValues(alpha: isDone ? 0.4 : 0.22),
            decoration: isSkipped ? TextDecoration.lineThrough : null,
          ))),
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: isSkipped ? Colors.white12 : isDone ? Colors.green : isActive ? accent : Colors.white24,
          ),
          const SizedBox(width: 8),
          if (isActive && onChanged != null)
            Expanded(child: SetRow(
              key: ValueKey('srinput-$setIndex'),
              setNumber: setIndex + 1, isTimed: isTimed,
              data: data,
              suggestion: suggestion,
              onChanged: onChanged!,
            ))
          else ...[
            if (!isTimed) ...[
              Expanded(child: ReadOnlyField(
                label: 'WEIGHT',
                value: isSkipped || data.weightKg == 0 ? '—' : '${fmtW(data.weightKg)} kg',
                dim: !isDone,
              )),
              const SizedBox(width: 6),
            ],
            Expanded(child: ReadOnlyField(
              label: isTimed ? 'DURATION' : 'REPS',
              value: isSkipped ? 'skip'
                  : isTimed ? (data.durationSeconds > 0 ? fmtSec(data.durationSeconds) : '—')
                  : (data.reps > 0 ? '${data.reps}' : '—'),
              dim: !isDone,
              strikethrough: isSkipped,
              accent: isSkipped ? Colors.orange : null,
            )),
            if (onEdit != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.edit, size: 12, color: Colors.white24),
              ),
          ],
        ]),
      ),
    );
  }
}

class SetRow extends StatefulWidget {
  final int setNumber;
  final bool isTimed;
  final SetData data;
  final WeightSuggestion? suggestion;
  final void Function(SetData) onChanged;

  const SetRow({
    super.key,
    required this.setNumber, required this.isTimed,
    required this.data,
    this.suggestion,
    required this.onChanged,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  static const _weightQuickAdjusts = [-2.5, -2.0, -1.0, 1.0, 2.0, 2.5];
  static const _repsQuickAdjusts = [-1.0, 1.0];
  static const _durationQuickAdjusts = [-15.0, -5.0, 5.0, 15.0];

  void _handleReps(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: (widget.data.reps + delta).clamp(1, 999), rir: widget.data.rir));
  }

  void _handleDuration(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: (widget.data.durationSeconds + delta).clamp(5, 3600), rir: widget.data.rir));
  }

  Future<void> _editWeight() async {
    final result = await showNumericKeypadSheet(
      context,
      title: 'Weight',
      subtitle: 'Set ${widget.setNumber}',
      initialValue: widget.data.weightKg,
      allowDecimal: true,
      unit: 'kg',
      quickAdjusts: _weightQuickAdjusts,
      min: 0,
      showNextButton: true,
    );
    if (result == null || !mounted) return;
    widget.onChanged(SetData(weightKg: result.value, reps: widget.data.reps, durationSeconds: widget.data.durationSeconds, rir: widget.data.rir));
    if (result.moveNext && mounted) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) _editSecondary();
    }
  }

  Future<void> _editSecondary() {
    return widget.isTimed ? _editDuration() : _editReps();
  }

  Future<void> _editReps() async {
    final result = await showNumericKeypadSheet(
      context,
      title: 'Reps',
      subtitle: 'Set ${widget.setNumber}',
      initialValue: widget.data.reps.toDouble(),
      allowDecimal: false,
      unit: 'reps',
      quickAdjusts: _repsQuickAdjusts,
      min: 1,
      max: 999,
    );
    if (result == null || !mounted) return;
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: result.value.round(), rir: widget.data.rir));
  }

  Future<void> _editDuration() async {
    final result = await showNumericKeypadSheet(
      context,
      title: 'Duration',
      subtitle: 'Set ${widget.setNumber}',
      initialValue: widget.data.durationSeconds.toDouble(),
      allowDecimal: false,
      unit: 'sec',
      quickAdjusts: _durationQuickAdjusts,
      min: 5,
      max: 3600,
    );
    if (result == null || !mounted) return;
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: result.value.round(), rir: widget.data.rir));
  }

  @override
  Widget build(BuildContext context) {
    final isTimed = widget.isTimed;
    final dur = widget.data.durationSeconds;
    final sug = widget.suggestion;
    final sugType = sug?.type ?? SuggestionType.noHistory;

    Color? weightTint;
    String? weightCue;

    Color? repsTint;
    String? repsCue;

    if (!isTimed) {
      switch (sugType) {
        case SuggestionType.increase:
          const emerald = Color(0xFF34D399);
          weightTint = emerald;
          final bumped = sug?.suggestedKg != null &&
              widget.data.weightKg > sug!.suggestedKg!;
          weightCue = bumped ? '✓' : '↑';
        case SuggestionType.decrease:
          const amber = Color(0xFFFBBF24);
          weightTint = amber;
          final dropped = sug?.suggestedKg != null &&
              widget.data.weightKg < sug!.suggestedKg!;
          weightCue = dropped ? '✓' : '↓';
        case SuggestionType.increaseReps:
          repsTint = const Color(0xFF38BDF8);
          repsCue = '↑';
        case SuggestionType.maintain:
          repsTint = const Color(0xFF818CF8);
          repsCue = '=';
        case SuggestionType.noHistory:
          break;
      }
    } else {
      switch (sugType) {
        case SuggestionType.increase:
          repsTint = const Color(0xFF34D399);
          repsCue = '↑';
        case SuggestionType.decrease:
          repsTint = const Color(0xFFFBBF24);
          repsCue = '↓';
        case SuggestionType.maintain:
        case SuggestionType.increaseReps:
          repsTint = const Color(0xFF818CF8);
          repsCue = '=';
        case SuggestionType.noHistory:
          break;
      }
    }

    return Row(children: [
      if (!isTimed) ...[
        Expanded(
          child: TappableWeightField(
            label: '${fmtW(widget.data.weightKg)} kg',
            tintColor: weightTint,
            cueText: weightCue,
            onTap: _editWeight,
          ),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: isTimed
            ? StepperField(
                label: fmtSec(dur),
                tintColor: repsTint,
                cueText: repsCue,
                onDecrement: () => _handleDuration(-5),
                onIncrement: () => _handleDuration(5),
                onTapValue: _editDuration,
              )
            : StepperField(
                label: '${widget.data.reps}',
                tintColor: repsTint,
                cueText: repsCue,
                onDecrement: () => _handleReps(-1),
                onIncrement: () => _handleReps(1),
                onTapValue: _editReps,
              ),
      ),
    ]);
  }
}

class TappableWeightField extends StatelessWidget {
  final String label;
  final Color? tintColor;
  final String? cueText;
  final VoidCallback onTap;

  const TappableWeightField({
    super.key,
    required this.label,
    this.tintColor,
    this.cueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.5);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: tintColor != null
              ? tintColor!.withValues(alpha: 0.14)
              : surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: tintColor != null
                ? tintColor!.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.12),
            width: tintColor != null ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'KG',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: (tintColor ?? Colors.white).withValues(alpha: 0.55),
              ),
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (cueText != null && tintColor != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      cueText!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: tintColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 13,
              color: (tintColor ?? Colors.white).withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }
}

class StepperField extends StatelessWidget {
  final String label;
  final Color? tintColor;
  final String? cueText;
  final Color? incrementHighlightColor;
  final Color? decrementHighlightColor;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapValue;

  const StepperField({super.key,
    required this.label,
    this.tintColor,
    this.cueText,
    this.incrementHighlightColor,
    this.decrementHighlightColor,
    required this.onDecrement, required this.onIncrement,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      StepBtn(
        icon: Icons.remove,
        onTap: onDecrement,
        highlightColor: decrementHighlightColor,
      ),
      Expanded(
        child: GestureDetector(
          onTap: onTapValue,
          child: Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: tintColor != null
                ? BoxDecoration(
                    color: tintColor!.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tintColor!.withValues(alpha: 0.42),
                    ),
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (cueText != null && tintColor != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    cueText!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: tintColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      StepBtn(
        icon: Icons.add,
        onTap: onIncrement,
        highlightColor: incrementHighlightColor,
      ),
    ]);
  }
}

class StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? highlightColor;
  const StepBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16),
    onPressed: onTap,
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: highlightColor,
      backgroundColor: highlightColor != null
          ? highlightColor!.withValues(alpha: 0.2)
          : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      side: highlightColor != null
          ? BorderSide(color: highlightColor!.withValues(alpha: 0.45))
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
