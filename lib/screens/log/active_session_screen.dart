import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../models/next_wod_result.dart';
import '../../models/weight_suggestion.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../widgets/celebration_overlay.dart';

// ─── Local data model ──────────────────────────────────────────────────────────

class _SetData {
  double weightKg;
  int reps;
  _SetData({required this.weightKg, required this.reps});
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final NextWodResult result;
  const ActiveSessionScreen({super.key, required this.result});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  final Map<int, List<_SetData>> _setData = {};
  final Map<int, List<WorkoutSet>> _lastSets = {};
  final Map<int, double?> _prData = {};
  int _expandedIndex = 0; // which exercise card is open
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final wodId = widget.result.wodTemplate.id;

    for (final entry in widget.result.exercises) {
      final te = entry.templateExercise;
      final exerciseId = te.exerciseId;
      final lastSets =
          await db.setsDao.getLastSetsForExerciseInWod(exerciseId, wodId);
      _lastSets[exerciseId] = lastSets;
      _prData[exerciseId] = await db.setsDao.getPersonalRecord(exerciseId);

      // All sets start blank — values are filled in on first stepper press
      _setData[exerciseId] = List.generate(
        te.targetSets,
        (_) => _SetData(weightKg: 0, reps: 0),
      );
    }
    setState(() => _loading = false);
  }

  void _onSetChanged(int exerciseId, int setIndex, _SetData data) {
    setState(() => _setData[exerciseId]![setIndex] = data);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final wod = widget.result.wodTemplate;

    final sessionId = await db.sessionsDao.insertSession(
      WorkoutSessionsCompanion.insert(
        date: DateTime.now(),
        workoutName: wod.name,
        wodTemplateId: Value(wod.id),
        weekNumber: Value(widget.result.weekNumberInProgram),
      ),
    );

    for (final entry in widget.result.exercises) {
      final exerciseId = entry.templateExercise.exerciseId;
      final sets = _setData[exerciseId] ?? [];
      // Skip sets the user never filled in (still at 0 reps)
      final filledSets = sets.where((s) => s.reps > 0).toList();
      for (int i = 0; i < filledSets.length; i++) {
        await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: i + 1,
          reps: filledSets[i].reps,
          weightKg: filledSets[i].weightKg,
        ));
      }
    }

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);
    if (mounted) {
      await showWorkoutCompleteOverlay(context, wod.name);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.result.exercises;

    final totalExercises = exercises.length;
    final progressValue = totalExercises == 0
        ? 0.0
        : (_expandedIndex + 1) / totalExercises;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.result.wodTemplate.name),
            Text(
              'Week ${widget.result.weekNumberInProgram} · Exercise ${_expandedIndex + 1} of $totalExercises',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 4,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12),
          ),
        ),
      ),
      // Sticky Finish button at the bottom — always visible
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _finish,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: const Text('Finish Workout'),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: exercises.length,
              itemBuilder: (_, i) {
                final entry = exercises[i];
                final exerciseId = entry.templateExercise.exerciseId;
                final isExpanded = _expandedIndex == i;
                return _ExerciseSection(
                  key: ValueKey(exerciseId),
                  entry: entry,
                  sets: _setData[exerciseId] ?? [],
                  lastSets: _lastSets[exerciseId] ?? [],
                  prKg: _prData[exerciseId],
                  isExpanded: isExpanded,
                  isLast: i == exercises.length - 1,
                  onSetChanged: (setIndex, data) =>
                      _onSetChanged(exerciseId, setIndex, data),
                  onDone: () => setState(() {
                    if (i < exercises.length - 1) {
                      _expandedIndex = i + 1;
                    }
                  }),
                  onExpand: () => setState(() => _expandedIndex = i),
                );
              },
            ),
    );
  }
}

// ─── Exercise section (expanded / collapsed) ───────────────────────────────────

class _ExerciseSection extends StatelessWidget {
  final WodExerciseEntry entry;
  final List<_SetData> sets;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final bool isExpanded;
  final bool isLast;
  final void Function(int setIndex, _SetData data) onSetChanged;
  final VoidCallback onDone;
  final VoidCallback onExpand;

  const _ExerciseSection({
    super.key,
    required this.entry,
    required this.sets,
    required this.lastSets,
    required this.prKg,
    required this.isExpanded,
    required this.isLast,
    required this.onSetChanged,
    required this.onDone,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isExpanded
          ? _ExpandedCard(
              entry: entry,
              sets: sets,
              lastSets: lastSets,
              prKg: prKg,
              isLast: isLast,
              onSetChanged: onSetChanged,
              onDone: onDone,
            )
          : _CollapsedTile(
              entry: entry,
              sets: sets,
              onExpand: onExpand,
            ),
    );
  }
}

// ─── Expanded card ─────────────────────────────────────────────────────────────

class _ExpandedCard extends StatelessWidget {
  final WodExerciseEntry entry;
  final List<_SetData> sets;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final bool isLast;
  final void Function(int setIndex, _SetData data) onSetChanged;
  final VoidCallback onDone;

  const _ExpandedCard({
    required this.entry,
    required this.sets,
    required this.lastSets,
    required this.prKg,
    required this.isLast,
    required this.onSetChanged,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;

    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar for active exercise
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.exercise.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _SuggestionBadge(suggestion: entry.suggestion),
              ],
            ),
            const SizedBox(height: 14),
            // Set rows — keyed by index so Flutter never mixes up state
            ...sets.asMap().entries.map((e) {
                  final i = e.key;
                  // Reference for first set: suggestion weight + last session reps
                  // Reference for subsequent sets: the previous set's current values
                  final _SetData refData;
                  if (i == 0) {
                    refData = _SetData(
                      weightKg: entry.suggestion.suggestedKg ?? 0.0,
                      reps: lastSets.isNotEmpty
                          ? lastSets[0].reps
                          : te.repRangeMax,
                    );
                  } else {
                    refData = sets[i - 1];
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SetRow(
                      key: ValueKey('set-${te.exerciseId}-$i'),
                      setNumber: i + 1,
                      data: e.value,
                      referenceData: refData,
                      onChanged: (data) => onSetChanged(i, data),
                    ),
                  );
                }),
            const Divider(height: 20),
            // Stats + Next Exercise row
            Row(
              children: [
                _ExerciseStats(lastSets: lastSets, prKg: prKg),
                if (!isLast)
                  TextButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: const Text('Next Exercise'),
                  ),
              ],
            ),
          ],
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exercise stats (last best + PR) ───────────────────────────────────────────

class _ExerciseStats extends StatelessWidget {
  final List<WorkoutSet> lastSets;
  final double? prKg;

  const _ExerciseStats({required this.lastSets, required this.prKg});

  @override
  Widget build(BuildContext context) {
    // Best set from last session: highest weight, tie-break by reps
    WorkoutSet? bestLast;
    for (final s in lastSets) {
      if (bestLast == null ||
          s.weightKg > bestLast.weightKg ||
          (s.weightKg == bestLast.weightKg && s.reps > bestLast.reps)) {
        bestLast = s;
      }
    }
    final lastStr = bestLast != null && bestLast.weightKg > 0
        ? '${_fmtW(bestLast.weightKg)}×${bestLast.reps}'
        : '--';
    final prStr =
        prKg != null && prKg! > 0 ? '${_fmtW(prKg!)} kg' : '--';

    final dim = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45));

    return Expanded(
      child: Row(
        children: [
          _StatChip(label: 'Last', value: lastStr, style: dim),
          const SizedBox(width: 12),
          _StatChip(label: 'PR', value: prStr, style: dim),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;
  const _StatChip({required this.label, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$label  ',
            style: style?.copyWith(
              color: style?.color?.withValues(alpha: 0.6),
            ),
          ),
          TextSpan(
            text: value,
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Collapsed tile ────────────────────────────────────────────────────────────

class _CollapsedTile extends StatelessWidget {
  final WodExerciseEntry entry;
  final List<_SetData> sets;
  final VoidCallback onExpand;

  const _CollapsedTile({
    required this.entry,
    required this.sets,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final summary = sets.isEmpty
        ? '—'
        : sets.map((s) => '${_fmtW(s.weightKg)}×${s.reps}').join('  ');

    return Card(
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.exercise.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.expand_more,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Set input row ─────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final int setNumber;
  final _SetData data;
  // On the very first stepper press, snap to this value instead of incrementing
  final _SetData referenceData;
  final void Function(_SetData) onChanged;

  const _SetRow({
    super.key,
    required this.setNumber,
    required this.data,
    required this.referenceData,
    required this.onChanged,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  // True once the user has interacted with any stepper on this set
  bool _initialized = false;
  bool _editingWeight = false;
  bool _editingReps = false;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController();
    _repsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  // On first press: snap to reference. On subsequent presses: normal delta.
  void _handleWeight(double delta) {
    if (!_initialized) {
      _initialized = true;
      widget.onChanged(widget.referenceData);
    } else {
      widget.onChanged(_SetData(
        weightKg: (widget.data.weightKg + delta).clamp(0.0, double.infinity),
        reps: widget.data.reps,
      ));
    }
  }

  void _handleReps(int delta) {
    if (!_initialized) {
      _initialized = true;
      widget.onChanged(widget.referenceData);
    } else {
      widget.onChanged(_SetData(
        weightKg: widget.data.weightKg,
        reps: (widget.data.reps + delta).clamp(1, 999),
      ));
    }
  }

  void _commitWeight() {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (v != null && v >= 0) {
      _initialized = true;
      widget.onChanged(_SetData(weightKg: v, reps: widget.data.reps));
    }
    if (mounted) setState(() => _editingWeight = false);
  }

  void _commitReps() {
    final v = int.tryParse(_repsCtrl.text);
    if (v != null && v >= 1) {
      _initialized = true;
      widget.onChanged(_SetData(weightKg: widget.data.weightKg, reps: v));
    }
    if (mounted) setState(() => _editingReps = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            'Set ${widget.setNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ),
        Expanded(
          child: _StepperField(
            label: _editingWeight ? null : '${_fmtW(widget.data.weightKg)} kg',
            editingController: _editingWeight ? _weightCtrl : null,
            onDecrement: () => _handleWeight(-2.5),
            onIncrement: () => _handleWeight(2.5),
            onTapValue: () => setState(() {
              _weightCtrl.text = _fmtW(widget.data.weightKg);
              _weightCtrl.selection = TextSelection(
                  baseOffset: 0, extentOffset: _weightCtrl.text.length);
              _editingWeight = true;
              _editingReps = false;
            }),
            onCommit: _commitWeight,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StepperField(
            label: _editingReps ? null : '${widget.data.reps} reps',
            editingController: _editingReps ? _repsCtrl : null,
            isInteger: true,
            onDecrement: () => _handleReps(-1),
            onIncrement: () => _handleReps(1),
            onTapValue: () => setState(() {
              _repsCtrl.text = widget.data.reps.toString();
              _repsCtrl.selection = TextSelection(
                  baseOffset: 0, extentOffset: _repsCtrl.text.length);
              _editingReps = true;
              _editingWeight = false;
            }),
            onCommit: _commitReps,
          ),
        ),
      ],
    );
  }
}

// ─── Stepper field ─────────────────────────────────────────────────────────────

class _StepperField extends StatelessWidget {
  final String? label;
  final TextEditingController? editingController;
  final bool isInteger;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapValue;
  final VoidCallback onCommit;

  const _StepperField({
    this.label,
    this.editingController,
    this.isInteger = false,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTapValue,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBtn(icon: Icons.remove, onTap: onDecrement),
        Expanded(
          child: editingController != null
              ? TextField(
                  controller: editingController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: !isInteger,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  ),
                  onSubmitted: (_) => onCommit(),
                  onTapOutside: (_) => onCommit(),
                )
              : GestureDetector(
                  onTap: onTapValue,
                  child: Text(
                    label ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
        ),
        _StepBtn(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Suggestion badge ──────────────────────────────────────────────────────────

class _SuggestionBadge extends StatelessWidget {
  final WeightSuggestion suggestion;
  const _SuggestionBadge({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    if (suggestion.type == SuggestionType.noHistory) {
      return const SizedBox.shrink();
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
      case SuggestionType.noHistory:
        color = Theme.of(context).colorScheme.secondary;
        icon = Icons.trending_flat;
    }
    final kg = suggestion.suggestedKg != null
        ? '${_fmtW(suggestion.suggestedKg!)} kg'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (kg.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(kg,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
