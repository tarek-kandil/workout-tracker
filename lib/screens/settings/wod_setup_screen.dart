import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'wod_exercise_setup_screen.dart';

class WodSetupScreen extends ConsumerStatefulWidget {
  final int phaseId;
  const WodSetupScreen({super.key, required this.phaseId});

  @override
  ConsumerState<WodSetupScreen> createState() => _WodSetupScreenState();
}

class _WodSetupScreenState extends ConsumerState<WodSetupScreen> {
  List<WodTemplate> _wods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final wods =
        await db.programsDao.getWodTemplatesForPhase(widget.phaseId);
    setState(() {
      _wods = wods;
      _loading = false;
    });
  }

  Future<void> _addWod() async {
    final nameCtrl = TextEditingController(text: 'WOD ${_wods.length + 1}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Workout'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Workout Name',
            hintText: 'e.g. WOD 1 – Push',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    final id = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion(
        phaseId: Value(widget.phaseId),
        wodNumber: Value(_wods.length + 1),
        name: Value(nameCtrl.text.trim()),
      ),
    );
    await _load();
    ref.invalidate(nextWodProvider);
    // Navigate directly to exercise setup for the new WOD
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WodExerciseSetupScreen(wodTemplateId: id),
        ),
      );
    }
  }

  Future<void> _renameWod(WodTemplate wod) async {
    final nameCtrl = TextEditingController(text: wod.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Workout'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Workout Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).programsDao.updateWodTemplate(
          WodTemplatesCompanion(
            id: Value(wod.id),
            phaseId: Value(wod.phaseId),
            wodNumber: Value(wod.wodNumber),
            name: Value(nameCtrl.text.trim()),
          ),
        );
    _load();
  }

  Future<void> _deleteWod(WodTemplate wod) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout?'),
        content: Text(
            'Delete "${wod.name}"? Its exercise template will be removed. Logged sessions are unaffected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).programsDao.deleteWodTemplate(wod.id);
    ref.invalidate(nextWodProvider);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_wods.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center,
                      size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text('No workouts yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          )),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _addWod,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Workout'),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _wods.length,
              itemBuilder: (context, i) {
                final wod = _wods[i];
                final accent = Theme.of(context).colorScheme.primary;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context)
                          .push(glassRoute(
                            WodExerciseSetupScreen(wodTemplateId: wod.id),
                          ))
                          .then((_) => _load()),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0x26000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.09)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  accent.withValues(alpha: 0.18),
                              child: Text(
                                '${wod.wodNumber}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: accent),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(wod.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _renameWod(wod),
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _deleteWod(wod),
                              color: Theme.of(context).colorScheme.error,
                            ),
                            Icon(Icons.chevron_right,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.25)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWod,
        icon: const Icon(Icons.add),
        label: const Text('Add Workout'),
      ),
    );
  }
}
