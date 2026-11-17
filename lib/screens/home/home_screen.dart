import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/program_providers.dart';
import '../../providers/daily_tasks_providers.dart';
import '../../providers/flash_workouts_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_route.dart';
import '../settings/program_list_screen.dart';
import 'widgets/challenges_home_section.dart';
import 'widgets/daily_task_home_card.dart';
import 'widgets/flash_workout_home_card.dart';
import 'widgets/next_workout_card.dart';
import 'widgets/progressive_overload_card.dart';
import 'widgets/weekly_pr_card.dart';
import 'widgets/weight_goal_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProgramAsync = ref.watch(activeProgramProvider);
    final tasksAsync = ref.watch(dailyTasksProvider);
    final flashWorkoutsAsync = ref.watch(flashWorkoutsProvider);

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
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 50),
              sliver: activeProgramAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
                data: (program) {
                  final enabledTasks = (tasksAsync.valueOrNull ?? const <DailyTask>[])
                      .where((t) => t.isEnabled)
                      .toList();
                  final flashWorkouts =
                      flashWorkoutsAsync.valueOrNull ?? const <WodTemplate>[];
                  if (program == null) {
                    return _buildNoProgramState(context, ref, enabledTasks, flashWorkouts);
                  }
                  return _buildDashboard(context, ref, enabledTasks, flashWorkouts);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildFlashWorkoutsSection(List<WodTemplate> flashWorkouts) {
    if (flashWorkouts.isEmpty) return const [];
    return [
      const _SectionLabel(label: 'FLASH WORKOUTS'),
      const SizedBox(height: 8),
      ...flashWorkouts.expand((w) => [
            FlashWorkoutHomeCard(wod: w),
            const SizedBox(height: 8),
          ]),
    ];
  }

  Widget _buildNoProgramState(BuildContext context, WidgetRef ref,
      List<DailyTask> enabledTasks, List<WodTemplate> flashWorkouts) {
    final allPrograms =
        ref.watch(allProgramsProvider).valueOrNull ?? const <Program>[];
    final hasLibraryPrograms = allPrograms.isNotEmpty;

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
                hasLibraryPrograms
                    ? 'You have ${allPrograms.length} saved program${allPrograms.length == 1 ? '' : 's'}. Activate one or create a new program to start training.'
                    : 'Set up a workout program to get started with guided training.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  glassRoute(
                    ProgramListScreen(autoPromptCreate: !hasLibraryPrograms),
                  ),
                ),
                icon: Icon(hasLibraryPrograms
                    ? Icons.playlist_play_rounded
                    : Icons.add),
                label: Text(hasLibraryPrograms
                    ? 'Choose or Create Program'
                    : 'Create Program'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const ChallengesHomeSection(),
        if (flashWorkouts.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._buildFlashWorkoutsSection(flashWorkouts),
        ],
        if (enabledTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionLabel(label: 'DAILY TASKS'),
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

  Widget _buildDashboard(BuildContext context, WidgetRef ref,
      List<DailyTask> enabledTasks, List<WodTemplate> flashWorkouts) {
    return SliverList(
      delegate: SliverChildListDelegate([
        // ── Hero card ────────────────────────────────────────────────────
        const NextWorkoutCard(),
        const SizedBox(height: 14),
        const ChallengesHomeSection(),
        const SizedBox(height: 12),
        const ProgressiveOverloadCard(),
        const SizedBox(height: 10),
        const WeightGoalCard(),
        const SizedBox(height: 10),
        const WeeklyPRCard(),
        const SizedBox(height: 20),

        // ── Flash workouts ───────────────────────────────────────────────
        const SizedBox(height: 14),
        const ChallengesHomeSection(),
        if (flashWorkouts.isNotEmpty) ...[
          ..._buildFlashWorkoutsSection(flashWorkouts),
          const SizedBox(height: 12),
        ],

        // ── Daily tasks ──────────────────────────────────────────────────
        if (enabledTasks.isNotEmpty) ...[
          const _SectionLabel(label: 'DAILY TASKS'),
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
