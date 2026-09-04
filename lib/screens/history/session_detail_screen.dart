import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/session_providers.dart';
import '../../services/personal_record_detection.dart';
import '../../utils/rir_conversion.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/vibrant_text.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Map<int, Exercise> _exerciseMap = {};
  bool _exercisesLoaded = false;
  double? _priorVolume;
  int? _pressedSetId;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final db = ref.read(databaseProvider);
    final exercises = await db.exercisesDao.getAllExercises();
    final prior = await db.setsDao.getVolumeForPriorSession(
      widget.session.workoutName,
      widget.session.date,
    );
    setState(() {
      _exerciseMap = {for (final e in exercises) e.id: e};
      _priorVolume = prior;
      _exercisesLoaded = true;
    });
  }

  void _clearPressed() {
    if (_pressedSetId != null) setState(() => _pressedSetId = null);
  }

  Future<void> _deleteSet(BuildContext ctx, int setId) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Set'),
        content: const Text('Remove this set from the session?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFFF453A)))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).setsDao.deleteSet(setId);
    ref.invalidate(personalRecordsProvider);
    ref.invalidate(allSessionStatsProvider);
    setState(() => _pressedSetId = null);
  }

  void _openEditSheet(BuildContext ctx, WorkoutSet set) {
    final exercise = _exerciseMap[set.exerciseId];
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSetSheet(
        set: set,
        exerciseName: exercise?.name ?? 'Exercise',
        isTimed: exercise?.isTimed ?? false,
        onSaved: () {
          ref.invalidate(personalRecordsProvider);
          ref.invalidate(allSessionStatsProvider);
          ref
              .read(databaseProvider)
              .setsDao
              .getVolumeForPriorSession(
                  widget.session.workoutName, widget.session.date)
              .then((v) {
            if (mounted) setState(() => _priorVolume = v);
          });
        },
        onPersonalRecord: (weightKg, reps, oldWeightKg) async {
          if (!mounted) return;
          HapticFeedback.heavyImpact();
          await showPrOverlay(
            context,
            exerciseName: exercise?.name ?? 'Exercise',
            newWeightKg: weightKg,
            reps: reps,
            oldWeightKg: oldWeightKg,
          );
        },
      ),
    );
    setState(() => _pressedSetId = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final setsAsync = ref.watch(setsForSessionProvider(session.id));
    final dateStr = _formatDate(session.date);

    return GestureDetector(
      onTap: _clearPressed,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.workoutName),
              Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: Stack(
          children: [
            const Positioned.fill(child: GlassBackground()),
            setsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sets) {
                if (!_exercisesLoaded) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sets.isEmpty) {
                  return Center(
                    child: Text(
                      'No sets recorded for this session.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                    ),
                  );
                }
                final groups = _buildGroups(sets);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: groups.length + 2,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final prCount = ref
                              .watch(allSessionStatsProvider)
                              .asData
                              ?.value[session.id]
                              ?.prCount ??
                          0;
                      return _StatsHeader(
                        sets: sets,
                        exerciseMap: _exerciseMap,
                        session: session,
                        priorVolume: _priorVolume,
                        prCount: prCount,
                      );
                    }
                    if (i == 1) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                        child: Text(
                          'Long-press any set to edit or delete',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                  ),
                        ),
                      );
                    }
                    final group = groups[i - 2];
                    return _ExerciseCard(
                      group: group,
                      pressedSetId: _pressedSetId,
                      onLongPress: (id) =>
                          setState(() => _pressedSetId = id),
                      onEdit: (set) => _openEditSheet(context, set),
                      onDelete: (id) => _deleteSet(context, id),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_ExerciseGroup> _buildGroups(List<WorkoutSet> sets) {
    final seen = <int>[];
    final grouped = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      if (!grouped.containsKey(s.exerciseId)) {
        seen.add(s.exerciseId);
        grouped[s.exerciseId] = [];
      }
      grouped[s.exerciseId]!.add(s);
    }
    return seen.map((id) {
      final ex = _exerciseMap[id];
      return _ExerciseGroup(
        exerciseId: id,
        name: ex?.name ?? 'Unknown',
        isTimed: ex?.isTimed ?? false,
        sets: grouped[id]!,
      );
    }).toList();
  }
}

// ─── Stats Header ─────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final List<WorkoutSet> sets;
  final Map<int, Exercise> exerciseMap;
  final WorkoutSession session;
  final double? priorVolume;
  final int prCount;
  const _StatsHeader({
    required this.sets,
    required this.exerciseMap,
    required this.session,
    this.priorVolume,
    required this.prCount,
  });

  @override
  Widget build(BuildContext context) {
    double totalVolume = 0;
    double rirSum = 0;
    int rirCount = 0;
    final exerciseIds = <int>{};
    for (final s in sets) {
      totalVolume += s.weightKg * s.reps;
      final rir = effectiveRir(s.rir, s.rpe);
      if (rir != null) {
        rirSum += rir;
        rirCount++;
      }
      exerciseIds.add(s.exerciseId);
    }
    final avgRir = rirCount > 0 ? rirSum / rirCount : null;

    String? deltaStr;
    Color? deltaColor;
    if (priorVolume != null && priorVolume! > 0 && totalVolume > 0) {
      final pct = (totalVolume - priorVolume!) / priorVolume! * 100;
      if (pct >= 0) {
        deltaStr =
            '↑ +${pct.toStringAsFixed(0)}% vs last ${session.workoutName}';
        deltaColor = const Color(0xFF34C759);
      } else {
        deltaStr =
            '↓ ${pct.toStringAsFixed(0)}% vs last ${session.workoutName}';
        deltaColor = const Color(0xFFFF453A);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          LiquidGlassContainer(
            borderRadius: 16,
            blurSigma: 10,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fmtVol(totalVolume),
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'total volume · kg',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.45)),
                      ),
                      if (deltaStr != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          deltaStr,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: deltaColor),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _SmallStat(label: 'SETS', value: '${sets.length}'),
              _SmallStat(
                  label: 'AVG RIR',
                  value: avgRir != null ? fmtRir(avgRir) : '—'),
              _SmallStat(
                  label: 'PRs',
                  value: prCount > 0 ? '🏆 $prCount' : '—'),
              _SmallStat(
                  label: 'EXERCISES', value: '${exerciseIds.length}'),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtVol(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.45),
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exercise group / set rows ────────────────────────────────────────────────

class _ExerciseGroup {
  final int exerciseId;
  final String name;
  final bool isTimed;
  final List<WorkoutSet> sets;
  _ExerciseGroup({
    required this.exerciseId,
    required this.name,
    required this.isTimed,
    required this.sets,
  });
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseGroup group;
  final int? pressedSetId;
  final void Function(int setId) onLongPress;
  final void Function(WorkoutSet set) onEdit;
  final void Function(int setId) onDelete;
  const _ExerciseCard({
    required this.group,
    required this.pressedSetId,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VibrantText(
                group.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...group.sets.map((s) => _SetRow(
                    set: s,
                    isTimed: group.isTimed,
                    isPressed: pressedSetId == s.id,
                    onLongPress: () => onLongPress(s.id),
                    onEdit: () => onEdit(s),
                    onDelete: () => onDelete(s.id),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final WorkoutSet set;
  final bool isTimed;
  final bool isPressed;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SetRow({
    required this.set,
    required this.isTimed,
    required this.isPressed,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    const red = Color(0xFFFF453A);

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPressed ? indigo.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                'Set ${set.setNumber}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
              ),
            ),
            Expanded(
              child: isTimed
                  ? Text(_fmtSec(set.durationSeconds ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600))
                  : Row(
                      children: [
                        Text('${_fmtW(set.weightKg)} kg',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('×',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 8),
                        Text('${set.reps} reps',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (effectiveRir(set.rir, set.rpe) != null) ...[
                          const SizedBox(width: 8),
                          RirPill(rir: effectiveRir(set.rir, set.rpe)!),
                        ],
                      ],
                    ),
            ),
            if (isPressed) ...[
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    foregroundColor: indigo),
                child: const Text('Edit',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    foregroundColor: red),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Edit Set Bottom Sheet ────────────────────────────────────────────────────

class _EditSetSheet extends ConsumerStatefulWidget {
  final WorkoutSet set;
  final String exerciseName;
  final bool isTimed;
  final VoidCallback onSaved;
  final Future<void> Function(double weightKg, int reps, double? oldWeightKg) onPersonalRecord;
  const _EditSetSheet({
    required this.set,
    required this.exerciseName,
    required this.isTimed,
    required this.onSaved,
    required this.onPersonalRecord,
  });

  @override
  ConsumerState<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends ConsumerState<_EditSetSheet> {
  late double _weight;
  late int _reps;
  late int _durationSeconds;
  // Slider always holds a valid 0..5 value; [_rirSet] tracks whether the
  // user has actually recorded an RIR (distinguishes "not recorded" from
  // the legitimate RIR value 0 = failure).
  late double _rir;
  late bool _rirSet;
  late TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.set.weightKg;
    _reps = widget.set.reps;
    _durationSeconds = widget.set.durationSeconds ?? 0;
    final initialRir = effectiveRir(widget.set.rir, widget.set.rpe);
    _rir = initialRir ?? 2.0;
    _rirSet = initialRir != null;
    _notesCtrl = TextEditingController(text: widget.set.notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final changedWeightOrReps = !widget.isTimed &&
        (!sameRecordWeight(_weight, widget.set.weightKg) ||
            _reps != widget.set.reps);
    final oldPrKg = changedWeightOrReps
        ? await db.setsDao.getPersonalRecord(widget.set.exerciseId)
        : null;
    final oldBestReps = oldPrKg != null && oldPrKg > 0
        ? await db.setsDao.getBestRepsAtWeight(widget.set.exerciseId, oldPrKg)
        : 0;
    final prResult = changedWeightOrReps
        ? evaluateWeightPersonalRecord(
            currentTopWeightKg: oldPrKg,
            bestRepsAtCurrentTopWeight: oldBestReps,
            weightKg: _weight,
            reps: _reps,
          )
        : PersonalRecordAttemptResult.none;

    await db.setsDao.updateSet(WorkoutSetsCompanion(
          id: Value(widget.set.id),
          sessionId: Value(widget.set.sessionId),
          exerciseId: Value(widget.set.exerciseId),
          setNumber: Value(widget.set.setNumber),
          reps: Value(_reps),
          weightKg: Value(_weight),
          durationSeconds: Value(
              widget.isTimed ? _durationSeconds : widget.set.durationSeconds),
          // Dual-write for one release: rir is the source of truth, rpe is
          // derived so legacy code paths/exports still see a valid value.
          rir: Value(_rirSet ? _rir : null),
          rpe: Value(_rirSet ? rpeFromRir(_rir) : null),
          notes: Value(_notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim()),
        ));
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
    if (prResult.isPersonalRecord) {
      await widget.onPersonalRecord(_weight, _reps, oldPrKg);
    }
  }

  Widget _stepper({
    required String label,
    required String display,
    required VoidCallback onDec,
    required VoidCallback onInc,
    String? unit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                  letterSpacing: 0.5),
            ),
          ),
          IconButton(
            onPressed: onDec,
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(display,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(unit,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
          ],
          const SizedBox(width: 12),
          IconButton(
            onPressed: onInc,
            icon: const Icon(Icons.add_circle_outline, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final subtitle = 'Set ${widget.set.setNumber}';
    final bool saveEnabled =
        widget.isTimed ? _durationSeconds > 0 : (_weight > 0 && _reps > 0);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Edit Set · ${widget.exerciseName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.45)),
          ),
          const Divider(height: 24),
          if (!widget.isTimed)
            _stepper(
              label: 'WEIGHT',
              display: _weight == _weight.roundToDouble()
                  ? _weight.toInt().toString()
                  : _weight.toStringAsFixed(1),
              unit: 'kg',
              onDec: () =>
                  setState(() => _weight = (_weight - 0.5).clamp(0.0, 9999.0)),
              onInc: () =>
                  setState(() => _weight = (_weight + 0.5).clamp(0.0, 9999.0)),
            ),
          if (!widget.isTimed)
            _stepper(
              label: 'REPS',
              display: '$_reps',
              onDec: () => setState(() => _reps = (_reps - 1).clamp(0, 9999)),
              onInc: () => setState(() => _reps = (_reps + 1).clamp(0, 9999)),
            )
          else
            _stepper(
              label: 'DURATION',
              display: _fmtSec(_durationSeconds),
              onDec: () => setState(() =>
                  _durationSeconds = (_durationSeconds - 5).clamp(0, 99999)),
              onInc: () => setState(() =>
                  _durationSeconds = (_durationSeconds + 5).clamp(0, 99999)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'RIR',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.5),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _rir,
                    min: 0.0,
                    max: 5.0,
                    divisions: 10,
                    activeColor: rirColor(_rir),
                    onChanged: (v) => setState(() {
                      _rir = v;
                      _rirSet = true;
                    }),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    _rirSet ? fmtRir(_rir) : '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: rirColor(_rir)),
                  ),
                ),
              ],
            ),
          ),
          if (_rirSet)
            GestureDetector(
              onTap: () => setState(() => _rirSet = false),
              child: Text(
                'Clear RIR',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
              labelText: 'Notes',
              labelStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (saveEnabled && !_saving) ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
