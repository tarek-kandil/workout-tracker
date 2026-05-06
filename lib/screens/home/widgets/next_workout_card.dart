import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/next_wod_result.dart';
import '../../../providers/next_workout_provider.dart';
import '../../../widgets/liquid_glass_container.dart';
import '../../../widgets/glass_route.dart';
import '../../log/active_session_screen.dart';
import '../week_wods_screen.dart';

String _lastDoneLabel(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Last done: today';
  if (diff == 1) return 'Last done: yesterday';
  return 'Last done: ${diff}d ago';
}

String _exerciseMeta(NextWodResult result) {
  final count = result.allExercises.length;
  return '$count exercise${count == 1 ? '' : 's'}';
}

class NextWorkoutCard extends ConsumerWidget {
  const NextWorkoutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextWodAsync = ref.watch(nextWodProvider);

    return nextWodAsync.when(
      loading: () => LiquidGlassContainer(
        borderRadius: 28,
        enableBlur: false,
        child: const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => LiquidGlassContainer(
        borderRadius: 28,
        enableBlur: false,
        child: Text('Could not load next workout: $e'),
      ),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        return _NextWodContent(result: result);
      },
    );
  }
}

class _NextWodContent extends ConsumerStatefulWidget {
  final NextWodResult result;
  const _NextWodContent({required this.result});

  @override
  ConsumerState<_NextWodContent> createState() => _NextWodContentState();
}

class _NextWodContentState extends ConsumerState<_NextWodContent> {
  bool _hasProgress = false;

  String get _prefsKey => 'workout_progress_${widget.result.wodTemplate.id}';

  @override
  void initState() {
    super.initState();
    _checkProgress();
  }

  Future<void> _checkProgress() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _hasProgress = prefs.containsKey(_prefsKey));
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _onStartOrResume({bool resume = false}) async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(glassRoute(
      ActiveSessionScreen(result: widget.result, autoResume: resume),
    ));
    _checkProgress();
  }

  Future<void> _onRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Workout?'),
        content: const Text('Your saved progress will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restart')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearProgress();
      await _onStartOrResume();
    }
  }

  Future<void> _onCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('Your saved progress will be discarded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearProgress();
      setState(() => _hasProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lastDone = _lastDoneLabel(widget.result.lastSessionDate);
    final meta = _exerciseMeta(widget.result);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.80);

    return LiquidGlassContainer(
      borderRadius: 28,
      blurSigma: 10,
      tintColor: tint,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row ─────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                'UP NEXT  ·  WEEK ${widget.result.weekNumberInProgram}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(glassRoute(const WeekWodsScreen())),
                child: Icon(
                  Icons.swap_vert_rounded,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Workout name ──────────────────────────────────────────────────
          Text(
            widget.result.wodTemplate.name,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),

          // ── Meta row ──────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                meta,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              if (lastDone.isNotEmpty) ...[
                Text(
                  '  ·  ',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.25)),
                ),
                Text(
                  lastDone,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── Action buttons ────────────────────────────────────────────────
          if (_hasProgress) ...[
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    onPressed: () => _onStartOrResume(resume: true),
                    icon: Icons.play_arrow_rounded,
                    label: 'Resume Workout',
                  ),
                ),
                const SizedBox(width: 8),
                _IconPillButton(
                  onPressed: _onRestart,
                  icon: Icons.refresh_rounded,
                  tooltip: 'Restart',
                ),
                const SizedBox(width: 6),
                _IconPillButton(
                  onPressed: _onCancel,
                  icon: Icons.close_rounded,
                  tooltip: 'Discard',
                  color: cs.error,
                ),
              ],
            ),
          ] else ...[
            _PillButton(
              onPressed: () => _onStartOrResume(),
              icon: Icons.fitness_center_rounded,
              label: 'Start Workout',
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared button widgets ─────────────────────────────────────────────────────

class _PillButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool fullWidth;

  const _PillButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
    if (fullWidth) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}

class _IconPillButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final Color? color;

  const _IconPillButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.onSurface;
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(14),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: effectiveColor,
          side: BorderSide(color: effectiveColor.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
