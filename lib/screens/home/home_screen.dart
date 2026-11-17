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
import 'widgets/supplements_home_card.dart';
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
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥', style: TextStyle(fontSize: 15)),
                  SizedBox(width: 7),
                  Text(
                    'TRAIN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
      const _SectionLabel(emoji: '⚡', label: 'FLASH WORKOUTS'),
      const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        const ChallengesHomeSection(),
        if (flashWorkouts.isNotEmpty) ...[
          const SizedBox(height: 26),
          ..._buildFlashWorkoutsSection(flashWorkouts),
        ],
        if (enabledTasks.isNotEmpty) ...[
          const SizedBox(height: 26),
          SupplementsHomeCard(tasks: enabledTasks),
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
        const SizedBox(height: 12),
        const ProgressiveOverloadCard(),
        const SizedBox(height: 10),
        const WeightGoalCard(),
        const SizedBox(height: 10),
        const WeeklyPRCard(),
        const SizedBox(height: 28),

        // ── Challenges ───────────────────────────────────────────────────
        const ChallengesHomeSection(),

        // ── Flash workouts ───────────────────────────────────────────────
        if (flashWorkouts.isNotEmpty) ...[
          const SizedBox(height: 28),
          ..._buildFlashWorkoutsSection(flashWorkouts),
        ],

        // ── Supplements ──────────────────────────────────────────────────
        if (enabledTasks.isNotEmpty) ...[
          const SizedBox(height: 28),
          SupplementsHomeCard(tasks: enabledTasks),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String? emoji;
  final String label;
  const _SectionLabel({this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (emoji != null) ...[
            Text(emoji!, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
