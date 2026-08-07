import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_provider.dart';

class ExerciseSwapSheet extends ConsumerStatefulWidget {
  final int exerciseId;
  final String exerciseName;
  final void Function(Exercise) onSisterSelected;
  final VoidCallback onOtherExercise;

  const ExerciseSwapSheet({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.onSisterSelected,
    required this.onOtherExercise,
  });

  @override
  ConsumerState<ExerciseSwapSheet> createState() => _ExerciseSwapSheetState();
}

class _ExerciseSwapSheetState extends ConsumerState<ExerciseSwapSheet> {
  List<Exercise> _sisters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSisters();
  }

  Future<void> _loadSisters() async {
    final sisters = await ref
        .read(databaseProvider)
        .exerciseSistersDao
        .getSisters(widget.exerciseId);
    if (mounted) {
      setState(() {
        _sisters = sisters;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Swap Exercise',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Similar movements for ${widget.exerciseName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scroll,
                          children: [
                            if (_sisters.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    'No sister exercises saved yet.',
                                    style: TextStyle(
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (final sister in _sisters)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.sync_alt_rounded),
                                  title: Text(sister.name),
                                  subtitle: Text(
                                    sister.isTimed ? 'Timed' : 'Weighted',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => widget.onSisterSelected(sister),
                                ),
                            const Divider(height: 24),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.search_rounded,
                                color: scheme.primary,
                              ),
                              title: const Text(
                                'Other exercise…',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: const Text(
                                'Search the full library and optionally add it to sisters',
                              ),
                              onTap: widget.onOtherExercise,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
