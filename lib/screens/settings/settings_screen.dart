import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../providers/session_providers.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/profile_calculations.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import 'exercise_library_screen.dart';
import 'profile_screen.dart';
import 'program_list_screen.dart';
import '../tasks/daily_tasks_screen.dart';
import '../history/session_history_screen.dart';
import '../weight/weight_hub_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    ProfileCalculations? calc;
    if (profile != null &&
        profile.age != null &&
        profile.heightCm != null &&
        profile.weightKg != null) {
      calc = ProfileCalculations(
        gender: profile.gender,
        age: profile.age!,
        heightCm: profile.heightCm!,
        weightKg: profile.weightKg!,
        targetWeightKg: profile.targetWeightKg ?? profile.weightKg!,
        fitnessGoal: profile.fitnessGoal,
        activityLevel: profile.activityLevel,
        weeklyRateKg: profile.weeklyRateKg ??
            ProfileCalculations.recommendedRate(profile.fitnessGoal),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          ListView(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 50),
            children: [
              // ── Profile hero ────────────────────────────────────────────
              _ProfileHeroCard(
                profile: profile,
                calc: calc,
                onTap: () => Navigator.of(context).push(
                  glassRoute(const ProfileScreen()),
                ),
              ),
              const SizedBox(height: 24),

              // ── Training grid ───────────────────────────────────────────
              _SectionLabel(label: 'TRAINING'),
              const SizedBox(height: 8),
              _NavGrid(
                items: [
                  _NavItem(
                    icon: Icons.fitness_center,
                    color: const Color(0xFF6366F1),
                    title: 'Programs',
                    subtitle: 'Manage plans',
                    onTap: () => Navigator.of(context).push(
                      glassRoute(const ProgramListScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.task_alt,
                    color: const Color(0xFF34C759),
                    title: 'Daily Tasks',
                    subtitle: 'Your goals',
                    onTap: () => Navigator.of(context).push(
                      glassRoute(const DailyTasksScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.history,
                    color: const Color(0xFF32ADE6),
                    title: 'History',
                    subtitle: 'Past sessions',
                    onTap: () => Navigator.of(context).push(
                      glassRoute(const SessionHistoryScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.menu_book,
                    color: const Color(0xFFFF9F0A),
                    title: 'Exercises',
                    subtitle: 'Library',
                    onTap: () => Navigator.of(context).push(
                      glassRoute(const ExerciseLibraryScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.monitor_weight_outlined,
                    color: const Color(0xFF38BDF8),
                    title: 'Weight',
                    subtitle: 'Goal & log',
                    onTap: () => Navigator.of(context).push(
                      glassRoute(const WeightHubScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Appearance ──────────────────────────────────────────────
              _SectionLabel(label: 'APPEARANCE'),
              const SizedBox(height: 6),
              _AppearanceTile(ref: ref),
              const SizedBox(height: 24),

              // ── Data / danger ───────────────────────────────────────────
              _SectionLabel(label: 'DATA'),
              const SizedBox(height: 8),
              _DangerCard(
                onTap: () => _confirmClearHistory(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Sessions & PRs?'),
        content: const Text(
            'This will permanently delete all logged sessions, sets, and '
            'personal records. Your program setup and exercise library are kept. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All History'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final db = ref.read(databaseProvider);
    await db.setsDao.clearAllSets();
    await db.sessionsDao.clearAllSessions();

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);
    ref.invalidate(personalRecordsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout history cleared.')),
      );
    }
  }
}

// ── Profile hero card ─────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  final UserProfile? profile;
  final ProfileCalculations? calc;
  final VoidCallback onTap;

  const _ProfileHeroCard({
    required this.profile,
    required this.calc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile?.name.isNotEmpty == true ? profile!.name : null;
    final hasStats = calc != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.22),
              cs.primary.withValues(alpha: 0.07),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
        ),
        child: Row(children: [
          // Avatar
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.18),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.45), width: 2),
            ),
            child: Icon(Icons.person_rounded, size: 28, color: cs.primary),
          ),
          const SizedBox(width: 14),

          // Name + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'Set up your profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: name != null
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                if (hasStats) ...[
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _HeroBadge(
                      label:
                          'BMI ${calc!.bmi.toStringAsFixed(1)} · ${calc!.bmiCategory}',
                      color: _bmiColor(calc!.bmi),
                    ),
                    _HeroBadge(
                      label: '${calc!.dailyCalories.round()} kcal',
                      color: cs.primary,
                    ),
                  ]),
                ] else ...[
                  Text(
                    'Tap to add your details →',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Icon(Icons.chevron_right_rounded,
              size: 22, color: cs.onSurface.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF32ADE6);
    if (bmi < 25) return const Color(0xFF34C759);
    if (bmi < 30) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _HeroBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Nav grid ──────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _NavGrid extends StatelessWidget {
  final List<_NavItem> items;
  const _NavGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile(_NavItem item) => GestureDetector(
          onTap: item.onTap,
          child: LiquidGlassContainer(
            borderRadius: 16,
            blurSigma: 10,
            tintColor: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.white.withValues(alpha: 0.80),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row + Spacer forces the Column to fill the full tile width
                Row(
                  children: [
                    Icon(item.icon, size: 26, color: item.color),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );

    final rows = <List<_NavItem>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(items.sublist(i, i + 2 > items.length ? items.length : i + 2));
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows[i].length == 2
                  ? [
                      Expanded(child: tile(rows[i][0])),
                      const SizedBox(width: 10),
                      Expanded(child: tile(rows[i][1])),
                    ]
                  : [Expanded(child: tile(rows[i][0]))],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Appearance tile ───────────────────────────────────────────────────────────

class _AppearanceTile extends StatelessWidget {
  final WidgetRef ref;
  const _AppearanceTile({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDarkMode = ref.watch(themeProvider).brightness == Brightness.dark;

    return LiquidGlassContainer(
      borderRadius: 18,
      blurSigma: 10,
      tintColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.80),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        const Icon(Icons.dark_mode, size: 26, color: Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Dark Mode',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        Switch(
          value: isDarkMode,
          onChanged: (_) =>
              ref.read(themeProvider.notifier).toggleBrightness(),
        ),
      ]),
    );
  }
}

// ── Danger card ───────────────────────────────────────────────────────────────

class _DangerCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DangerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF453A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: red.withValues(alpha: 0.28)),
        ),
        child: Row(children: [
          const Icon(Icons.delete, size: 26, color: Color(0xFFFF453A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Clear All Sessions & PRs',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: red)),
              const SizedBox(height: 2),
              Text('Permanently removes all history',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: red.withValues(alpha: 0.6))),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: red.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              )),
    );
  }
}
