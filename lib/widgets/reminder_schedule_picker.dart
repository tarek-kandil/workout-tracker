import 'package:flutter/material.dart';
import 'drum_picker.dart';

const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Reusable reminder configuration block used in both Daily Tasks and Flash
/// Workouts dialogs:
/// - Switch to enable/disable reminders
/// - 7 weekday toggle chips (Mon..Sun, bit 0..6; defaults to all 7 days = 0x7F)
/// - Tappable time pill that opens a drum-wheel HH:MM picker (or system time picker)
class ReminderSchedulePicker extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onTimeChanged;
  final int daysMask;
  final ValueChanged<int> onDaysChanged;

  const ReminderSchedulePicker({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.hour,
    required this.minute,
    required this.onTimeChanged,
    required this.daysMask,
    required this.onDaysChanged,
  });

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DrumTimePickerSheet(
        initialHour: hour,
        initialMinute: minute,
      ),
    );
    if (picked != null) {
      onTimeChanged(picked.$1, picked.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveMask = (daysMask & 0x7F) == 0 ? 0x7F : (daysMask & 0x7F);
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_outlined,
                size: 18, color: scheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text('Reminder', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Switch(
              value: enabled,
              onChanged: onEnabledChanged,
            ),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 10),
          // ── Time selector pill ───────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pickTime(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Time',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.unfold_more_rounded,
                      size: 18, color: scheme.primary.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ── Weekday selector chips ───────────────────────────────────────
          Row(
            children: [
              Text(
                'Days',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => onDaysChanged(0x7F),
                child: Text(
                  effectiveMask == 0x7F ? 'Every day' : 'Select all',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary.withValues(
                        alpha: effectiveMask == 0x7F ? 0.55 : 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final bit = 1 << i;
              final selected = (effectiveMask & bit) != 0;
              return GestureDetector(
                onTap: () {
                  final next = effectiveMask ^ bit;
                  // Keep at least one day selected
                  if (next != 0) onDaysChanged(next);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.22)
                        : scheme.onSurface.withValues(alpha: 0.06),
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.14),
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    _weekdayShort[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _DrumTimePickerSheet extends StatefulWidget {
  final int initialHour;
  final int initialMinute;

  const _DrumTimePickerSheet({
    required this.initialHour,
    required this.initialMinute,
  });

  @override
  State<_DrumTimePickerSheet> createState() => _DrumTimePickerSheetState();
}

class _DrumTimePickerSheetState extends State<_DrumTimePickerSheet> {
  static const _bg = Color(0xFF141829);
  late int _hour = widget.initialHour.clamp(0, 23);
  late int _minute = widget.initialMinute.clamp(0, 59);

  static final _hours =
      List.generate(24, (i) => i.toString().padLeft(2, '0'));
  static final _minutes =
      List.generate(60, (i) => i.toString().padLeft(2, '0'));

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Expanded(
                child: Text(
                  'Reminder Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, (_hour, _minute)),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DrumPicker(
                  items: _hours,
                  selectedIndex: _hour,
                  onChanged: (i) => setState(() => _hour = i),
                  accentColor: accent,
                  backgroundColor: _bg,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ),
              Expanded(
                child: DrumPicker(
                  items: _minutes,
                  selectedIndex: _minute,
                  onChanged: (i) => setState(() => _minute = i),
                  accentColor: accent,
                  backgroundColor: _bg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
