import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const emerald = Color(0xFF34D399);
    const sky = Color(0xFF0EA5E9);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  Colors.white.withValues(alpha: 0.06),
                  sky.withValues(alpha: 0.14),
                ]
              : [
                  Colors.white.withValues(alpha: 0.90),
                  sky.withValues(alpha: 0.10),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.11)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row: ● WEEK N pill + Switch pill ───────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: emerald.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: emerald,
                        boxShadow: [
                          BoxShadow(
                            color: emerald.withValues(alpha: 0.85),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'WEEK ${widget.result.weekNumberInProgram}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(glassRoute(const WeekWodsScreen())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.70),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Switch',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Body: Title + Last done on left, Side-Launch CTA on right ─────
          if (_hasProgress) ...[
            Text(
              widget.result.wodTemplate.name,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (lastDone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                lastDone,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
            const SizedBox(height: 14),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.result.wodTemplate.name,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                      ),
                      if (lastDone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lastDone,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.56),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SideLaunchButton(
                  onPressed: () => _onStartOrResume(),
                  label: 'Start',
                ),
              ],
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

  const _PillButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF0EA5E9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34D399).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: const Color(0xFF06131A)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF06131A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideLaunchButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _SideLaunchButton({
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF0EA5E9)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34D399).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF06131A),
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF06131A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
