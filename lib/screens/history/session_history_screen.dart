import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/daos/sessions_dao.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'session_detail_screen.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (entries) {
              if (entries.isEmpty) {
                return Center(
                  child: Text(
                    'No sessions logged yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                  ),
                );
              }
              final grouped = _groupByWeek(entries);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: grouped.length,
                itemBuilder: (_, i) {
                  final group = grouped[i];
                  if (group.isHeader) {
                    return _WeekHeader(label: group.label);
                  }
                  return _SessionTile(entry: group.entry!);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Grouping logic ────────────────────────────────────────────────────────────

class _ListItem {
  final bool isHeader;
  final String label;
  final SessionWithProgram? entry;
  const _ListItem.header(this.label)
      : isHeader = true,
        entry = null;
  const _ListItem.entry(this.entry)
      : isHeader = false,
        label = '';
}

List<_ListItem> _groupByWeek(List<SessionWithProgram> entries) {
  final items = <_ListItem>[];
  String? lastKey;
  for (final e in entries) {
    final key = _weekKey(e.session.date);
    if (key != lastKey) {
      items.add(_ListItem.header(_weekLabel(e.session.date)));
      lastKey = key;
    }
    items.add(_ListItem.entry(e));
  }
  return items;
}

String _weekKey(DateTime d) {
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return '${monday.year}-W${_isoWeek(d).toString().padLeft(2, '0')}';
}

int _isoWeek(DateTime d) {
  final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
  final weekday = d.weekday;
  return ((dayOfYear - weekday + 10) / 7).floor();
}

String _weekLabel(DateTime d) {
  final monday = d.subtract(Duration(days: d.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  if (monday.month == sunday.month) {
    return '${monday.day}–${sunday.day} ${months[monday.month - 1]} ${monday.year}';
  }
  return '${monday.day} ${months[monday.month - 1]} – ${sunday.day} ${months[sunday.month - 1]} ${sunday.year}';
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

// ─── Widgets ───────────────────────────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  final String label;
  const _WeekHeader({required this.label});

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
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final SessionWithProgram entry;
  const _SessionTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final accent = Theme.of(context).colorScheme.primary;

    // Build subtitle: "Program Name · Week X" or just date
    final parts = <String>[];
    if (entry.programName != null) parts.add(entry.programName!);
    if (session.weekNumber != null) parts.add('Week ${session.weekNumber}');
    final subtitle = parts.isNotEmpty
        ? '${_formatDate(session.date)}  ·  ${parts.join(' · ')}'
        : _formatDate(session.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            glassRoute(SessionDetailScreen(session: session)),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.fitness_center, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.workoutName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                      ),
                    ],
                  ),
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
}
