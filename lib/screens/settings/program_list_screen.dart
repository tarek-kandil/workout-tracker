import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../providers/program_providers.dart';
import '../../providers/database_provider.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_route.dart';
import 'program_setup_screen.dart';

// ── Colours ───────────────────────────────────────────────────────────────────
const _indigo = Color(0xFF6366F1);
const _indigoLight = Color(0xFF818CF8);
const _blue = Color(0xFF32ADE6);
const _blueLight = Color(0xFF67C9E8);
const _red = Color(0xFFFF453A);

class ProgramListScreen extends ConsumerWidget {
  const ProgramListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programsAsync = ref.watch(allProgramsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add),
        label: const Text('New Program',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _createNew(context),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          programsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (programs) {
              if (programs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No programs yet',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _createNew(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Program'),
                      ),
                    ],
                  ),
                );
              }

              final active =
                  programs.where((p) => p.status == 0).toList();
              final library =
                  programs.where((p) => p.status != 0).toList();

              final items = <Widget>[];

              if (active.isNotEmpty) {
                items.add(const _SectionLabel('Active'));
                for (final p in active) {
                  items.add(_ProgramTile(program: p));
                }
              }

              if (library.isNotEmpty) {
                items.add(_SectionLabel(active.isNotEmpty
                    ? 'Library'
                    : 'Library'));
                for (final p in library) {
                  items.add(_ProgramTile(program: p));
                }
              }

              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: items,
              );
            },
          ),
        ],
      ),
    );
  }

  void _createNew(BuildContext context) {
    Navigator.of(context).push(glassRoute(const ProgramSetupScreen()));
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Program tile ──────────────────────────────────────────────────────────────

class _ProgramTile extends ConsumerStatefulWidget {
  final Program program;
  const _ProgramTile({required this.program});

  @override
  ConsumerState<_ProgramTile> createState() => _ProgramTileState();
}

class _ProgramTileState extends ConsumerState<_ProgramTile> {
  int? _totalWeeks;

  @override
  void initState() {
    super.initState();
    _loadPhaseData();
  }

  Future<void> _loadPhaseData() async {
    final phases = await ref
        .read(databaseProvider)
        .programsDao
        .getPhasesForProgram(widget.program.id);
    if (!mounted) return;
    final total =
        phases.fold<int>(0, (sum, ph) => sum + ph.durationWeeks);
    setState(() => _totalWeeks = total > 0 ? total : null);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.program.status;
    final hasChip = status == 0 || status == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            glassRoute(
                ProgramSetupScreen(existingProgram: widget.program)),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // ── Card body ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    // Rim-light: 1px gradient line at the top
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Row 1: icon + info + actions ──────────
                          Padding(
                            padding: EdgeInsets.only(
                                right: hasChip ? 74.0 : 0.0),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                _IconBadge(status: status),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.program.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _totalWeeks != null
                                            ? '$_totalWeeks weeks'
                                            : '—',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white
                                              .withValues(alpha: 0.4),
                                        ),
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  constraints:
                                      const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: _red.withValues(alpha: 0.55),
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                          ),

                          // ── Progress bar (active only) ─────────────
                          if (status == 0) _ProgressBar(totalWeeks: _totalWeeks),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status chip (top-right, absolute) ─────────────────
              if (status == 0 || status == 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _StatusChip(status: status),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final isActive = widget.program.status == 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Program?'),
        content: Text(isActive
            ? 'WARNING: "${widget.program.name}" is your currently active program. Deleting it will remove the program and all its workouts. Your logged sessions will be kept. This cannot be undone.'
            : 'Delete "${widget.program.name}"? Its workouts will be removed. Logged sessions will not be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                  isActive ? 'Delete Active Program' : 'Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(databaseProvider)
          .programsDao
          .deleteProgram(widget.program.id);
      ref.invalidate(allProgramsProvider);
      ref.invalidate(activeProgramProvider);
    }
  }
}

// ── Icon badge ────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final int status;
  const _IconBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color badgeBg;
    final Color? badgeBorder;
    final Color iconColor;

    switch (status) {
      case 0: // active
        badgeBg = _indigo.withValues(alpha: 0.2);
        badgeBorder = _indigo.withValues(alpha: 0.3);
        iconColor = _indigoLight;
      case 1: // completed
        badgeBg = _blue.withValues(alpha: 0.15);
        badgeBorder = _blue.withValues(alpha: 0.25);
        iconColor = _blueLight;
      default: // draft
        badgeBg = Colors.white.withValues(alpha: 0.07);
        badgeBorder = Colors.white.withValues(alpha: 0.12);
        iconColor = Colors.white.withValues(alpha: 0.3);
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeBorder),
      ),
      child: Icon(Icons.fitness_center, size: 24, color: iconColor),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final int status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 0) {
      // Active — gradient pill
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_indigo, _indigoLight],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _indigo.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '● Active',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    // Completed
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.18),
        border: Border.all(color: _blue.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '✓ Completed',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _blueLight,
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends ConsumerWidget {
  final int? totalWeeks;
  const _ProgressBar({required this.totalWeeks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWeekAsync = ref.watch(currentProgramWeekProvider);

    return currentWeekAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (currentWeek) {
        final week = currentWeek ?? 1;
        final total = totalWeeks ?? 12;
        final progress = (week / total).clamp(0.0, 1.0);
        final pct = (progress * 100).round();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Text(
                'Week $week of $total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        _indigo.withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation(_indigo),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
