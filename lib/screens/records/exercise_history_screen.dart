import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/personal_record_entry.dart';
import '../../models/weight_history_point.dart';
import '../../providers/database_provider.dart';

class ExerciseHistoryScreen extends ConsumerStatefulWidget {
  final PersonalRecordEntry record;
  const ExerciseHistoryScreen({super.key, required this.record});

  @override
  ConsumerState<ExerciseHistoryScreen> createState() =>
      _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState
    extends ConsumerState<ExerciseHistoryScreen> {
  // Chronological order (oldest → newest) — used for the chart
  List<WeightHistoryPoint> _history = [];
  double? _goalKg;
  bool _loading = true;

  static const _prefKey = 'exercise_goal_';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await ref
        .read(databaseProvider)
        .setsDao
        .getWeightHistoryForExercise(widget.record.exerciseId);

    final prefs = await SharedPreferences.getInstance();
    final goal = prefs.getDouble('$_prefKey${widget.record.exerciseId}');

    setState(() {
      _history = points; // already ASC by date from the query
      _goalKg = goal;
      _loading = false;
    });
  }

  Future<void> _showGoalDialog() async {
    final ctrl = TextEditingController(
        text: _goalKg != null ? _fmtW(_goalKg!) : '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Goal Weight'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Target weight',
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (_goalKg != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Clear Goal'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (confirmed == null) {
      // Clear goal
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefKey${widget.record.exerciseId}');
      setState(() => _goalKg = null);
    } else if (confirmed == true) {
      final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (v != null && v > 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('$_prefKey${widget.record.exerciseId}', v);
        setState(() => _goalKg = v);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pr = widget.record;

    return Scaffold(
      appBar: AppBar(
        title: Text(pr.exerciseName),
        actions: [
          IconButton(
            icon: Icon(
              _goalKg != null ? Icons.flag : Icons.flag_outlined,
              color: _goalKg != null ? Colors.green : null,
            ),
            tooltip: 'Set Goal',
            onPressed: _showGoalDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Stat boxes ────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        _StatBox(
                          label: 'PR',
                          value: '${_fmtW(pr.maxWeightKg)} kg',
                          accent: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatBox(
                          label: 'Est. 1RM',
                          value: '~${_fmtW(pr.estimatedOneRm)} kg',
                        ),
                        if (_goalKg != null) ...[
                          const SizedBox(width: 12),
                          _StatBox(
                            label: 'Goal',
                            value: '${_fmtW(_goalKg!)} kg',
                            accent: Colors.green,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Chart ────────────────────────────────────────────────
                if (_history.length >= 2)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
                          child: SizedBox(
                            height: 220,
                            child: _ProgressChart(
                              history: _history,
                              prKg: pr.maxWeightKg,
                              goalKg: _goalKg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Session history list ──────────────────────────────────
                if (_history.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No weight history yet.')),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SESSION HISTORY',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Show most recent first in the list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final reversed = _history.reversed.toList();
                        return _HistoryTile(
                          point: reversed[i],
                          isPR: reversed[i].maxWeightKg >=
                              pr.maxWeightKg,
                        );
                      },
                      childCount: _history.length,
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ],
            ),
    );
  }
}

// ─── Progress chart ──────────────────────────────────────────────────────────

class _ProgressChart extends StatelessWidget {
  final List<WeightHistoryPoint> history;
  final double prKg;
  final double? goalKg;

  const _ProgressChart({
    required this.history,
    required this.prKg,
    required this.goalKg,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.maxWeightKg))
        .toList();

    // Y range — leave room for labels above the PR and goal lines
    final allValues = [
      ...history.map((h) => h.maxWeightKg),
      ?goalKg,
    ];
    final minY = (allValues.reduce((a, b) => a < b ? a : b) - 5)
        .clamp(0.0, double.infinity);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) + 10;

    final horizontalLines = <HorizontalLine>[
      // PR line
      HorizontalLine(
        y: prKg,
        color: primary.withValues(alpha: 0.8),
        strokeWidth: 1.5,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          labelResolver: (_) => 'PR  ${_fmtW(prKg)} kg',
          style: TextStyle(
            color: primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      // Goal line
      if (goalKg != null)
        HorizontalLine(
          y: goalKg!,
          color: Colors.green.withValues(alpha: 0.8),
          strokeWidth: 1.5,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            labelResolver: (_) => 'Goal  ${_fmtW(goalKg!)} kg',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval:
                  (history.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                final d = history[idx].date;
                const months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                ];
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${months[d.month - 1]} ${d.day}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, p, bar, index) {
                final isPR = history[index].maxWeightKg >= prKg;
                return FlDotCirclePainter(
                  radius: isPR ? 5.5 : 3,
                  color: isPR ? primary : primary.withValues(alpha: 0.7),
                  strokeWidth: isPR ? 2.5 : 0,
                  strokeColor: isPR
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.transparent,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat box ────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;
  const _StatBox({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: 0.7),
                      )),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History tile ────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final WeightHistoryPoint point;
  final bool isPR;
  const _HistoryTile({required this.point, required this.isPR});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = point.date;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateStr =
        '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: isPR
            ? primary.withValues(alpha: 0.18)
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.6),
        child: Icon(
          isPR ? Icons.emoji_events : Icons.fitness_center,
          size: 14,
          color: isPR ? primary : Colors.white.withValues(alpha: 0.5),
        ),
      ),
      title: Text(dateStr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPR)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
          Text(
            '${_fmtW(point.maxWeightKg)} kg',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPR ? primary : null,
                ),
          ),
        ],
      ),
    );
  }
}

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
