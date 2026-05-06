import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/next_wod_result.dart';
import '../../../models/weight_suggestion.dart';
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
        borderRadius: 32,
        enableBlur: false,
        child: const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => LiquidGlassContainer(
        borderRadius: 32,
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

  String get _prefsKey =>
      'workout_progress_${widget.result.wodTemplate.id}';

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
    final lastDone = _lastDoneLabel(widget.result.lastSessionDate);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralTint = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.78);

    return LiquidGlassContainer(
      borderRadius: 22,
      blurSigma: 18,
      tintColor: neutralTint,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NEXT UP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Week ${widget.result.weekNumberInProgram}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        glassRoute(const WeekWodsScreen()),
                      ),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.result.wodTemplate.name,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (lastDone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lastDone,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Exercise list ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                ...widget.result.allExercises
                    .map((entry) => _ExerciseTile(entry: entry)),
                const SizedBox(height: 12),
                if (_hasProgress) ...[
                  // ── Resume row ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _onStartOrResume(resume: true),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Resume Workout'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _onRestart,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(13),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Tooltip(
                          message: 'Restart',
                          child: Icon(Icons.refresh, size: 18),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: _onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(13),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                          side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Tooltip(
                          message: 'Discard',
                          child: Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _onStartOrResume(),
                      icon: const Icon(Icons.fitness_center, size: 18),
                      label: const Text('Start Workout'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final WodExerciseEntry entry;
  const _ExerciseTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    final suggestion = entry.suggestion;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.exercise.name,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  entry.exercise.isTimed
                      ? '${te.targetSets} sets · ${te.repRangeMin} s'
                      : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _SuggestionChip(suggestion: suggestion),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final WeightSuggestion suggestion;
  const _SuggestionChip({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (suggestion.type) {
      case SuggestionType.increase:
        color = Colors.green;
        icon = Icons.trending_up;
      case SuggestionType.decrease:
        color = Colors.orange;
        icon = Icons.trending_down;
      case SuggestionType.maintain:
        color = Theme.of(context).colorScheme.secondary;
        icon = Icons.trending_flat;
      case SuggestionType.noHistory:
        return Text('—', style: Theme.of(context).textTheme.bodySmall);
    }

    final label = suggestion.suggestedKg != null
        ? '${suggestion.suggestedKg!.toStringAsFixed(1)}kg'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
