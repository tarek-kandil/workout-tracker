import 'package:flutter/material.dart';

import '../models/weekly_muscle_volume.dart';

/// Athlete-facing style (color + icon + shape marker) for one of the three
/// muscle-volume statuses. See design.md §3 — colorblind-safe (never color
/// alone) and theme-aware (separate dark/light hex values).
class VolumeStatusStyle {
  final Color color;
  final IconData icon;
  final String label;
  final IconData markerIcon;

  const VolumeStatusStyle({
    required this.color,
    required this.icon,
    required this.label,
    required this.markerIcon,
  });

  static VolumeStatusStyle of(MuscleVolumeStatus status, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case MuscleVolumeStatus.undertrained:
        return VolumeStatusStyle(
          color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
          icon: Icons.trending_down_rounded,
          markerIcon: Icons.radio_button_unchecked,
          label: 'Undertrained',
        );
      case MuscleVolumeStatus.optimal:
        return VolumeStatusStyle(
          color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          icon: Icons.check_circle_rounded,
          markerIcon: Icons.circle,
          label: 'Optimal',
        );
      case MuscleVolumeStatus.overtrained:
        return VolumeStatusStyle(
          color: isDark ? const Color(0xFFE11D48) : const Color(0xFFBE123C),
          icon: Icons.warning_amber_rounded,
          markerIcon: Icons.change_history_rounded,
          label: 'Overtrained',
        );
    }
  }
}

/// Status pill reused across the report list, needs-attention card, and
/// home tile chips. Never color-only: always pairs an icon with the label.
class VolumeStatusPill extends StatelessWidget {
  final MuscleVolumeStatus status;
  final bool compact;
  const VolumeStatusPill({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style =
        VolumeStatusStyle.of(status, Theme.of(context).brightness);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 12 : 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }
}
