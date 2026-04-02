import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'session_detail_screen.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          sessionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Center(
                  child: Text(
                    'No sessions logged yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                  ),
                );
              }
              final grouped = _groupByWeek(sessions);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: grouped.length,
                itemBuilder: (_, i) {
                  final group = grouped[i];
                  if (group.isHeader) {
                    return _WeekHeader(label: group.label);
                  }
                  return _SessionTile(session: group.session!);
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
  final WorkoutSession? session;
  const _ListItem.header(this.label)
      : isHeader = true,
        session = null;
  const _ListItem.session(this.session)
      : isHeader = false,
        label = '';
}

List<_ListItem> _groupByWeek(List<WorkoutSession> sessions) {
  final items = <_ListItem>[];
  String? lastKey;
  for (final s in sessions) {
    final key = _weekKey(s.date);
    if (key != lastKey) {
      items.add(_ListItem.header(_weekLabel(s.date)));
      lastKey = key;
    }
    items.add(_ListItem.session(s));
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
  final WorkoutSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
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
              color: const Color(0x26000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.09),
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
                        _formatDate(session.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                      ),
                    ],
                  ),
                ),
                if (session.weekNumber != null)
                  Text(
                    'Wk ${session.weekNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                  ),
                const SizedBox(width: 4),
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
