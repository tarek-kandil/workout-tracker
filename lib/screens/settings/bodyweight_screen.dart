import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/home_providers.dart';

class BodyweightScreen extends ConsumerWidget {
  const BodyweightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(allBodyweightsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Body Weight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log Weight'),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No entries yet.\nTap "Log Weight" to record today\'s weight.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: entries.length,
            itemBuilder: (_, i) => _EntryTile(entry: entries[i]),
          );
        },
      ),
    );
  }

  Future<void> _showLogDialog(BuildContext context, WidgetRef ref,
      {BodyweightEntry? existing}) async {
    final weightCtrl = TextEditingController(
        text: existing != null
            ? existing.weightKg.toStringAsFixed(1)
            : '');
    DateTime selectedDate = existing?.date ?? DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Log Weight' : 'Edit Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_formatDate(selectedDate)),
              ),
            ],
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
      ),
    );
    if (confirmed != true) return;

    final kg = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;

    final db = ref.read(databaseProvider);
    await db.bodyweightDao.insertBodyweight(
      BodyweightEntriesCompanion(
        date: Value(selectedDate),
        weightKg: Value(kg),
      ),
    );
    // Streams auto-refresh — no manual invalidation needed
  }
}

class _EntryTile extends ConsumerWidget {
  final BodyweightEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.5),
        child: Icon(Icons.monitor_weight_outlined,
            size: 18, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        '${entry.weightKg.toStringAsFixed(1)} kg',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_formatDate(entry.date)),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
            'Remove the ${entry.weightKg.toStringAsFixed(1)} kg entry from ${_formatDate(entry.date)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(databaseProvider).bodyweightDao.deleteBodyweight(entry.id);
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}
