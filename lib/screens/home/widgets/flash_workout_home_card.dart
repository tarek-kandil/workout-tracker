import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../database/app_database.dart';
import '../../../providers/flash_workouts_providers.dart';
import '../../../widgets/glass_route.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../log/active_session_screen.dart';
import '../../settings/wod_exercise_setup_screen.dart';

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class FlashWorkoutHomeCard extends ConsumerStatefulWidget {
  final WodTemplate wod;
  const FlashWorkoutHomeCard({super.key, required this.wod});

  @override
  ConsumerState<FlashWorkoutHomeCard> createState() =>
      _FlashWorkoutHomeCardState();
}

class _FlashWorkoutHomeCardState extends ConsumerState<FlashWorkoutHomeCard> {
  bool _hasProgress = false;

  String get _prefsKey => 'workout_progress_${widget.wod.id}';

  @override
  void initState() {
    super.initState();
    _checkProgress();
  }

  Future<void> _checkProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _hasProgress = prefs.containsKey(_prefsKey));
    }
  }

  Future<void> _startOrEdit() async {
    final result =
        await ref.read(flashWorkoutResultProvider(widget.wod.id).future);
    if (!mounted) return;
    if (result == null || result.items.isEmpty) {
      await Navigator.of(context).push(
        glassRoute(WodExerciseSetupScreen(wodTemplateId: widget.wod.id)),
      );
      ref.invalidate(flashWorkoutResultProvider(widget.wod.id));
      return;
    }
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      glassRoute(ActiveSessionScreen(result: result, autoResume: _hasProgress)),
    );
    ref.invalidate(flashWorkoutResultProvider(widget.wod.id));
    await _checkProgress();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);

    final days =
        ref.watch(flashWorkoutLast7DaysProvider(widget.wod.id)).valueOrNull ??
            List.filled(7, false);
    final isDoneToday = days.isNotEmpty && days.last;
    final result =
        ref.watch(flashWorkoutResultProvider(widget.wod.id)).valueOrNull;
    final exerciseCount = result?.allExercises.length ?? 0;

    final accentColor = _hasProgress
        ? Colors.amber
        : (isDoneToday ? Colors.green : const Color(0xFF38BDF8));

    final metaParts = <String>[
      if (exerciseCount > 0)
        '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}'
      else
        'Tap to add exercises',
      if (widget.wod.reminderHour != null &&
          widget.wod.reminderMinute != null)
        '${widget.wod.reminderHour!.toString().padLeft(2, '0')}:${widget.wod.reminderMinute!.toString().padLeft(2, '0')}',
      if (_hasProgress) 'In progress',
    ];

    return LiquidGlassContainer(
      borderRadius: 22,
      blurSigma: 10,
      tintColor: tint,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _startOrEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              // ── Icon badge ─────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDoneToday ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isDoneToday ? Icons.check_rounded : Icons.bolt_rounded,
                  size: 22,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 14),
              // ── Name + meta + 7-day dots ───────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.wod.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface
                                .withValues(alpha: isDoneToday ? 0.65 : 0.92),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metaParts.join('  ·  '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.4),
                          ),
                    ),
                    const SizedBox(height: 8),
                    _FlashSevenDayDots(days: days, accentColor: accentColor),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ── Start / Resume button ──────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hasProgress
                          ? 'Resume'
                          : (isDoneToday ? 'Again' : 'Start'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlashSevenDayDots extends StatelessWidget {
  final List<bool> days;
  final Color accentColor;
  const _FlashSevenDayDots({required this.days, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final todayWeekday = DateTime.now().weekday;
    final labels = List.generate(
      7,
      (i) => _dayLabels[(todayWeekday - 1 - (6 - i) + 70) % 7],
    );

    return Row(
      children: List.generate(7, (i) {
        final done = i < days.length && days[i];
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? accentColor
                      : cs.onSurface.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
