import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No workouts yet'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addWod,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Workout'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _wods.length,
                  itemBuilder: (context, i) {
                    final wod = _wods[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text('${wod.wodNumber}'),
                      ),
                      title: Text(wod.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _renameWod(wod),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteWod(wod),
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (_) => WodExerciseSetupScreen(
                                wodTemplateId: wod.id),
                          ))
                          .then((_) => _load()),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWod,
        icon: const Icon(Icons.add),
        label: const Text('Add Workout'),
      ),
    );
  }
}
