import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/next_wod_result.dart';
import '../../../models/weight_suggestion.dart';
import '../../../providers/next_workout_provider.dart';
import '../../log/active_session_screen.dart';

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
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load next workout: $e'),
        ),
      ),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        return _NextWodContent(result: result);
      },
    );
  }
}

class _NextWodContent extends ConsumerWidget {
  final NextWodResult result;
  const _NextWodContent({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phaseLabel = result.totalPhases > 1 ? ' · ${result.phase.name}' : '';
    final accent = Theme.of(context).colorScheme.primary;
    final lastDone = _lastDoneLabel(result.lastSessionDate);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero gradient header ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NEXT UP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Week ${result.weekNumberInProgram}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.wodTemplate.name + phaseLabel,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (lastDone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lastDone,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                  ),
                ],
              ],
            ),
          ),
          // ── Exercise list ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                ...result.exercises.map((entry) => _ExerciseTile(entry: entry)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActiveSessionScreen(result: result),
                      ),
                    ),
                    icon: const Icon(Icons.fitness_center, size: 18),
                    label: const Text('Start Workout'),
                  ),
                ),
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
                  '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
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
        return Text('—',
            style: Theme.of(context).textTheme.bodySmall);
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
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
