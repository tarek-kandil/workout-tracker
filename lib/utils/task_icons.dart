import 'package:flutter/material.dart';

typedef TaskIconDef = ({IconData icon, Color color, String label});

const Map<String, TaskIconDef> kTaskIcons = {
  'sun':      (icon: Icons.wb_sunny_rounded,              color: Color(0xFFFF9F0A), label: 'Morning'),
  'moon':     (icon: Icons.bedtime_rounded,               color: Color(0xFF5E5CE6), label: 'Night'),
  'fire':     (icon: Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), label: 'Energy'),
  'dumbbell': (icon: Icons.fitness_center,                color: Color(0xFF30D158), label: 'Workout'),
  'run':      (icon: Icons.directions_run,                color: Color(0xFF32ADE6), label: 'Cardio'),
  'walk':     (icon: Icons.directions_walk_rounded,       color: Color(0xFF34C759), label: 'Walk'),
  'water':    (icon: Icons.water_drop_rounded,            color: Color(0xFF32ADE6), label: 'Hydration'),
  'pill':     (icon: Icons.medication_rounded,            color: Color(0xFFFF453A), label: 'Medication'),
  'science':  (icon: Icons.science_rounded,               color: Color(0xFF64D2FF), label: 'Supplement'),
  'food':     (icon: Icons.restaurant_rounded,            color: Color(0xFFFF9F0A), label: 'Nutrition'),
  'scale':    (icon: Icons.monitor_weight_rounded,        color: Color(0xFF30D158), label: 'Weight'),
  'yoga':     (icon: Icons.self_improvement,              color: Color(0xFF5E5CE6), label: 'Yoga'),
  'heart':    (icon: Icons.favorite_rounded,              color: Color(0xFFFF2D55), label: 'Health'),
  'brain':    (icon: Icons.psychology_rounded,            color: Color(0xFF5AC8FA), label: 'Mental'),
  'spa':      (icon: Icons.spa_rounded,                   color: Color(0xFF34C759), label: 'Recovery'),
  'coffee':   (icon: Icons.coffee_rounded,                color: Color(0xFFAC8E68), label: 'Coffee'),
  'book':     (icon: Icons.menu_book_rounded,             color: Color(0xFFFF9F0A), label: 'Reading'),
  'sleep':    (icon: Icons.king_bed_rounded,              color: Color(0xFF5E5CE6), label: 'Sleep'),
  'timer':    (icon: Icons.timer_rounded,                 color: Color(0xFF32ADE6), label: 'Timer'),
  'star':     (icon: Icons.star_rounded,                  color: Color(0xFFFFD60A), label: 'Goal'),
};

/// Returns the [TaskIconDef] for [key], falling back to a neutral default.
TaskIconDef resolveTaskIcon(String? key) =>
    kTaskIcons[key] ??
    (icon: Icons.check_circle_outline_rounded, color: const Color(0xFF8E8E93), label: 'Default');
