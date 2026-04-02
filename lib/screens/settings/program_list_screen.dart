import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/program_providers.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'program_setup_screen.dart';

class ProgramListScreen extends ConsumerWidget {
  const ProgramListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(allProgramsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context),
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          programsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (programs) {
              if (programs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No programs yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _createNew(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Program'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: programs.length,
                itemBuilder: (context, i) =>
                    _ProgramTile(program: programs[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  void _createNew(BuildContext context) {
    Navigator.of(context).push(glassRoute(const ProgramSetupScreen()));
  }
}

class _ProgramTile extends ConsumerWidget {
  final Program program;
  const _ProgramTile({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColors = {0: Colors.green, 1: Colors.blue, 2: Colors.grey};
    final statusLabels = {0: 'Active', 1: 'Completed', 2: 'Draft'};
    final status = program.status;
    final color = statusColors[status] ?? Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            glassRoute(ProgramSetupScreen(existingProgram: program)),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(Icons.fitness_center, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(program.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        statusLabels[status] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: color.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error, size: 20),
                  onPressed: () => _confirmDelete(context, ref),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.white.withValues(alpha: 0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isActive = program.status == 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: Text(isActive
            ? 'WARNING: "${program.name}" is your currently active program. Deleting it will remove the program and all its workouts. Your logged sessions will be kept. This cannot be undone.'
            : 'Delete "${program.name}"? Its workouts will be removed. Logged sessions will not be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isActive ? 'Delete Active Program' : 'Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(databaseProvider).programsDao.deleteProgram(program.id);
      ref.invalidate(allProgramsProvider);
      ref.invalidate(activeProgramProvider);
    }
  }
}
