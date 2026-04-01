import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/program_providers.dart';
import '../../providers/database_provider.dart';
import 'program_setup_screen.dart';

class ProgramListScreen extends ConsumerWidget {
  const ProgramListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(allProgramsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: programsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (programs) {
          if (programs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center, size: 64),
                  const SizedBox(height: 16),
                  const Text('No programs yet'),
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
            itemCount: programs.length,
            itemBuilder: (context, i) =>
                _ProgramTile(program: programs[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context),
        icon: const Icon(Icons.add),
        label: const Text('New Program'),
      ),
    );
  }

  void _createNew(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProgramSetupScreen()),
    );
  }
}

class _ProgramTile extends ConsumerWidget {
  final Program program;
  const _ProgramTile({required this.program});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabels = {0: 'Active', 1: 'Completed', 2: 'Draft'};
    final statusColors = {
      0: Colors.green,
      1: Colors.blue,
      2: Colors.grey,
    };
    final status = program.status;

    return ListTile(
      title: Text(program.name),
      subtitle: Text(statusLabels[status] ?? ''),
      leading: CircleAvatar(
        backgroundColor:
            (statusColors[status] ?? Colors.grey).withValues(alpha: 0.2),
        child: Icon(Icons.fitness_center,
            color: statusColors[status] ?? Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_right),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgramSetupScreen(existingProgram: program),
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
