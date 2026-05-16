import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/daos/sessions_dao.dart';
import '../../database/daos/sets_dao.dart';
import '../../providers/database_provider.dart';
import '../../providers/home_providers.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'session_detail_screen.dart';

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final statsAsync = ref.watch(allSessionStatsProvider);

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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                );
              }
              final stats = statsAsync.asData?.value ?? {};
              final grouped = _groupByWeek(entries);
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(context).padding.bottom + 50),
                itemCount: grouped.length,
                itemBuilder: (_, i) {
                  final group = grouped[i];
                  if (group.isHeader) {
                    return _WeekHeader(label: group.label);
                  }
                  final entry = group.entry!;
                  final isMostRecent = entry == entries.first;
                  final sessionStats = stats[entry.session.id];
                  // Find prior same-name session for delta
                  double? priorVolume;
                  if (sessionStats != null) {
                    final prior = entries.firstWhere(
                      (e) =>
                          e.session.workoutName == entry.session.workoutName &&
                          e.session.date.isBefore(entry.session.date),
                      orElse: () => entry,
                    );
                    if (prior != entry) {
                      priorVolume = stats[prior.session.id]?.totalVolume;
                    }
                  }
                  return _SessionTile(
                    entry: entry,
                    stats: sessionStats,
                    priorVolume: priorVolume,
                    isMostRecent: isMostRecent,
                  );
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

class _SessionTile extends ConsumerWidget {
  final SessionWithProgram entry;
  final SessionSetStats? stats;
  final double? priorVolume;
  final bool isMostRecent;
  const _SessionTile({
    required this.entry,
    required this.stats,
    required this.priorVolume,
    required this.isMostRecent,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final session = entry.session;
    await db.setsDao.deleteSetsForSession(session.id);
    await db.sessionsDao.deleteSession(session.id);
    ref.invalidate(nextWodProvider);
    ref.invalidate(personalRecordsProvider);
    ref.invalidate(pointsScoreProvider);
    ref.invalidate(allSessionStatsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${session.workoutName} deleted'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = entry.session;
    final cs = Theme.of(context).colorScheme;

    final parts = <String>[];
    if (entry.programName != null) parts.add(entry.programName!);
    if (session.weekNumber != null) parts.add('Week ${session.weekNumber}');
    final subtitle = parts.isNotEmpty ? parts.join(' · ') : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(session.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _delete(context, ref),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: cs.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: cs.error),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              glassRoute(SessionDetailScreen(session: session)),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  // Row 1: date badge + name + PR chip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DateBadge(date: session.date, isMostRecent: isMostRecent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.workoutName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.45),
                                        fontSize: 10,
                                      ),
                                ),
                            ],
                          ),
                        ),
                        if ((stats?.prCount ?? 0) > 0)
                          _PrChip(prCount: stats!.prCount),
                      ],
                    ),
                  ),
                  // Row 2: stats strip
                  if (stats != null)
                    _StatsStrip(
                      stats: stats!,
                      priorVolume: priorVolume,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  final DateTime date;
  final bool isMostRecent;
  const _DateBadge({required this.date, required this.isMostRecent});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final bg = isMostRecent
        ? indigo.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.08);
    final fgStrong = isMostRecent ? indigo : Colors.white;
    final fgDim = isMostRecent
        ? indigo.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.45);

    return Container(
      width: 44,
      height: 50,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: fgStrong),
          ),
          Text(
            days[date.weekday - 1],
            style: TextStyle(fontSize: 10, color: fgDim),
          ),
        ],
      ),
    );
  }
}

class _PrChip extends StatelessWidget {
  final int prCount;
  const _PrChip({required this.prCount});

  @override
  Widget build(BuildContext context) {
    const indigo = Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: indigo.withValues(alpha: 0.35)),
      ),
      child: Text(
        '🏆 $prCount PR${prCount > 1 ? 's' : ''}',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: indigo),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  final SessionSetStats stats;
  final double? priorVolume;
  const _StatsStrip({required this.stats, this.priorVolume});

  String _fmtVol(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  String? _delta() {
    if (priorVolume == null || priorVolume! == 0) return null;
    final pct = (stats.totalVolume - priorVolume!) / priorVolume! * 100;
    if (pct >= 0) return '↑${pct.toStringAsFixed(0)}%';
    return '↓${(-pct).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta();
    final deltaColor = delta == null
        ? null
        : delta.startsWith('↑')
            ? const Color(0xFF34C759)
            : const Color(0xFFFF453A);

    final cols = <Widget>[
      _StatCol(
        label: 'VOL kg',
        value: _fmtVol(stats.totalVolume),
        sub: delta,
        subColor: deltaColor,
      ),
      const _VertDivider(),
      _StatCol(label: 'SETS', value: '${stats.setCount}'),
    ];

    if (stats.avgRpe != null) {
      cols.addAll([
        const _VertDivider(),
        _StatCol(label: 'AVG RPE', value: stats.avgRpe!.toStringAsFixed(1)),
      ]);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        color: const Color.fromRGBO(0, 0, 0, 0.18),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: cols),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  const _StatCol(
      {required this.label, required this.value, this.sub, this.subColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (sub != null)
            Text(
              sub!,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: subColor ?? Colors.white),
            ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  const _VertDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1));
  }
}
