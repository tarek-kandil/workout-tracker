import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/personal_record_entry.dart';
import '../../providers/database_provider.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'exercise_history_screen.dart';

class PersonalRecordsScreen extends ConsumerWidget {
  const PersonalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prAsync = ref.watch(personalRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          prAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (records) {
              if (records.isEmpty) {
                return Center(
                  child: Text(
                    'No records yet — log a workout to see your PRs.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                  ),
                );
              }
              final grouped = _groupByCategory(records);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
        ],
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
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
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
    await ref
        .read(databaseProvider)
        .setsDao
        .deleteSetsByExercise(record.exerciseId);
    ref.invalidate(personalRecordsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            glassRoute(ExerciseHistoryScreen(record: record)),
          ),
          onLongPress: () => _confirmDelete(context, ref),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.exerciseName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Est. 1RM  ~${_fmtW(record.estimatedOneRm)} kg',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_fmtW(record.maxWeightKg)} kg',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'PR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.white.withValues(alpha: 0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
