import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import '../../widgets/liquid_glass_container.dart';
import 'bodyweight_screen.dart';
import 'exercise_library_screen.dart';
import 'program_list_screen.dart';
import '../tasks/daily_tasks_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ── Training group ──────────────────────────────────────────
              _SectionLabel(label: 'TRAINING'),
              const SizedBox(height: 8),
              LiquidGlassContainer(
                borderRadius: 20,
                blurSigma: 10,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.fitness_center,
                      title: 'Manage Programs',
                      onTap: () => Navigator.of(context).push(
                        glassRoute(const ProgramListScreen()),
                      ),
                    ),
                    _Divider(),
                    _SettingsTile(
                      icon: Icons.check_circle_outline,
                      title: 'Daily Tasks',
                      subtitle: 'Manage your daily goals',
                      onTap: () => Navigator.of(context).push(
                        glassRoute(const DailyTasksScreen()),
                      ),
                    ),
                    _Divider(),
                    _SettingsTile(
                      icon: Icons.library_books_outlined,
                      title: 'Exercise Library',
                      subtitle: 'View and manage exercises',
                      onTap: () => Navigator.of(context).push(
                        glassRoute(const ExerciseLibraryScreen()),
                      ),
                    ),
                    _Divider(),
                    _SettingsTile(
                      icon: Icons.monitor_weight_outlined,
                      title: 'Log Body Weight',
                      subtitle: 'Track your weight over time',
                      onTap: () => Navigator.of(context).push(
                        glassRoute(const BodyweightScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Danger zone group ───────────────────────────────────────
              _SectionLabel(label: 'DATA'),
              const SizedBox(height: 8),
              LiquidGlassContainer(
                borderRadius: 20,
                blurSigma: 10,
                padding: EdgeInsets.zero,
                child: _SettingsTile(
                  icon: Icons.delete_sweep_outlined,
                  iconColor: Theme.of(context).colorScheme.error,
                  title: 'Clear All Sessions & PRs',
                  titleColor: Theme.of(context).colorScheme.error,
                  subtitle:
                      'Delete all logged sessions, sets, and personal records. Program setup is kept.',
                  onTap: () => _confirmClearHistory(context, ref),
                ),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
            )
          : null,
      trailing: Icon(Icons.chevron_right,
          size: 18, color: Colors.white.withValues(alpha: 0.25)),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.07),
    );
  }
}
