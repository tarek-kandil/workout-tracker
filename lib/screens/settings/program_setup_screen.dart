import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
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
  List<_PhaseEntry> _phases = [];
  bool _saving = false;
  bool _readOnly = false;

  bool get _isEditing => widget.existingProgram != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existingProgram?.name ?? '');
    _readOnly = _isEditing; // start read-only when viewing an existing program
    _loadPhases();
  }

  Future<void> _loadPhases() async {
    if (!_isEditing) {
      // Default: single 12-week phase
      setState(() => _phases = [
            _PhaseEntry(
              nameCtrl: TextEditingController(text: 'Phase 1'),
              weeksCtrl: TextEditingController(text: '12'),
            )
          ]);
      return;
    }
    final db = ref.read(databaseProvider);
    final phases = await db.programsDao
        .getPhasesForProgram(widget.existingProgram!.id);
    setState(() => _phases = phases
        .map((p) => _PhaseEntry(
              id: p.id,
              nameCtrl: TextEditingController(text: p.name),
              weeksCtrl:
                  TextEditingController(text: p.durationWeeks.toString()),
            ))
        .toList());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final p in _phases) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = ref.read(databaseProvider);
    int programId;

    if (_isEditing) {
      programId = widget.existingProgram!.id;
      await db.programsDao.updateProgram(ProgramsCompanion(
        id: Value(programId),
        name: Value(_nameCtrl.text.trim()),
        status: Value(widget.existingProgram!.status),
      ));
      // Sync phases: update existing, insert new
      final existingPhases =
          await db.programsDao.getPhasesForProgram(programId);
      final existingIds = existingPhases.map((p) => p.id).toSet();

      for (int i = 0; i < _phases.length; i++) {
        final entry = _phases[i];
        final weeks =
            int.tryParse(entry.weeksCtrl.text.trim()) ?? 4;
        if (entry.id != null && existingIds.contains(entry.id)) {
          await db.programsDao.updatePhase(ProgramPhasesCompanion(
            id: Value(entry.id!),
            programId: Value(programId),
            phaseNumber: Value(i + 1),
            name: Value(entry.nameCtrl.text.trim()),
            durationWeeks: Value(weeks),
          ));
        } else {
          await db.programsDao.insertPhase(ProgramPhasesCompanion(
            programId: Value(programId),
            phaseNumber: Value(i + 1),
            name: Value(entry.nameCtrl.text.trim()),
            durationWeeks: Value(weeks),
          ));
        }
      }
      // Delete removed phases (user deleted them in UI)
      final keptIds =
          _phases.where((p) => p.id != null).map((p) => p.id!).toSet();
      for (final id
          in existingIds.difference(keptIds)) {
        await db.programsDao.deletePhase(id);
      }
    } else {
      // New program — create as draft (status = 2)
      programId = await db.programsDao.insertProgram(ProgramsCompanion(
        name: Value(_nameCtrl.text.trim()),
        status: const Value(2),
      ));
      for (int i = 0; i < _phases.length; i++) {
        final entry = _phases[i];
        final weeks = int.tryParse(entry.weeksCtrl.text.trim()) ?? 4;
        await db.programsDao.insertPhase(ProgramPhasesCompanion(
          programId: Value(programId),
          phaseNumber: Value(i + 1),
          name: Value(entry.nameCtrl.text.trim()),
          durationWeeks: Value(weeks),
        ));
      }
    }

    ref.invalidate(allProgramsProvider);
    ref.invalidate(activeProgramProvider);

    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
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
    // Deactivate any current active program
    final allPrograms = await db.programsDao.getAllPrograms();
    for (final p in allPrograms) {
      if (p.status == 0) {
        await db.programsDao.updateProgramStatus(p.id, 2); // back to draft
      }
    }
    await db.programsDao.updateProgramStatus(
        widget.existingProgram!.id, 0); // set active

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
            'Your program setup (exercises, WODs, phases) is kept. '
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Program' : 'New Program'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active program banner
            if (_isEditing && widget.existingProgram!.status == 0) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Currently Active Program',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Program name
            TextFormField(
              controller: _nameCtrl,
              readOnly: _readOnly,
              decoration: const InputDecoration(
                labelText: 'Program Name',
                hintText: 'e.g. 12-Week PPL',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),

            // Phases
            Row(
              children: [
                Text('Phases',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (!_readOnly)
                  TextButton.icon(
                    onPressed: () => setState(() => _phases.add(_PhaseEntry(
                          nameCtrl: TextEditingController(
                              text: 'Phase ${_phases.length + 1}'),
                          weeksCtrl: TextEditingController(text: '4'),
                        ))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Phase'),
                  ),
              ],
            ),
            ..._phases.asMap().entries.map((entry) =>
                _PhaseCard(
                  index: entry.key,
                  phaseEntry: entry.value,
                  canDelete: _phases.length > 1,
                  readOnly: _readOnly,
                  onDelete: () => setState(() => _phases.removeAt(entry.key)),
                )),

            // Activate button (edit mode only, draft programs)
            if (_isEditing && widget.existingProgram!.status == 2) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _activate,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Activate This Program'),
              ),
            ],

            // Restart button (active programs only)
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
    );
  }
}

class _PhaseEntry {
  final int? id;
  final TextEditingController nameCtrl;
  final TextEditingController weeksCtrl;

  _PhaseEntry({this.id, required this.nameCtrl, required this.weeksCtrl});

  void dispose() {
    nameCtrl.dispose();
    weeksCtrl.dispose();
  }
}

class _PhaseCard extends ConsumerWidget {
  final int index;
  final _PhaseEntry phaseEntry;
  final bool canDelete;
  final bool readOnly;
  final VoidCallback onDelete;

  const _PhaseCard({
    required this.index,
    required this.phaseEntry,
    required this.canDelete,
    required this.readOnly,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phaseId = phaseEntry.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Phase ${index + 1}',
                    style: Theme.of(context).textTheme.labelMedium),
                const Spacer(),
                if (phaseId != null && !readOnly)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit WODs',
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => WodSetupScreen(phaseId: phaseId),
                      ));
                      ref.invalidate(wodTemplatesForPhaseProvider(phaseId));
                    },
                  ),
                if (canDelete && !readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    color: Theme.of(context).colorScheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: phaseEntry.nameCtrl,
                    readOnly: readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Phase Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: phaseEntry.weeksCtrl,
                    readOnly: readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Weeks',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Min 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (phaseId == null) ...[
              const SizedBox(height: 8),
              Text(
                'Save the program first, then add workouts to each phase.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              _WodList(phaseId: phaseId),
          ],
        ),
      ),
    );
  }
}

class _WodList extends ConsumerWidget {
  final int phaseId;
  const _WodList({required this.phaseId});

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
              'No workouts yet — tap the pencil to add.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          );
        }
        return Column(
          children: [
            const SizedBox(height: 4),
            ...wods.map((wod) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(wod.name,
                      style: Theme.of(context).textTheme.bodyMedium),
                  trailing:
                      const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        WodExerciseSetupScreen(wodTemplateId: wod.id),
                  )),
                )),
          ],
        );
      },
    );
  }
}
