import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/program_providers.dart';
import 'widgets/active_program_card.dart';
import 'widgets/next_workout_card.dart';
import 'widgets/bodyweight_card.dart';
import 'widgets/streak_card.dart';
import 'widgets/strength_chart_card.dart';
import 'widgets/daily_tasks_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramAsync = ref.watch(activeProgramProvider);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          title: Text('Workout Tracker'),
          floating: true,
          snap: true,
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
            data: (program) => program == null
                ? _buildNoProgramState(context)
                : _buildProgramDashboard(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoProgramState(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.fitness_center,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary),
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
                  onPressed: () => Navigator.of(context).pushNamed('/program-setup'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Program'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const BodyweightCard(),
        const SizedBox(height: 12),
        const DailyTasksCard(),
      ]),
    );
  }

  Widget _buildProgramDashboard() {
    return SliverList(
      delegate: SliverChildListDelegate([
        const ActiveProgramCard(),
        const SizedBox(height: 12),
        const NextWorkoutCard(),
        const SizedBox(height: 12),
        const BodyweightCard(),
        const SizedBox(height: 12),
        const StreakCard(),
        const SizedBox(height: 12),
        const DailyTasksCard(),
        const SizedBox(height: 12),
        const StrengthChartCard(),
        const SizedBox(height: 24),
      ]),
    );
  }
}
