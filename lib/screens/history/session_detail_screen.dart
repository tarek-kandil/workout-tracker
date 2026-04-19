import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/vibrant_text.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
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
          isTimed: ex?.isTimed ?? false,
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
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _groups.isEmpty
                  ? Center(
                      child: Text(
                        'No sets recorded for this session.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _groups.length,
                      itemBuilder: (_, i) => _ExerciseCard(group: _groups[i]),
                    ),
        ],
      ),
    );
  }
}

class _ExerciseGroup {
  final String name;
  final bool isTimed;
  final List<WorkoutSet> sets;
  _ExerciseGroup({required this.name, required this.isTimed, required this.sets});
}

class _ExerciseCard extends StatelessWidget {
  final _ExerciseGroup group;
  const _ExerciseCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: 20,
        blurSigma: 10,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VibrantText(
                group.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...group.sets.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: group.isTimed
                        ? Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(
                                  'Set ${s.setNumber}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                ),
                              ),
                              Text(
                                _fmtSec(s.durationSeconds ?? 0),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              SizedBox(
                                width: 52,
                                child: Text(
                                  'Set ${s.setNumber}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.4),
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
                  )),
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

String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
