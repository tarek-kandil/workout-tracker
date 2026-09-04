import 'package:flutter/material.dart';

import '../../../models/exercise_muscle_seed.dart';
import '../../../utils/constants.dart';

/// Muscle + role assignment picker (design.md §5.3). Lets the athlete pick
/// exactly one primary muscle and any number of secondary muscles from the
/// 21-muscle taxonomy, grouped by body region and searchable.
///
/// Returns the new assignment list (primary first, then secondaries in
/// selection order), or `null` if the sheet was dismissed without saving.
Future<List<ExerciseMuscleSeed>?> showMuscleAssignmentSheet(
  BuildContext context, {
  required List<ExerciseMuscleSeed> initial,
}) {
  return showModalBottomSheet<List<ExerciseMuscleSeed>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _MuscleAssignmentSheet(initial: initial),
  );
}

class _MuscleAssignmentSheet extends StatefulWidget {
  final List<ExerciseMuscleSeed> initial;
  const _MuscleAssignmentSheet({required this.initial});

  @override
  State<_MuscleAssignmentSheet> createState() =>
      _MuscleAssignmentSheetState();
}

class _MuscleAssignmentSheetState extends State<_MuscleAssignmentSheet> {
  String? _primary;
  final List<String> _secondary = [];
  final _searchController = TextEditingController();
  String _query = '';

  static const _aliases = <String, List<String>>{
    'delt': ['Front Delts', 'Side Delts', 'Rear Delts'],
    'quad': ['Quads'],
    'ham': ['Hamstrings'],
    'lat': ['Lats'],
    'ab': ['Abs'],
    'calf': ['Calves'],
    'trap': ['Traps'],
  };

  @override
  void initState() {
    super.initState();
    for (final seed in widget.initial) {
      if (seed.role == ExerciseMuscleRole.primary && _primary == null) {
        _primary = seed.muscle;
      } else if (seed.role == ExerciseMuscleRole.secondary) {
        _secondary.add(seed.muscle);
      }
    }
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(String muscle) {
    if (_query.isEmpty) return true;
    if (muscle.toLowerCase().contains(_query)) return true;
    for (final entry in _aliases.entries) {
      if (entry.key.contains(_query) && entry.value.contains(muscle)) {
        return true;
      }
    }
    return false;
  }

  void _tapPrimary(String muscle) {
    setState(() {
      final previousPrimary = _primary;
      _primary = muscle;
      _secondary.remove(muscle);
      if (previousPrimary != null &&
          previousPrimary != muscle &&
          !_secondary.contains(previousPrimary)) {
        _secondary.add(previousPrimary);
      }
    });
  }

  void _toggleSecondary(String muscle) {
    if (_primary == muscle) return;
    setState(() {
      if (_secondary.contains(muscle)) {
        _secondary.remove(muscle);
      } else {
        _secondary.add(muscle);
      }
    });
  }

  void _clear() {
    setState(() {
      _primary = null;
      _secondary.clear();
    });
  }

  void _save() {
    final result = <ExerciseMuscleSeed>[
      if (_primary != null) ExerciseMuscleSeed.primary(_primary!),
      for (final m in _secondary) ExerciseMuscleSeed.secondary(m),
    ];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assign muscles',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Primary counts 1 set. Secondary counts 0.5.',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.55))),
                  const SizedBox(height: 12),
                  _SelectedSummary(
                    primary: _primary,
                    secondary: _secondary,
                    onRemovePrimary: () => setState(() => _primary = null),
                    onRemoveSecondary: (m) =>
                        setState(() => _secondary.remove(m)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search muscles…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildList(scrollController, cs),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _clear,
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _primary == null ? null : _save,
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(ScrollController scrollController, ColorScheme cs) {
    final entries = kMusclesByRegion.entries
        .map((e) => MapEntry(e.key, e.value.where(_matchesQuery).toList()))
        .where((e) => e.value.isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No muscle found for "$_query". Try lats, quads, or delts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (_, index) {
        var remaining = index;
        for (final entry in entries) {
          if (remaining == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            );
          }
          remaining--;
          if (remaining < entry.value.length) {
            final muscle = entry.value[remaining];
            return _MuscleRow(
              muscle: muscle,
              isPrimary: _primary == muscle,
              isSecondary: _secondary.contains(muscle),
              onTapPrimary: () => _tapPrimary(muscle),
              onTapSecondary: () => _toggleSecondary(muscle),
            );
          }
          remaining -= entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  final String? primary;
  final List<String> secondary;
  final VoidCallback onRemovePrimary;
  final void Function(String) onRemoveSecondary;
  const _SelectedSummary({
    required this.primary,
    required this.secondary,
    required this.onRemovePrimary,
    required this.onRemoveSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (primary == null)
          _DashedPill(label: 'Choose primary')
        else
          _RemovablePill(
            label: 'Primary · $primary',
            icon: Icons.adjust_rounded,
            color: const Color(0xFF818CF8),
            onRemove: onRemovePrimary,
          ),
        if (secondary.isEmpty)
          Text('Secondary muscles optional',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45)))
        else
          for (final m in secondary)
            _RemovablePill(
              label: m,
              icon: Icons.circle_outlined,
              color: Colors.white.withValues(alpha: 0.7),
              onRemove: () => onRemoveSecondary(m),
            ),
      ],
    );
  }
}

class _DashedPill extends StatelessWidget {
  final String label;
  const _DashedPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3), style: BorderStyle.solid),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.6))),
    );
  }
}

class _RemovablePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onRemove;
  const _RemovablePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 13, color: color),
          ),
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final String muscle;
  final bool isPrimary;
  final bool isSecondary;
  final VoidCallback onTapPrimary;
  final VoidCallback onTapSecondary;
  const _MuscleRow({
    required this.muscle,
    required this.isPrimary,
    required this.isSecondary,
    required this.onTapPrimary,
    required this.onTapSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isPrimary || isSecondary ? onTapSecondary : onTapPrimary,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(muscle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              _RoleButton(
                label: 'Primary',
                selected: isPrimary,
                onTap: onTapPrimary,
              ),
              const SizedBox(width: 6),
              _RoleButton(
                label: 'Secondary',
                selected: isSecondary,
                onTap: isPrimary ? null : onTapSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _RoleButton({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final color = selected ? const Color(0xFF818CF8) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF818CF8).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF818CF8).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: disabled ? color.withValues(alpha: 0.25) : color.withValues(alpha: selected ? 1 : 0.5),
          ),
        ),
      ),
    );
  }
}
