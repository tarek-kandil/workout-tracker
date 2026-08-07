import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';

class ExerciseLibrarySheet extends ConsumerStatefulWidget {
  final String title;
  final void Function(Exercise) onSelected;
  const ExerciseLibrarySheet({super.key, required this.title, required this.onSelected});

  @override
  ConsumerState<ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends ConsumerState<ExerciseLibrarySheet> {
  String _query = '';
  List<Exercise> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).exercisesDao.getAllExercises().then((list) {
      if (mounted) setState(() { _all = list; _loading = false; });
    });
  }

  List<Exercise> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect(String name) async {
    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(ExercisesCompanion.insert(name: name));
    final created = Exercise(id: id, name: name, isTimed: false, category: 'Other', notes: null);
    if (mounted) widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showCreate = _query.isNotEmpty &&
        filtered.every((e) => e.name.toLowerCase() != _query.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(controller: scroll, children: [
                    if (showCreate)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                        title: Text('Create "$_query"', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Add to exercise library'),
                        onTap: () => _createAndSelect(_query),
                      ),
                    for (final ex in filtered)
                      ListTile(
                        title: Text(ex.name),
                        subtitle: Text(ex.isTimed ? 'Timed' : 'Weighted', style: const TextStyle(fontSize: 11)),
                        onTap: () => widget.onSelected(ex),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}
