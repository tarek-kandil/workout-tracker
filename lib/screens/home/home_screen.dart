import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/program_providers.dart';
import '../../providers/daily_tasks_providers.dart';
import '../../providers/home_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import 'widgets/daily_task_home_card.dart';
import 'widgets/next_workout_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramAsync = ref.watch(activeProgramProvider);
    final tasksAsync = ref.watch(dailyTasksProvider);

    return Stack(
      children: [
        const Positioned.fill(child: GlassBackground()),
        CustomScrollView(
          slivers: [
            const SliverAppBar(
              title: Text('Today'),
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: activeProgramAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
                data: (program) {
                  final enabledTasks = (tasksAsync.valueOrNull ?? [])
                      .where((t) => t.isEnabled)
                      .toList();
                  if (program == null) {
                    return _buildNoProgramState(context, enabledTasks);
                  }
                  return _buildDashboard(context, ref, enabledTasks);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoProgramState(BuildContext context, List enabledTasks) {
    return SliverList(
      delegate: SliverChildListDelegate([
        GlassCard(
          borderRadius: 32,
          child: Column(
            children: [
              Icon(
                Icons.fitness_center,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Program',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Set up a workout program to get started with guided training.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/program-setup'),
                icon: const Icon(Icons.add),
                label: const Text('Create Program'),
              ),
            ],
          ),
        ),
        if (enabledTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionLabel(label: 'DAILY TASKS'),
          const SizedBox(height: 8),
          ...enabledTasks.expand((t) => [
                DailyTaskHomeCard(task: t),
                const SizedBox(height: 8),
              ]),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildDashboard(
      BuildContext context, WidgetRef ref, List enabledTasks) {
    final streakAsync = ref.watch(workoutStreakProvider);
    final sessionsAsync = ref.watch(recentSessionsProvider);
    final weekAsync = ref.watch(currentProgramWeekProvider);

    final streak = streakAsync.valueOrNull ?? 0;
    final sessions = sessionsAsync.valueOrNull?.length ?? 0;
    final week = weekAsync.valueOrNull ?? 1;

    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Hero card ────────────────────────────────────────────────────
        const NextWorkoutCard(),

        // ── Stat row ─────────────────────────────────────────────────────
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Streak', value: '$streak', unit: 'wk')),
            const SizedBox(width: 10),
            Expanded(child: _StatChip(label: 'Sessions', value: '$sessions')),
            const SizedBox(width: 10),
            Expanded(child: _StatChip(label: 'Week', value: '$week', prefix: 'W')),
          ],
        ),
        const SizedBox(height: 20),

        // ── Daily tasks ──────────────────────────────────────────────────
        if (enabledTasks.isNotEmpty) ...[
          _SectionLabel(label: 'DAILY TASKS'),
          const SizedBox(height: 8),
          ...enabledTasks.expand((t) => [
                DailyTaskHomeCard(task: t),
                const SizedBox(height: 8),
              ]),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? prefix;
  const _StatChip({required this.label, required this.value, this.unit, this.prefix});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
              children: [
                if (prefix != null)
                  TextSpan(
                    text: prefix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                TextSpan(text: value),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.45),
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.45),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
