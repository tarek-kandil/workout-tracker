import 'package:flutter/material.dart';
import 'weight_goal_calculations.dart';

/// Shared color/icon/label mapping for [WeightGoalVerdict] so the Weight Hub,
/// the post-weigh-in status card, and the home tile all agree on status
/// treatment. Every status pairs a color with a distinct icon + label so
/// meaning never depends on color alone (accessibility).
class WeightGoalStatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const WeightGoalStatusStyle(
      {required this.color, required this.icon, required this.label});

  static const _cyan = Color(0xFF38BDF8);
  static const _indigo = Color(0xFF818CF8);
  static const _amber = Color(0xFFFF9F0A);
  static const _orange = Color(0xFFFF7A00);
  static const _red = Color(0xFFFF453A);
  static const _neutral = Color(0x73FFFFFF); // white45

  static WeightGoalStatusStyle of(WeightGoalVerdict verdict) {
    switch (verdict) {
      case WeightGoalVerdict.noPlan:
        return const WeightGoalStatusStyle(
          color: _neutral,
          icon: Icons.flag_outlined,
          label: 'No goal set',
        );
      case WeightGoalVerdict.buildingTrend:
        return const WeightGoalStatusStyle(
          color: _neutral,
          icon: Icons.hourglass_top_rounded,
          label: 'Building trend',
        );
      case WeightGoalVerdict.onTrack:
        return const WeightGoalStatusStyle(
          color: _cyan,
          icon: Icons.check_circle_rounded,
          label: 'On track',
        );
      case WeightGoalVerdict.ahead:
        return const WeightGoalStatusStyle(
          color: _indigo,
          icon: Icons.trending_up_rounded,
          label: 'Ahead of pace',
        );
      case WeightGoalVerdict.behind:
        return const WeightGoalStatusStyle(
          color: _amber,
          icon: Icons.trending_down_rounded,
          label: 'Behind pace',
        );
      case WeightGoalVerdict.tooFast:
        return const WeightGoalStatusStyle(
          color: _orange,
          icon: Icons.speed_rounded,
          label: 'Too fast',
        );
      case WeightGoalVerdict.unsafe:
        return const WeightGoalStatusStyle(
          color: _red,
          icon: Icons.error_rounded,
          label: 'Unsafe pace',
        );
      case WeightGoalVerdict.plateau:
        return const WeightGoalStatusStyle(
          color: _amber,
          icon: Icons.trending_flat_rounded,
          label: 'Plateau',
        );
      case WeightGoalVerdict.maintenanceOnTrack:
        return const WeightGoalStatusStyle(
          color: _cyan,
          icon: Icons.check_circle_rounded,
          label: 'Stable',
        );
      case WeightGoalVerdict.goalReached:
        return const WeightGoalStatusStyle(
          color: _indigo,
          icon: Icons.emoji_events_rounded,
          label: 'Goal reached',
        );
    }
  }
}
