import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/exercise_providers.dart';
import '../../widgets/glass_background.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Group exercises by category, maintaining sort order from DAO
  Map<String, List<Exercise>> _group(List<Exercise> exercises) {
    final filtered = _query.isEmpty
        ? exercises
        : exercises
            .where((e) => e.name.toLowerCase().contains(_query))
            .toList();

    final Map<String, List<Exercise>> grouped = {};
    for (final e in filtered) {
      (grouped[e.category] ??= []).add(e);
    }
    return grouped;
  }

  Future<void> _showExerciseDialog({Exercise? existing, required List<Exercise> all}) async {
    final distinctCategories = all.map((e) => e.category).toSet().toList()..sort();

    final nameController = TextEditingController(text: existing?.name ?? '')
      ..selection = TextSelection.collapsed(
          offset: existing?.name.length ?? 0);
    final categoryController =
        TextEditingController(text: existing?.category == 'Other' && existing != null ? '' : (existing?.category ?? ''));
    final formKey = GlobalKey<FormState>();
    bool isTimed = existing?.isTimed ?? false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'New Exercise' : 'Edit Exercise'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue:
                          TextEditingValue(text: categoryController.text),
                      optionsBuilder: (textEditingValue) {
                        final q = textEditingValue.text.toLowerCase();
                        if (q.isEmpty) return distinctCategories;
                        return distinctCategories
                            .where((c) => c.toLowerCase().contains(q));
                      },
                      fieldViewBuilder:
                          (ctx, controller, focusNode, onSubmitted) {
                        // Keep our controller in sync with the autocomplete field
                        controller.addListener(
                            () => categoryController.text = controller.text);
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Category (optional)',
                            hintText: 'e.g. Push, Pull, Legs…',
                          ),
                          textCapitalization: TextCapitalization.words,
                          onEditingComplete: onSubmitted,
                        );
                      },
                      onSelected: (value) =>
                          categoryController.text = value,
                      optionsViewBuilder: (ctx, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (_, i) {
                                  final option = options.elementAt(i);
                                  return ListTile(
                                    dense: true,
                                    title: Text(option),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Timed exercise'),
                      value: isTimed,
                      onChanged: (v) => setDialogState(() => isTimed = v),
                    ),
                  ],
                ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ValueListenableBuilder(
                  valueListenable: nameController,
                  builder: (_, value, child) => FilledButton(
                    onPressed: nameController.text.trim().isEmpty
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            final name = nameController.text.trim();
                            final category =
                                categoryController.text.trim().isEmpty
                                    ? 'Other'
                                    : categoryController.text.trim();
                            final dao = ref.read(databaseProvider).exercisesDao;
                            if (existing == null) {
                              await dao.insertExercise(ExercisesCompanion.insert(
                                name: name,
                                category: Value(category),
                                isTimed: Value(isTimed),
                              ));
                            } else {
                              await dao.updateExercise(ExercisesCompanion(
                                id: Value(existing.id),
                                name: Value(name),
                                category: Value(category),
                                isTimed: Value(isTimed),
                              ));
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('Save'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Remove "${exercise.name}" from the library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).exercisesDao.deleteExercise(exercise.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (exercises) {
                final grouped = _group(exercises);
                if (grouped.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No exercises yet. Tap + to add one.'
                          : 'No results for "$_query"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  );
                }
                final categories = grouped.keys.toList()..sort();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: categories.fold<int>(
                    0,
                    (sum, cat) => sum + 1 + grouped[cat]!.length,
                  ),
                  itemBuilder: (_, index) {
                    var remaining = index;
                    for (final cat in categories) {
                      if (remaining == 0) {
                        return _CategoryHeader(
                          label: cat,
                          count: grouped[cat]!.length,
                        );
                      }
                      remaining--;
                      final items = grouped[cat]!;
                      if (remaining < items.length) {
                        final exercise = items[remaining];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showExerciseDialog(
                                existing: exercise,
                                all: exercises,
                              ),
                              onLongPress: () => _confirmDelete(exercise),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0x26000000),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(exercise.name)),
                                    if (exercise.isTimed) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.timer_outlined,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.7)),
                                    ],
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit_outlined,
                                        size: 16,
                                        color: Colors.white
                                            .withValues(alpha: 0.3)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      remaining -= items.length;
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
        ],
      ),          // Column
        ],
      ),          // Stack
      floatingActionButton: exercisesAsync.whenOrNull(
        data: (exercises) => FloatingActionButton(
          onPressed: () => _showExerciseDialog(all: exercises),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
