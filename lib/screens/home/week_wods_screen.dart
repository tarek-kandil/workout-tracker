import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/next_wod_result.dart';
import '../../models/weight_suggestion.dart';
import '../../models/wod_item.dart';
import '../../providers/next_workout_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../log/active_session_screen.dart';

String _lastDoneLabel(DateTime? date) {
  if (date == null) return 'Never done';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Done today';
  if (diff == 1) return 'Done yesterday';
  return 'Done ${diff}d ago';
}

class WeekWodsScreen extends ConsumerStatefulWidget {
  const WeekWodsScreen({super.key});

  @override
  ConsumerState<WeekWodsScreen> createState() => _WeekWodsScreenState();
}

class _WeekWodsScreenState extends ConsumerState<WeekWodsScreen> {
  int? _selectedWodId;
  final Map<int, bool> _hasProgress = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final wods = await ref.read(allCurrentPhaseWodsProvider.future);
    if (!mounted) return;
    setState(() {
      for (final r in wods) {
        _hasProgress[r.wodTemplate.id] =
            prefs.containsKey('workout_progress_${r.wodTemplate.id}');
      }
    });
  }

  Future<void> _startWod(NextWodResult result, {bool resume = false}) async {
    HapticFeedback.mediumImpact();
    await Navigator.of(context).push(
      glassRoute(ActiveSessionScreen(result: result, autoResume: resume)),
    );
    _loadProgress();
  }

  Future<void> _discardProgress(int wodId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Progress?'),
        content: const Text('Your saved progress for this workout will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('workout_progress_$wodId');
    setState(() => _hasProgress[wodId] = false);
  }

  @override
  Widget build(BuildContext context) {
    final allWodsAsync = ref.watch(allCurrentPhaseWodsProvider);
    final recommendedAsync = ref.watch(nextWodProvider);
    final recommendedId = recommendedAsync.valueOrNull?.wodTemplate.id;

    return allWodsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('This Week')),
        body: Stack(children: [
          const Positioned.fill(child: GlassBackground()),
          const Center(child: CircularProgressIndicator()),
        ]),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('This Week')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (wods) {
        if (wods.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('This Week')),
            body: Stack(children: [
              const Positioned.fill(child: GlassBackground()),
              const Center(child: Text('No workouts configured.')),
            ]),
          );
        }

        final selectedId = _selectedWodId ?? recommendedId ?? wods.first.wodTemplate.id;
        final selected = wods.firstWhere(
          (r) => r.wodTemplate.id == selectedId,
          orElse: () => wods.first,
        );
        final selectedHasProgress = _hasProgress[selectedId] ?? false;
        final rec = wods.first; // for header title

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.program.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'Week ${rec.weekNumberInProgram} of ${rec.totalProgramWeeks}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: GlassBackground()),
              // WOD list
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: wods.length,
                itemBuilder: (_, i) {
                  final r = wods[i];
                  final isRecommended = r.wodTemplate.id == recommendedId;
                  final isSelected = r.wodTemplate.id == selectedId;
                  final hasProgress = _hasProgress[r.wodTemplate.id] ?? false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WodTile(
                      result: r,
                      isRecommended: isRecommended,
                      isSelected: isSelected,
                      hasProgress: hasProgress,
                      onTap: () => setState(
                          () => _selectedWodId = r.wodTemplate.id),
                    ),
                  );
                },
              ),
              // Bottom action bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: selectedHasProgress
                      ? Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _startWod(selected, resume: true),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: Text(
                                    'Resume ${selected.wodTemplate.name}',
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  _discardProgress(selectedId),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(13),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                foregroundColor:
                                    Theme.of(context).colorScheme.error,
                                side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _startWod(selected),
                            icon: Icon(
                              selected.wodTemplate.id == recommendedId
                                  ? Icons.fitness_center
                                  : Icons.shuffle,
                              size: 18,
                            ),
                            label: Text('Start ${selected.wodTemplate.name}'),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── WOD Tile ──────────────────────────────────────────────────────────────────

class _WodTile extends StatelessWidget {
  final NextWodResult result;
  final bool isRecommended;
  final bool isSelected;
  final bool hasProgress;
  final VoidCallback onTap;

  const _WodTile({
    required this.result,
    required this.isRecommended,
    required this.isSelected,
    required this.hasProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0x26000000)
            : const Color(0x14000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.07),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  result.wodTemplate.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                              ),
                              if (isRecommended) ...[
                                const SizedBox(width: 8),
                                _Badge(
                                    label: 'NEXT', color: accent),
                              ],
                              if (hasProgress) ...[
                                const SizedBox(width: 6),
                                _Badge(
                                    label: 'IN PROGRESS',
                                    color: Colors.orange),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${result.allExercises.length} exercise${result.allExercises.length == 1 ? '' : 's'}  ·  ${_lastDoneLabel(result.lastSessionDate)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.45),
                                ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isSelected ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_down,
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
                // ── Item list (expanded) ────────────────────────────────────
                if (isSelected && result.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: 12),
                  ...result.items.map((item) => switch (item) {
                        StandaloneWodExercise(:final entry) =>
                          _ExerciseRow(entry: entry),
                        WodCircuit() => _CircuitBlock(circuit: item),
                      }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Exercise row ───────────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  final WodExerciseEntry entry;
  const _ExerciseRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.exercise.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(
                  entry.exercise.isTimed
                      ? '${te.targetSets} sets · ${te.repRangeMin}s'
                      : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
          _SuggestionChip(suggestion: entry.suggestion),
        ],
      ),
    );
  }
}

// ── Circuit block ──────────────────────────────────────────────────────────────

class _CircuitBlock extends StatelessWidget {
  final WodCircuit circuit;
  const _CircuitBlock({required this.circuit});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.loop, size: 13, color: accent),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    circuit.name != null && circuit.name!.isNotEmpty
                        ? circuit.name!
                        : 'Circuit',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 0.3),
                  ),
                ),
                Text(
                  '${circuit.rounds} rounds${circuit.restBetweenRoundsSeconds > 0 ? ' · ${circuit.restBetweenRoundsSeconds}s rest' : ''}',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.35)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...circuit.exercises.map((e) => _ExerciseRow(entry: e)),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion chip ────────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final WeightSuggestion suggestion;
  const _SuggestionChip({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    if (suggestion.type == SuggestionType.noHistory) {
      return Text('—', style: Theme.of(context).textTheme.bodySmall);
    }

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
        color = Colors.white;
        icon = Icons.remove;
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
