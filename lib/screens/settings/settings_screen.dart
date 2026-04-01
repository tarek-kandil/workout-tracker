import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../providers/session_providers.dart';
import 'bodyweight_screen.dart';
import 'exercise_library_screen.dart';
import 'program_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Manage Programs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProgramListScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('Exercise Library'),
            subtitle: const Text('View and manage exercises'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Log Body Weight'),
            subtitle: const Text('Track your weight over time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BodyweightScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text('Clear All Sessions & PRs',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text(
                'Delete all logged sessions, sets, and personal records. Program setup is kept.'),
            onTap: () => _confirmClearHistory(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Sessions & PRs?'),
        content: const Text(
            'This will permanently delete all logged sessions, sets, and '
            'personal records. Your program setup and exercise library are kept. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All History'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final db = ref.read(databaseProvider);
    // Delete sets first (FK references sessions), then sessions
    await db.setsDao.clearAllSets();
    await db.sessionsDao.clearAllSessions();

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);
    ref.invalidate(personalRecordsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout history cleared.')),
      );
    }
  }
}
