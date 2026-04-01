import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  // exerciseId → (exercise name, sets)
  List<_ExerciseGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final sets = await db.setsDao.getSetsForSession(widget.session.id);
    final exercises = await db.exercisesDao.getAllExercises();
    final exerciseMap = {for (final e in exercises) e.id: e};

    // Group sets by exercise, preserving order of first appearance
    final seen = <int>[];
    final grouped = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      if (!grouped.containsKey(s.exerciseId)) {
        seen.add(s.exerciseId);
        grouped[s.exerciseId] = [];
      }
      grouped[s.exerciseId]!.add(s);
    }

    setState(() {
      _groups = seen.map((id) {
        final ex = exerciseMap[id];
        return _ExerciseGroup(
          name: ex?.name ?? 'Unknown',
          sets: grouped[id]!,
        );
      }).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateStr = _formatDate(session.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.workoutName),
            Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('No sets recorded for this session.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (_, i) => _ExerciseCard(group: _groups[i]),
                ),
    );
  }
}

class _ExerciseGroup {
  final String name;
  final List<WorkoutSet> sets;
  _ExerciseGroup({required this.name, required this.sets});
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseGroup group;
  const _ExerciseCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...group.sets.asMap().entries.map((e) {
                final s = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(
                          'Set ${s.setNumber}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      ),
                      Text(
                        '${_fmtW(s.weightKg)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text('×',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Text(
                        '${s.reps} reps',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
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

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
