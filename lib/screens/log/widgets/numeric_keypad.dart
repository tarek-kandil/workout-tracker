import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../session_formatters.dart';

// ─── Pure text-buffer logic ─────────────────────────────────────────────────
//
// Kept free of widget/BuildContext state so the digit/decimal/backspace/clear
// rules can be unit tested directly, independent of the sheet UI.

/// Immutable text buffer for the numeric keypad. Each mutating method returns
/// a new instance; [text] is always the raw (unparsed, un-clamped) string the
/// user has typed so far — it may be empty, or end in a trailing ".".
class NumericKeypadBuffer {
  final String text;
  final bool allowDecimal;

  const NumericKeypadBuffer(this.text, {this.allowDecimal = true});

  /// Max raw character length, guards against runaway/pointless input.
  static const _maxLength = 7;

  NumericKeypadBuffer withDigit(String digit) {
    assert(digit.length == 1 && RegExp(r'^[0-9]$').hasMatch(digit));
    if (text.length >= _maxLength) return this;
    // Replace a lone leading "0" instead of accumulating "01", "02"...
    if (text == '0') return NumericKeypadBuffer(digit, allowDecimal: allowDecimal);
    return NumericKeypadBuffer(text + digit, allowDecimal: allowDecimal);
  }

  NumericKeypadBuffer withDecimalPoint() {
    if (!allowDecimal || text.contains('.')) return this;
    return NumericKeypadBuffer(text.isEmpty ? '0.' : '$text.', allowDecimal: allowDecimal);
  }

  NumericKeypadBuffer backspace() {
    if (text.isEmpty) return this;
    return NumericKeypadBuffer(text.substring(0, text.length - 1), allowDecimal: allowDecimal);
  }

  NumericKeypadBuffer clear() => NumericKeypadBuffer('', allowDecimal: allowDecimal);

  /// Parses [text] accepting either "." or "," as the decimal separator.
  /// Returns null when the buffer is empty or not yet a valid number (e.g.
  /// a lone trailing ".").
  double? get numericValue {
    final normalized = text.replaceAll(',', '.');
    if (normalized.isEmpty || normalized == '.') return null;
    return double.tryParse(normalized);
  }
}

/// Result popped by the numeric keypad sheet. [moveNext] is true when the
/// user tapped the "Next ›" action (weight → reps/duration) rather than the
/// final "Done".
class NumericKeypadResult {
  final double value;
  final bool moveNext;
  const NumericKeypadResult({required this.value, this.moveNext = false});
}

/// A single quick-adjust delta chip, e.g. -2.5 / +5 for weight or -15 / +15
/// for duration.
String fmtDelta(double delta) {
  final sign = delta >= 0 ? '+' : '−';
  final magnitude = delta.abs();
  final txt = magnitude == magnitude.roundToDouble()
      ? magnitude.toInt().toString()
      : magnitude.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '$sign$txt';
}

/// Clamps [value] to `[min, max]` (max defaults to +infinity) and, when
/// [allowDecimal] is false, rounds to the nearest whole number first.
double clampNumericValue(double value, {required double min, double? max, required bool allowDecimal}) {
  var v = allowDecimal ? value : value.roundToDouble();
  v = v.clamp(min, max ?? double.infinity);
  return v;
}

/// Shows the in-app numeric keypad as a LiquidGlass-styled bottom sheet.
/// Returns null if the user dismissed it without confirming (existing value
/// should be left untouched by the caller), matching [RirSheet]'s contract.
Future<NumericKeypadResult?> showNumericKeypadSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required double initialValue,
  required bool allowDecimal,
  required String unit,
  required List<double> quickAdjusts,
  double min = 0,
  double? max,
  bool showNextButton = false,
}) {
  return showModalBottomSheet<NumericKeypadResult>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NumericKeypadSheet(
      title: title,
      subtitle: subtitle,
      initialValue: initialValue,
      allowDecimal: allowDecimal,
      unit: unit,
      quickAdjusts: quickAdjusts,
      min: min,
      max: max,
      showNextButton: showNextButton,
    ),
  );
}

/// In-app numeric keypad bottom sheet used to enter weight / reps / duration
/// during an active workout, replacing the system keyboard so the value stays
/// on-screen at all times and common plate/rep/time nudges stay one tap away.
class NumericKeypadSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double initialValue;
  final bool allowDecimal;
  final String unit;
  final List<double> quickAdjusts;
  final double min;
  final double? max;
  final bool showNextButton;

  const NumericKeypadSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.initialValue,
    required this.allowDecimal,
    required this.unit,
    required this.quickAdjusts,
    this.min = 0,
    this.max,
    this.showNextButton = false,
  });

  @override
  State<NumericKeypadSheet> createState() => _NumericKeypadSheetState();
}

class _NumericKeypadSheetState extends State<NumericKeypadSheet> {
  late NumericKeypadBuffer _buffer;

  @override
  void initState() {
    super.initState();
    _buffer = NumericKeypadBuffer(_formatSeed(widget.initialValue), allowDecimal: widget.allowDecimal);
  }

  String _formatSeed(double v) => widget.allowDecimal ? fmtW(v) : v.round().toString();

  /// The clamped value that would be committed if the user confirmed now —
  /// falls back to the original value when the buffer is empty/invalid,
  /// mirroring the previous inline-TextField "discard invalid input" rule.
  double get _clampedValue {
    final raw = _buffer.numericValue ?? widget.initialValue;
    return clampNumericValue(raw, min: widget.min, max: widget.max, allowDecimal: widget.allowDecimal);
  }

  void _digit(String d) {
    HapticFeedback.selectionClick();
    setState(() => _buffer = _buffer.withDigit(d));
  }

  void _decimal() {
    if (!widget.allowDecimal) return;
    HapticFeedback.selectionClick();
    setState(() => _buffer = _buffer.withDecimalPoint());
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    setState(() => _buffer = _buffer.backspace());
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() => _buffer = _buffer.clear());
  }

  void _quickAdjust(double delta) {
    HapticFeedback.selectionClick();
    final next = clampNumericValue(_clampedValue + delta, min: widget.min, max: widget.max, allowDecimal: widget.allowDecimal);
    setState(() => _buffer = NumericKeypadBuffer(_formatSeed(next), allowDecimal: widget.allowDecimal));
  }

  void _confirm({required bool moveNext}) {
    Navigator.of(context).pop(NumericKeypadResult(value: _clampedValue, moveNext: moveNext));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final displayText = _buffer.text.isEmpty ? _formatSeed(widget.initialValue) : _buffer.text;

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
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
          Text(widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(widget.subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ],
          const SizedBox(height: 14),
          // Live value display.
          Container(
            key: const ValueKey('keypad-display'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(displayText,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 6),
                Text(widget.unit,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Quick-adjust chips (plate jumps / rep or time nudges).
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.quickAdjusts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final delta = widget.quickAdjusts[i];
                return _QuickAdjustChip(label: fmtDelta(delta), onTap: () => _quickAdjust(delta));
              },
            ),
          ),
          const SizedBox(height: 14),
          _KeypadGrid(
            allowDecimal: widget.allowDecimal,
            onDigit: _digit,
            onDecimal: _decimal,
            onBackspace: _backspace,
            onClear: _clear,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _confirm(moveNext: widget.showNextButton),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(widget.showNextButton ? 'Next ›' : 'Done',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAdjustChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAdjustChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
      ),
    );
  }
}

/// 3x4 glass key grid: 1-9, then "." / 0 / backspace. When [allowDecimal] is
/// false (reps, duration) the decimal key becomes a disabled placeholder so
/// the grid layout stays stable across field types.
class _KeypadGrid extends StatelessWidget {
  final bool allowDecimal;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const _KeypadGrid({
    required this.allowDecimal,
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback? onTap, {IconData? icon}) => _KeypadKey(label: label, icon: icon, onTap: onTap);

    final rows = <List<Widget>>[
      [key('1', () => onDigit('1')), key('2', () => onDigit('2')), key('3', () => onDigit('3'))],
      [key('4', () => onDigit('4')), key('5', () => onDigit('5')), key('6', () => onDigit('6'))],
      [key('7', () => onDigit('7')), key('8', () => onDigit('8')), key('9', () => onDigit('9'))],
      [
        allowDecimal ? key('.', onDecimal) : key('', null),
        key('0', () => onDigit('0')),
        _KeypadKey(label: '', icon: Icons.backspace_outlined, onTap: onBackspace, onLongPress: onClear),
      ],
    ];

    return Column(
      children: rows
          .map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: row.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList()),
              ))
          .toList(),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _KeypadKey({required this.label, this.icon, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 20, color: Colors.white.withValues(alpha: enabled ? 0.8 : 0.15))
              : Text(label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: enabled ? 0.92 : 0.15),
                  )),
        ),
      ),
    );
  }
}
