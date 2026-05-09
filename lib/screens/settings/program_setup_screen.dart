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
    if (phases.isEmpty || !mounted) return;

    // Programs are single-phase for now. Zero out any extra phases so they
    // don't inflate week totals. We keep the rows (and their WODs) intact so
    // the phase feature can be revived later without data loss.
    for (int i = 1; i < phases.length; i++) {
      final p = phases[i];
      await db.programsDao.updatePhase(ProgramPhasesCompanion(
        id: Value(p.id),
        programId: Value(p.programId),
        phaseNumber: Value(p.phaseNumber),
        name: Value(p.name),
        durationWeeks: const Value(0),
      ));
    }

    if (!mounted) return;
    setState(() {
      _phaseId = phases.first.id;
      _durationCtrl.text = phases.first.durationWeeks.toString();
    });
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
        // Update the primary phase with the user-specified duration.
        await db.programsDao.updatePhase(ProgramPhasesCompanion(
          id: Value(_phaseId!),
          programId: Value(widget.existingProgram!.id),
          phaseNumber: const Value(1),
          name: const Value('Main'),
          durationWeeks: Value(weeks),
        ));
        // Zero out every other phase so they never contribute to week totals.
        final allPhases = await db.programsDao
            .getPhasesForProgram(widget.existingProgram!.id);
        for (final p in allPhases) {
          if (p.id == _phaseId) continue;
          await db.programsDao.updatePhase(ProgramPhasesCompanion(
            id: Value(p.id),
            programId: Value(p.programId),
            phaseNumber: Value(p.phaseNumber),
            name: Value(p.name),
            durationWeeks: const Value(0),
          ));
        }
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

class _WodList extends ConsumerStatefulWidget {
  final int phaseId;
  final bool readOnly;
  const _WodList({required this.phaseId, required this.readOnly});

  @override
  ConsumerState<_WodList> createState() => _WodListState();
}

class _WodListState extends ConsumerState<_WodList> {
  List<WodTemplate>? _wods;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wods = await ref
        .read(databaseProvider)
        .programsDao
        .getWodTemplatesForPhase(widget.phaseId);
    if (mounted) setState(() => _wods = wods);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final wods = List<WodTemplate>.from(_wods!);
    final item = wods.removeAt(oldIndex);
    wods.insert(newIndex, item);
    setState(() => _wods = wods);

    final db = ref.read(databaseProvider);
    for (int i = 0; i < wods.length; i++) {
      await db.programsDao.updateWodTemplate(WodTemplatesCompanion(
        id: Value(wods[i].id),
        phaseId: Value(wods[i].phaseId),
        wodNumber: Value(i + 1),
        name: Value(wods[i].name),
        notes: Value(wods[i].notes),
      ));
    }
    ref.invalidate(wodTemplatesForPhaseProvider(widget.phaseId));
    ref.invalidate(nextWodProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Sync from provider after external edits (e.g. returning from WodSetupScreen)
    ref.listen(wodTemplatesForPhaseProvider(widget.phaseId), (_, next) {
      next.whenData((wods) {
        if (mounted) setState(() => _wods = wods);
      });
    });

    final wods = _wods;
    if (wods == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (wods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          widget.readOnly
              ? 'No workouts in this program.'
              : 'No workouts yet — tap "Edit Workouts" to add.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.4),
              ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: widget.readOnly ? (a, b) {} : _onReorder,
        children: [
          for (int i = 0; i < wods.length; i++)
            _WodTile(
              key: ValueKey(wods[i].id),
              wod: wods[i],
              phaseId: widget.phaseId,
              readOnly: widget.readOnly,
              dragIndex: widget.readOnly ? null : i,
            ),
        ],
      ),
    );
  }
}

// ── WOD tile with exercise summary ───────────────────────────────────────────

String _fmtRpe(double rpe) =>
    rpe == rpe.roundToDouble() ? rpe.toInt().toString() : rpe.toString();

class _WodTile extends ConsumerStatefulWidget {
  final WodTemplate wod;
  final int phaseId;
  final bool readOnly;
  final int? dragIndex;
  const _WodTile({
    super.key,
    required this.wod,
    required this.phaseId,
    required this.readOnly,
    this.dragIndex,
  });

  @override
  ConsumerState<_WodTile> createState() => _WodTileState();
}

class _WodTileState extends ConsumerState<_WodTile> {
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.wod.name);
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _saveName();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      _nameCtrl.text = widget.wod.name;
      setState(() => _editing = false);
      return;
    }
    setState(() => _editing = false);
    await ref.read(databaseProvider).programsDao.updateWodTemplate(
      WodTemplatesCompanion(
        id: Value(widget.wod.id),
        phaseId: Value(widget.wod.phaseId),
        wodNumber: Value(widget.wod.wodNumber),
        name: Value(newName),
        notes: Value(widget.wod.notes),
      ),
    );
    ref.invalidate(wodTemplatesForPhaseProvider(widget.phaseId));
  }

  @override
  Widget build(BuildContext context) {
    final templateExercisesAsync =
        ref.watch(wodTemplateExercisesProvider(widget.wod.id));
    final circuitGroupsAsync = ref.watch(wodCircuitGroupsProvider(widget.wod.id));
    final allExercisesAsync = ref.watch(exercisesProvider);

    final exerciseMap = <int, Exercise>{};
    for (final e in allExercisesAsync.valueOrNull ?? []) {
      exerciseMap[e.id] = e;
    }
    final templateExercises = templateExercisesAsync.valueOrNull ?? [];
    final circuitGroups = circuitGroupsAsync.valueOrNull ?? [];

    // Group exercises by groupId
    final standaloneExercises =
        templateExercises.where((te) => te.groupId == null).toList();
    final circuitExMap = <int, List<WodTemplateExercise>>{};
    for (final te in templateExercises) {
      if (te.groupId != null) {
        circuitExMap.putIfAbsent(te.groupId!, () => []).add(te);
      }
    }

    final isLoading =
        templateExercisesAsync.isLoading && templateExercises.isEmpty;
    final isEmpty =
        !isLoading && templateExercises.isEmpty && circuitGroups.isEmpty;

    // Build sorted list of wod-level items (standalone + circuit) by sort order
    final wodLevelItems =
        <({int sortOrder, bool isCircuit, dynamic data})>[];
    for (final te in standaloneExercises) {
      wodLevelItems
          .add((sortOrder: te.sortOrder, isCircuit: false, data: te));
    }
    for (final g in circuitGroups) {
      wodLevelItems
          .add((sortOrder: g.sortOrder, isCircuit: true, data: g));
    }
    wodLevelItems.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final hasExercises = !isLoading && !isEmpty;

    // ── Inner card ────────────────────────────────────────────────────────
    final inner = Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _editing
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: Stack(
        children: [
          // Rim-light: 1 px gradient line at top
          Positioned(
            left: 1,
            right: 1,
            top: 0,
            height: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    // Drag handle
                    if (widget.dragIndex != null) ...[
                      ReorderableDragStartListener(
                        index: widget.dragIndex!,
                        child: Icon(
                          Icons.drag_handle,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Numbered indigo badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: const Color(0xFF6366F1)
                              .withValues(alpha: 0.28),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.wod.wodNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF818CF8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name zone
                    Expanded(
                      child: !widget.readOnly
                          ? GestureDetector(
                              onTap: () {
                                setState(() => _editing = true);
                                Future.microtask(() => _focusNode.requestFocus());
                              },
                              child: _editing
                                  ? TextField(
                                      controller: _nameCtrl,
                                      focusNode: _focusNode,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        border: InputBorder.none,
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0xFF6366F1),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveName(),
                                    )
                                  : Text(
                                      widget.wod.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                            )
                          : Text(
                              widget.wod.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                    ),
                    // Pencil indicator — visual only, plain Icon, no onTap
                    if (!widget.readOnly) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: Color.fromRGBO(99, 102, 241, 0.4),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Divider (only when exercises exist) ─────────────────────
              if (hasExercises)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),

              // ── Exercise rows ────────────────────────────────────────────
              if (!widget.readOnly && (hasExercises || isEmpty))
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    glassRoute(WodExerciseSetupScreen(wodTemplateId: widget.wod.id)),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: isEmpty
                        ? Text(
                            'No exercises — tap to add',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int idx = 0; idx < wodLevelItems.length; idx++) ...[
                                if (idx > 0) const SizedBox(height: 4),
                                _buildWodItem(context, wodLevelItems[idx], exerciseMap, circuitExMap),
                              ],
                            ],
                          ),
                  ),
                )
              else if (widget.readOnly && hasExercises)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int idx = 0; idx < wodLevelItems.length; idx++) ...[
                        if (idx > 0) const SizedBox(height: 4),
                        _buildWodItem(context, wodLevelItems[idx], exerciseMap, circuitExMap),
                      ],
                    ],
                  ),
                )
              else if (isLoading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: SizedBox(height: 2, child: LinearProgressIndicator()),
                )
              else if (widget.readOnly && isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Text(
                    'No exercises',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: inner,
    );
  }

  Widget _buildWodItem(
    BuildContext context,
    ({int sortOrder, bool isCircuit, dynamic data}) item,
    Map<int, Exercise> exerciseMap,
    Map<int, List<WodTemplateExercise>> circuitExMap,
  ) {
    if (!item.isCircuit) {
      return _buildStandaloneRow(context, item.data as WodTemplateExercise,
          exerciseMap);
    } else {
      return _buildCircuitBlock(context, item.data as WodExerciseGroup,
          exerciseMap, circuitExMap);
    }
  }

  Widget _buildStandaloneRow(
    BuildContext context,
    WodTemplateExercise te,
    Map<int, Exercise> exerciseMap,
  ) {
    final exercise = exerciseMap[te.exerciseId];
    final name = exercise?.name ?? '…';
    final isTimed = exercise?.isTimed ?? false;
    final rangeStr = isTimed
        ? '${te.targetSets}×${te.repRangeMin}s'
        : '${te.targetSets}×${te.repRangeMin}–${te.repRangeMax}';

    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(right: 8, top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // Reps pill
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            rangeStr,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(255, 255, 255, 0.3),
            ),
          ),
        ),
        // RPE pill
        if (te.targetRpe != null) ...[
          const SizedBox(width: 5),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFBBF24).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: const Color(0xFFFBBF24)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '@${_fmtRpe(te.targetRpe!)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color.fromRGBO(251, 191, 36, 0.75),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCircuitBlock(
    BuildContext context,
    WodExerciseGroup group,
    Map<int, Exercise> exerciseMap,
    Map<int, List<WodTemplateExercise>> circuitExMap,
  ) {
    final exercises = circuitExMap[group.id] ?? [];
    final circuitName =
        (group.name != null && group.name!.isNotEmpty)
            ? group.name!
            : 'Circuit';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circuit header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                const Icon(Icons.loop,
                    size: 11, color: Color(0xFF818CF8)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    circuitName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF818CF8),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  '${group.rounds}×',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color.fromRGBO(129, 140, 248, 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (exercises.isNotEmpty) ...[
            Divider(
                height: 1,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < exercises.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _buildCircuitExerciseRow(
                        context, exercises[i], exerciseMap),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircuitExerciseRow(
    BuildContext context,
    WodTemplateExercise te,
    Map<int, Exercise> exerciseMap,
  ) {
    final exercise = exerciseMap[te.exerciseId];
    final name = exercise?.name ?? '…';
    final isTimed = exercise?.isTimed ?? false;
    final rangeStr = isTimed
        ? '${te.repRangeMin}s'
        : '${te.repRangeMin}–${te.repRangeMax}';

    return Row(
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(right: 7, top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        // Reps pill
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            rangeStr,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(255, 255, 255, 0.3),
            ),
          ),
        ),
        // RPE pill
        if (te.targetRpe != null) ...[
          const SizedBox(width: 5),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFBBF24).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: const Color(0xFFFBBF24)
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '@${_fmtRpe(te.targetRpe!)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color.fromRGBO(251, 191, 36, 0.75),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
