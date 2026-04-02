import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/program_providers.dart';
import '../../providers/daily_tasks_providers.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/glass_background.dart';
import 'widgets/active_program_card.dart';
import 'widgets/next_workout_card.dart';
import 'widgets/bodyweight_card.dart';
import 'widgets/streak_card.dart';
import 'widgets/daily_task_home_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramAsync = ref.watch(activeProgramProvider);
    final tasksAsync = ref.watch(dailyTasksProvider);

    return Stack(
      children: [
        // ── Animated blob background — gives BackdropFilter something to blur ──
        const Positioned.fill(child: GlassBackground()),

        // ── Scrollable content ─────────────────────────────────────────────────
        CustomScrollView(
          slivers: [
            // App bar — semi-transparent without BackdropFilter
            // (BackdropFilter in SliverAppBar.flexibleSpace is unreliable
            //  with floating+snap and triggers parentDataDirty assertions)
            const SliverAppBar(
              title: Text('Workout Tracker'),
              floating: true,
              snap: true,
              backgroundColor: Color(0xCC0F172A), // Deep Midnight ~80%
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
                  return program == null
                      ? _buildNoProgramState(context, enabledTasks)
                      : _buildProgramDashboard(enabledTasks);
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
        LiquidGlassContainer(
          borderRadius: 32,
          blurSigma: 18,
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
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/program-setup'),
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
        ...enabledTasks.expand((t) => [
              DailyTaskHomeCard(task: t),
              const SizedBox(height: 8),
            ]),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildProgramDashboard(List enabledTasks) {
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
        ...enabledTasks.expand((t) => [
              DailyTaskHomeCard(task: t),
              const SizedBox(height: 8),
            ]),
        const SizedBox(height: 24),
      ]),
    );
  }
}

