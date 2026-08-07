import 'package:flutter/material.dart';
import '../models/session_models.dart';
import '../session_formatters.dart';
import 'session_common.dart';

class SetRowItem extends StatelessWidget {
  final int setIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final bool isSkipped;
  final bool canSkip;
  final SetData data;
  final void Function(SetData)? onChanged;
  final VoidCallback onSkip;
  final VoidCallback? onEdit;

  const SetRowItem({
    super.key,
    required this.setIndex, required this.isTimed,
    required this.isActive, required this.isDone, required this.isSkipped,
    required this.canSkip, required this.data,
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
              data: data, onChanged: onChanged!,
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
  final void Function(SetData) onChanged;

  const SetRow({
    super.key,
    required this.setNumber, required this.isTimed,
    required this.data, required this.onChanged,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  bool _editingWeight = false;
  bool _editingSecondary = false;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _secondaryCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController();
    _secondaryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  void _handleWeight(double delta) {
    widget.onChanged(SetData(
      weightKg: (widget.data.weightKg + delta).clamp(0.0, double.infinity),
      reps: widget.data.reps,
      durationSeconds: widget.data.durationSeconds,
      rpe: widget.data.rpe,
    ));
  }

  void _handleReps(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: (widget.data.reps + delta).clamp(1, 999), rpe: widget.data.rpe));
  }

  void _handleDuration(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: (widget.data.durationSeconds + delta).clamp(5, 3600), rpe: widget.data.rpe));
  }

  void _commitWeight() {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (v != null && v >= 0) {
      widget.onChanged(SetData(weightKg: v, reps: widget.data.reps, durationSeconds: widget.data.durationSeconds, rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingWeight = false);
  }

  void _commitReps() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: v, rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  void _commitDuration() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: v.clamp(5, 3600), rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTimed = widget.isTimed;
    final dur = widget.data.durationSeconds;

    return Row(children: [
      if (!isTimed) ...[
        Expanded(child: StepperField(
          label: _editingWeight ? null : '${fmtW(widget.data.weightKg)} kg',
          editingController: _editingWeight ? _weightCtrl : null,
          onDecrement: () => _handleWeight(-2.5),
          onIncrement: () => _handleWeight(2.5),
          onTapValue: () => setState(() {
            _weightCtrl.text = fmtW(widget.data.weightKg);
            _weightCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _weightCtrl.text.length);
            _editingWeight = true; _editingSecondary = false;
          }),
          onCommit: _commitWeight,
        )),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: isTimed
            ? StepperField(
                label: _editingSecondary ? null : fmtSec(dur),
                editingController: _editingSecondary ? _secondaryCtrl : null,
                isInteger: true,
                onDecrement: () => _handleDuration(-5),
                onIncrement: () => _handleDuration(5),
                onTapValue: () => setState(() {
                  _secondaryCtrl.text = dur.toString();
                  _secondaryCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                  _editingSecondary = true; _editingWeight = false;
                }),
                onCommit: _commitDuration,
              )
            : StepperField(
                label: _editingSecondary ? null : '${widget.data.reps}',
                editingController: _editingSecondary ? _secondaryCtrl : null,
                isInteger: true,
                onDecrement: () => _handleReps(-1),
                onIncrement: () => _handleReps(1),
                onTapValue: () => setState(() {
                  _secondaryCtrl.text = widget.data.reps.toString();
                  _secondaryCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                  _editingSecondary = true; _editingWeight = false;
                }),
                onCommit: _commitReps,
              ),
      ),
    ]);
  }
}

class StepperField extends StatelessWidget {
  final String? label;
  final TextEditingController? editingController;
  final bool isInteger;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapValue;
  final VoidCallback onCommit;

  const StepperField({super.key, 
    this.label, this.editingController, this.isInteger = false,
    required this.onDecrement, required this.onIncrement,
    required this.onTapValue, required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      StepBtn(icon: Icons.remove, onTap: onDecrement),
      Expanded(
        child: editingController != null
            ? TextField(
                controller: editingController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                onSubmitted: (_) => onCommit(),
                onTapOutside: (_) => onCommit(),
              )
            : GestureDetector(
                onTap: onTapValue,
                child: Text(label ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
      ),
      StepBtn(icon: Icons.add, onTap: onIncrement),
    ]);
  }
}

class StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const StepBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16),
    onPressed: onTap,
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
