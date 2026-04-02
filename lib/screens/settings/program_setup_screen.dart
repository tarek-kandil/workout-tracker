import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/vibrant_text.dart';
import 'wod_exercise_setup_screen.dart';
import 'wod_setup_screen.dart';

class ProgramSetupScreen extends ConsumerStatefulWidget {
  final Program? existingProgram;
  const ProgramSetupScreen({super.key, this.existingProgram});

  @override
  ConsumerState<ProgramSetupScreen> createState() =>
      _ProgramSetupScreenState();
}

class _ProgramSetupScreenState extends ConsumerState<ProgramSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _durationCtrl;
  int? _phaseId;
  bool _saving = false;
  bool _readOnly = false;

  bool get _isEditing => widget.existingProgram != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existingProgram?.name ?? '');
    _durationCtrl = TextEditingController(text: '12');
    _readOnly = _isEditing;
    if (_isEditing) _loadPhaseId();
  }

  Future<void> _loadPhaseId() async {
    final db = ref.read(databaseProvider);
    final phases =
        await db.programsDao.getPhasesForProgram(widget.existingProgram!.id);
    if (phases.isNotEmpty && mounted) {
      setState(() {
        _phaseId = phases.first.id;
        _durationCtrl.text = phases.first.durationWeeks.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    final weeks = int.tryParse(_durationCtrl.text.trim()) ?? 12;

    if (_isEditing) {
      await db.programsDao.updateProgram(ProgramsCompanion(
        id: Value(widget.existingProgram!.id),
        name: Value(_nameCtrl.text.trim()),
        status: Value(widget.existingProgram!.status),
      ));
      if (_phaseId != null) {
        await db.programsDao.updatePhase(ProgramPhasesCompanion(
          id: Value(_phaseId!),
          programId: Value(widget.existingProgram!.id),
          phaseNumber: const Value(1),
          name: const Value('Main'),
          durationWeeks: Value(weeks),
        ));
        ref.invalidate(currentProgramWeekProvider);
      }
      ref.invalidate(allProgramsProvider);
      ref.invalidate(activeProgramProvider);
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    } else {
      // New program — create as draft (status = 2) with one hidden phase
      final programId = await db.programsDao.insertProgram(ProgramsCompanion(
        name: Value(_nameCtrl.text.trim()),
        status: const Value(2),
      ));
      final phaseId = await db.programsDao.insertPhase(ProgramPhasesCompanion(
        programId: Value(programId),
        phaseNumber: const Value(1),
        name: const Value('Main'),
        durationWeeks: Value(weeks),
      ));
      ref.invalidate(allProgramsProvider);
      ref.invalidate(activeProgramProvider);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          glassRoute(WodSetupScreen(phaseId: phaseId)),
        );
      }
    }
  }

  Future<void> _activate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activate Program?'),
        content: const Text(
            'This will set this program as active. Any currently active program will be deactivated.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Activate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    final allPrograms = await db.programsDao.getAllPrograms();
    for (final p in allPrograms) {
      if (p.status == 0) {
        await db.programsDao.updateProgramStatus(p.id, 2);
      }
    }
    await db.programsDao.updateProgramStatus(widget.existingProgram!.id, 0);

    ref.invalidate(allProgramsProvider);
    ref.invalidate(activeProgramProvider);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Program?'),
        content: Text(
            'This will delete all logged sessions and sets for '
            '"${widget.existingProgram!.name}". '
            'Your program setup (exercises and workouts) is kept. '
            'Progress resets to Week 1, WOD 1. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    final sessions = await db.sessionsDao
        .getSessionsForProgram(widget.existingProgram!.id);
    for (final session in sessions) {
      await db.setsDao.deleteSetsForSession(session.id);
      await db.sessionsDao.deleteSession(session.id);
    }

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program restarted — back to Week 1.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _isEditing
        ? widget.existingProgram!.name
        : 'New Program';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_readOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => setState(() => _readOnly = false),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // ── Active program banner ──────────────────────────────
                if (_isEditing && widget.existingProgram!.status == 0) ...[
                  LiquidGlassContainer(
                    borderRadius: 14,
                    blurSigma: 8,
                    tintColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Currently Active Program',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Program name (edit mode only — title is in AppBar) ─
                if (!_readOnly) ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Program Name',
                      hintText: 'e.g. 12-Week PPL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Duration ──────────────────────────────────────────
                if (_readOnly && _phaseId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 8),
                        Text(
                          '${_durationCtrl.text} weeks',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  )
                else if (!_readOnly) ...[
                  TextFormField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      hintText: 'e.g. 12',
                      border: OutlineInputBorder(),
                      suffixText: 'weeks',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Min 1 week';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Workouts section ───────────────────────────────────
                Row(
                  children: [
                    Text('Workouts',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (!_readOnly && _phaseId != null)
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            glassRoute(WodSetupScreen(phaseId: _phaseId!)),
                          );
                          ref.invalidate(
                              wodTemplatesForPhaseProvider(_phaseId!));
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Workouts'),
                      ),
                  ],
                ),
                if (_phaseId != null)
                  _WodList(phaseId: _phaseId!, readOnly: _readOnly)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Save the program first to add workouts.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                    ),
                  ),

                // ── Activate button (draft programs) ───────────────────
                if (_isEditing && widget.existingProgram!.status == 2) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _activate,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Activate This Program'),
                  ),
                ],

                // ── Restart button (active programs) ───────────────────
                if (_isEditing && widget.existingProgram!.status == 0) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restart Program'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.5)),
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

// ── WOD list ──────────────────────────────────────────────────────────────────

class _WodList extends ConsumerWidget {
  final int phaseId;
  final bool readOnly;
  const _WodList({required this.phaseId, required this.readOnly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wodsAsync = ref.watch(wodTemplatesForPhaseProvider(phaseId));
    return wodsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (wods) {
        if (wods.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              readOnly
                  ? 'No workouts in this program.'
                  : 'No workouts yet — tap "Edit Workouts" to add.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
            ),
          );
        }
        return Column(
          children: [
            const SizedBox(height: 8),
            ...wods.map((wod) => _WodTile(
                  key: ValueKey(wod.id),
                  wod: wod,
                  readOnly: readOnly,
                )),
          ],
        );
      },
    );
  }
}

// ── WOD tile with exercise summary ───────────────────────────────────────────

class _WodTile extends ConsumerWidget {
  final WodTemplate wod;
  final bool readOnly;
  const _WodTile({super.key, required this.wod, required this.readOnly});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templateExercisesAsync =
        ref.watch(wodTemplateExercisesProvider(wod.id));
    final allExercisesAsync = ref.watch(exercisesProvider);

    final exerciseMap = <int, String>{};
    for (final e in allExercisesAsync.valueOrNull ?? []) {
      exerciseMap[e.id] = e.name;
    }
    final templateExercises = templateExercisesAsync.valueOrNull ?? [];

    final inner = Container(
      decoration: BoxDecoration(
        color: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WOD name row
          Row(
            children: [
              VibrantText(
                wod.name,
                style: Theme.of(context).textTheme.bodyMedium!,
              ),
              const Spacer(),
              if (!readOnly)
                Icon(Icons.chevron_right,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),

          // Exercise summary
          if (templateExercisesAsync.isLoading && templateExercises.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: SizedBox(height: 2, child: LinearProgressIndicator()),
            )
          else if (templateExercises.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No exercises',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            ...templateExercises.map((te) {
              final name = exerciseMap[te.exerciseId] ?? '…';
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 3,
                      margin: const EdgeInsets.only(right: 7, top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        name,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${te.targetSets}×${te.repRangeMin}–${te.repRangeMax}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: readOnly
          ? inner
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  glassRoute(
                      WodExerciseSetupScreen(wodTemplateId: wod.id)),
                ),
                borderRadius: BorderRadius.circular(12),
                child: inner,
              ),
            ),
    );
  }
}
