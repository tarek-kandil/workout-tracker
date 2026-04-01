import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/personal_record_entry.dart';
import '../../providers/database_provider.dart';
import '../../providers/session_providers.dart';
import 'exercise_history_screen.dart';

class PersonalRecordsScreen extends ConsumerWidget {
  const PersonalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prAsync = ref.watch(personalRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: prAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Text('No records yet — log a workout to see your PRs.'),
            );
          }

          // Group by category
          final grouped = _groupByCategory(records);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final item = grouped[i];
              if (item.isHeader) {
                return _CategoryHeader(label: item.label);
              }
              return _RecordTile(record: item.record!);
            },
          );
        },
      ),
    );
  }
}

// ─── Grouping ──────────────────────────────────────────────────────────────────

class _ListItem {
  final bool isHeader;
  final String label;
  final PersonalRecordEntry? record;
  const _ListItem.header(this.label)
      : isHeader = true,
        record = null;
  const _ListItem.record(this.record)
      : isHeader = false,
        label = '';
}

List<_ListItem> _groupByCategory(List<PersonalRecordEntry> records) {
  final items = <_ListItem>[];
  String? lastCategory;
  for (final r in records) {
    final cat = r.exerciseCategory.isEmpty ? 'Other' : r.exerciseCategory;
    if (cat != lastCategory) {
      items.add(_ListItem.header(cat));
      lastCategory = cat;
    }
    items.add(_ListItem.record(r));
  }
  return items;
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String label;
  const _CategoryHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends ConsumerWidget {
  final PersonalRecordEntry record;
  const _RecordTile({required this.record});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PR?'),
        content: Text(
            'This will permanently delete all logged sets for '
            '"${record.exerciseName}". The exercise itself is kept.'),
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
    await ref.read(databaseProvider).setsDao.deleteSetsByExercise(record.exerciseId);
    ref.invalidate(personalRecordsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(record.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        'Est. 1RM  ~${_fmtW(record.estimatedOneRm)} kg',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${_fmtW(record.maxWeightKg)} kg',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'PR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ExerciseHistoryScreen(record: record),
      )),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
