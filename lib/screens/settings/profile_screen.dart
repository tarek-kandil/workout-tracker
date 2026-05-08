import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../utils/profile_calculations.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/liquid_glass_container.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ── Form state ────────────────────────────────────────────────────────────────
  String _name = '';
  bool _editingName = false;
  late final TextEditingController _nameCtrl = TextEditingController();
  String _gender = 'male';
  int? _age;
  double? _heightCm;
  double? _weightKg;
  double? _targetWeightKg;
  String _fitnessGoal = 'maintain';
  String _activityLevel = 'moderate';
  double _weeklyRateKg = 0.5;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile =
        await ref.read(databaseProvider).userProfileDao.getProfile();
    if (profile != null && mounted) {
      setState(() {
        _name = profile.name;
        _nameCtrl.text = profile.name;
        _gender = profile.gender;
        _age = profile.age;
        _heightCm = profile.heightCm;
        _weightKg = profile.weightKg;
        _targetWeightKg = profile.targetWeightKg;
        _fitnessGoal = profile.fitnessGoal;
        _activityLevel = profile.activityLevel;
        _weeklyRateKg = profile.weeklyRateKg ??
            ProfileCalculations.recommendedRate(profile.fitnessGoal);
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    await ref.read(databaseProvider).userProfileDao.upsertProfile(
          UserProfilesCompanion(
            name: Value(_nameCtrl.text.trim()),
            gender: Value(_gender),
            age: Value(_age),
            heightCm: Value(_heightCm),
            weightKg: Value(_weightKg),
            targetWeightKg: Value(_targetWeightKg),
            fitnessGoal: Value(_fitnessGoal),
            activityLevel: Value(_activityLevel),
            weeklyRateKg: Value(_weeklyRateKg),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  ProfileCalculations? get _calc {
    if (_age == null || _heightCm == null || _weightKg == null) return null;
    return ProfileCalculations(
      gender: _gender,
      age: _age!,
      heightCm: _heightCm!,
      weightKg: _weightKg!,
      targetWeightKg: _targetWeightKg ?? _weightKg!,
      fitnessGoal: _fitnessGoal,
      activityLevel: _activityLevel,
      weeklyRateKg: _weeklyRateKg,
    );
  }



  Future<void> _showAgePicker() async {
    final initVal = (_age ?? 25).clamp(10, 100);
    final ctrl = FixedExtentScrollController(initialItem: initVal - 10);
    int selected = initVal;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => _drumSheet(
        ctx: ctx,
        title: 'Age',
        onDone: () => Navigator.pop(ctx, selected),
        picker: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 100, height: 220,
            child: ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: 44,
              perspective: 0.004,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => selected = i + 10,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 91,
                builder: (_, i) => Center(child: Text('${i + 10}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ),
          const Text(' yrs', style: TextStyle(fontSize: 16, color: Colors.white38, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
    if (result != null && mounted) setState(() => _age = result);
  }

  // ── Drum pickers ─────────────────────────────────────────────────────────────

  static const _sheetBg = Color(0xFF1C1C20);

  Future<void> _showHeightPicker() async {
    final initVal = (_heightCm ?? 170).clamp(100.0, 250.0);
    final initIdx = (initVal - 100).round();
    final ctrl = FixedExtentScrollController(initialItem: initIdx);
    int selected = initIdx + 100;

    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => _drumSheet(
        ctx: ctx,
        title: 'Height',
        onDone: () => Navigator.pop(ctx, selected.toDouble()),
        picker: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 100, height: 220,
            child: ListWheelScrollView.useDelegate(
              controller: ctrl,
              itemExtent: 44,
              perspective: 0.004,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => selected = i + 100,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 151,
                builder: (_, i) => Center(child: Text('${i + 100}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ),
          const Text(' cm', style: TextStyle(fontSize: 16, color: Colors.white38, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
    if (result != null && mounted) setState(() => _heightCm = result);
  }

  Future<void> _showWeightPicker(String title, double? current, void Function(double) onSave) async {
    final initVal = (current ?? 70).clamp(30.0, 300.0);
    final initInt = initVal.floor().clamp(30, 300);
    final initDecIdx = (initVal - initInt) >= 0.25 ? 1 : 0;

    final intCtrl = FixedExtentScrollController(initialItem: initInt - 30);
    final decCtrl = FixedExtentScrollController(initialItem: initDecIdx);

    int selInt = initInt;
    int selDecIdx = initDecIdx;

    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => _drumSheet(
        ctx: ctx,
        title: title,
        onDone: () => Navigator.pop(ctx, selInt + (selDecIdx == 1 ? 0.5 : 0.0)),
        picker: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: 110, height: 220,
            child: ListWheelScrollView.useDelegate(
              controller: intCtrl,
              itemExtent: 44,
              perspective: 0.004,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => selInt = i + 30,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: 271,
                builder: (_, i) => Center(child: Text('${i + 30}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ),
          const Text('.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(
            width: 70, height: 220,
            child: ListWheelScrollView(
              controller: decCtrl,
              itemExtent: 44,
              perspective: 0.004,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => selDecIdx = i,
              children: const [
                Center(child: Text('0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
                Center(child: Text('5', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
              ],
            ),
          ),
          const Text(' kg', style: TextStyle(fontSize: 16, color: Colors.white38, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
    if (result != null && mounted) onSave(result);
  }

  Widget _drumSheet({
    required BuildContext ctx,
    required String title,
    required Widget picker,
    required VoidCallback onDone,
  }) {
    final primary = Theme.of(ctx).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: _sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(fontSize: 16, color: Colors.white38)),
            ),
            Expanded(child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            GestureDetector(
              onTap: onDone,
              child: Text('Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
            ),
          ]),
        ),
        SizedBox(
          height: 220,
          child: Stack(children: [
            // Selection highlight
            Center(
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Picker wheels
            Center(child: picker),
            // Top fade
            Positioned(
              top: 0, left: 0, right: 0, height: 88,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [_sheetBg, Color(0x001C1C20)],
                  )),
                ),
              ),
            ),
            // Bottom fade
            Positioned(
              bottom: 0, left: 0, right: 0, height: 88,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [_sheetBg, Color(0x001C1C20)],
                  )),
                ),
              ),
            ),
          ]),
        ),
        SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final calc = _calc;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(
                    color: cs.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          if (!_loaded)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 50),
              children: [
                // ── Hero ───────────────────────────────────────────────────
                _HeroHeader(
                  name: _name.isEmpty ? 'You' : _name,
                  calc: calc,
                  editing: _editingName,
                  nameCtrl: _nameCtrl,
                  onStartEdit: () => setState(() {
                    _editingName = true;
                    _nameCtrl.selection = TextSelection.collapsed(
                      offset: _nameCtrl.text.length,
                    );
                  }),
                  onDoneEdit: () => setState(() {
                    _name = _nameCtrl.text.trim();
                    _editingName = false;
                  }),
                ),
                const SizedBox(height: 20),

                // ── Personal info ──────────────────────────────────────────
                _SectionLabel(label: 'PERSONAL INFO'),
                const SizedBox(height: 8),
                _InfoCard(children: [
                  _InfoRow(
                    icon: Icons.wc_rounded,
                    iconColor: const Color(0xFF5E5CE6),
                    label: 'Gender',
                    valueWidget: _GenderPills(
                      selected: _gender,
                      onChanged: (g) => setState(() => _gender = g),
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.cake_outlined,
                    iconColor: const Color(0xFFFF9F0A),
                    label: 'Age',
                    value: _age != null ? '$_age yrs' : 'Tap to set',
                    onTap: _showAgePicker,
                  ),
                  _InfoRow(
                    icon: Icons.straighten_rounded,
                    iconColor: const Color(0xFF32ADE6),
                    label: 'Height',
                    value: _heightCm != null
                        ? '${_heightCm!.toStringAsFixed(0)} cm'
                        : 'Tap to set',
                    onTap: _showHeightPicker,
                  ),
                  _InfoRow(
                    icon: Icons.monitor_weight_outlined,
                    iconColor: const Color(0xFF34C759),
                    label: 'Current Weight',
                    value: _weightKg != null
                        ? '${_weightKg!.toStringAsFixed(1)} kg'
                        : 'Tap to set',
                    onTap: () => _showWeightPicker(
                        'Current Weight', _weightKg,
                        (v) => setState(() => _weightKg = v)),
                  ),
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    iconColor: const Color(0xFFFF453A),
                    label: 'Target Weight',
                    value: _targetWeightKg != null
                        ? '${_targetWeightKg!.toStringAsFixed(1)} kg'
                        : 'Tap to set',
                    onTap: () => _showWeightPicker(
                        'Target Weight', _targetWeightKg,
                        (v) => setState(() => _targetWeightKg = v)),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Fitness goal ────────────────────────────────────────────
                _SectionLabel(label: 'FITNESS GOAL'),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: _GoalGrid(
                    selected: _fitnessGoal,
                    onChanged: (g) => setState(() => _fitnessGoal = g),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Pace picker (lose/build only) ───────────────────────────
                if (_fitnessGoal == 'lose' || _fitnessGoal == 'build') ...[
                  const SizedBox(height: 20),
                  _SectionLabel(
                    label: _fitnessGoal == 'lose'
                        ? 'HOW FAST TO LOSE'
                        : 'HOW FAST TO BUILD',
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: _PacePicker(
                      goal: _fitnessGoal,
                      selected: _weeklyRateKg,
                      onChanged: (v) => setState(() => _weeklyRateKg = v),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // ── Activity level ──────────────────────────────────────────
                _SectionLabel(label: 'ACTIVITY LEVEL'),
                const SizedBox(height: 8),
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  child: _ActivitySelector(
                    selected: _activityLevel,
                    onChanged: (a) => setState(() => _activityLevel = a),
                  ),
                ),

                // ── Results ─────────────────────────────────────────────────
                if (calc != null) ...[
                  const SizedBox(height: 20),
                  _SectionLabel(label: 'YOUR ESTIMATES'),
                  const SizedBox(height: 8),
                  _ResultsCard(calc: calc),
                  if (calc.paceWarning != null) ...[
                    const SizedBox(height: 10),
                    _PaceWarningBanner(
                      level: calc.paceWarning!,
                      goal: _fitnessGoal,
                    ),
                  ],
                  if (calc.estimatedWeeks != null) ...[
                    const SizedBox(height: 10),
                    _TimelineCard(calc: calc),
                  ],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String name;
  final ProfileCalculations? calc;
  final bool editing;
  final TextEditingController nameCtrl;
  final VoidCallback onStartEdit;
  final VoidCallback onDoneEdit;

  const _HeroHeader({
    required this.name,
    required this.calc,
    required this.editing,
    required this.nameCtrl,
    required this.onStartEdit,
    required this.onDoneEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const nameStyle = TextStyle(fontSize: 28, fontWeight: FontWeight.w800);

    return Column(children: [
      GestureDetector(
        onTap: editing ? null : onStartEdit,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: 0.15),
            border: Border.all(color: cs.primary.withValues(alpha: 0.4), width: 2),
          ),
          child: Icon(Icons.person_rounded, size: 36, color: cs.primary),
        ),
      ),
      const SizedBox(height: 10),

      // ── Inline name edit ──────────────────────────────────────────
      if (editing)
        SizedBox(
          width: 240,
          child: TextField(
            controller: nameCtrl,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            style: nameStyle,
            cursorColor: cs.primary,
            decoration: const InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => onDoneEdit(),
          ),
        )
      else
        // Pencil sits visually next to name but doesn't shift the center:
        // a ghost SizedBox of the same width on the left balances it out.
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 40), // balances the icon on the right
              GestureDetector(
                onTap: onStartEdit,
                child: Text(name, style: nameStyle),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: onStartEdit,
                child: Icon(Icons.edit_rounded,
                    size: 22,
                    color: cs.onSurface.withValues(alpha: 0.35)),
              ),
            ],
          ),
        ),

      // ── Done button (visible while editing) ───────────────────────
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        child: editing
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onTap: onDoneEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text('Done',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),

      if (calc != null) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Badge(
            label: 'BMI ${calc!.bmi.toStringAsFixed(1)} · ${calc!.bmiCategory}',
            color: _bmiColor(calc!.bmi),
          ),
          const SizedBox(width: 8),
          _Badge(
            label: '${calc!.dailyCalories.round()} kcal/day',
            color: cs.primary,
          ),
        ]),
      ],
    ]);
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF32ADE6);
    if (bmi < 25) return const Color(0xFF34C759);
    if (bmi < 30) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Info card / rows ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LiquidGlassContainer(
      borderRadius: 20,
      blurSigma: 10,
      tintColor: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.80),
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final VoidCallback? onTap;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.valueWidget,
    this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              if (valueWidget != null) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 6),
                      valueWidget!,
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14))),
                Text(value ?? '',
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.25)),
                ],
              ],
            ]),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 60,
              endIndent: 16,
              color: cs.onSurface.withValues(alpha: 0.07)),
      ],
    );
  }
}

// ── Gender pills ──────────────────────────────────────────────────────────────

class _GenderPills extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _GenderPills({required this.selected, required this.onChanged});

  static const _options = [
    ('male', 'Male'),
    ('female', 'Female'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.map((opt) {
        final isSelected = selected == opt.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.2)
                    : cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.5)
                        : Colors.transparent),
              ),
              child: Text(opt.$2,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.5))),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Goal grid ─────────────────────────────────────────────────────────────────

class _GoalGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _GoalGrid({required this.selected, required this.onChanged});

  static const _goals = [
    ('lose', '🔥', 'Lose Weight'),
    ('build', '💪', 'Build Muscle'),
    ('maintain', '⚖️', 'Maintain'),
    ('fitness', '🏃', 'Improve Fitness'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: _goals.map((g) {
        final isSelected = selected == g.$1;
        return GestureDetector(
          onTap: () => onChanged(g.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.18)
                  : cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.5)
                      : Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(g.$2, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(g.$3,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Activity level ────────────────────────────────────────────────────────────

class _ActivitySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ActivitySelector({required this.selected, required this.onChanged});

  static const _levels = [
    ('sedentary', '🪑', 'Sedentary', 'Desk job'),
    ('light',     '🚶', 'Light',     '1–3×/wk'),
    ('moderate',  '🏃', 'Moderate',  '3–5×/wk'),
    ('active',    '💪', 'Active',    '6–7×/wk'),
    ('athletic',  '🏋️', 'Athletic',  '2×/day'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _levels.map((l) {
        final (key, emoji, name, days) = l;
        final isSelected = selected == key;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.18)
                    : cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 6),
                Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(days,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        color: cs.onSurface.withValues(alpha: 0.3),
                        height: 1.2)),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Results card ──────────────────────────────────────────────────────────────

class _ResultsCard extends StatelessWidget {
  final ProfileCalculations calc;
  const _ResultsCard({required this.calc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bmiColor = _bmiColor(calc.bmi);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.18),
            cs.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('✦  Calculated for you',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.primary.withValues(alpha: 0.8),
                letterSpacing: 0.8)),
        const SizedBox(height: 12),

        // BMI + Calories row
        Row(children: [
          Expanded(child: _ResultBox(
            label: 'BMI',
            value: calc.bmi.toStringAsFixed(1),
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    height: 5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color(0xFF32ADE6),
                        Color(0xFF34C759),
                        Color(0xFFFF9F0A),
                        Color(0xFFFF453A),
                      ]),
                    ),
                    child: Align(
                      alignment: Alignment(
                          (calc.bmiBarPosition * 2 - 1).clamp(-1.0, 1.0), 0),
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: bmiColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bmiColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(calc.bmiCategory,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: bmiColor)),
                ),
              ],
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ResultBox(
            label: 'Daily Calories',
            value: calc.dailyCalories.round().toString(),
            unit: 'kcal / day',
            bottom: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(calc.goalLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
              ),
            ),
          )),
        ]),

        const SizedBox(height: 10),

        // Macros row
        Row(children: [
          Expanded(child: _MacroBox(
            label: 'Protein',
            value: calc.proteinG.round().toString(),
            color: const Color(0xFFFF6B35),
          )),
          const SizedBox(width: 8),
          Expanded(child: _MacroBox(
            label: 'Carbs',
            value: calc.carbsG.round().toString(),
            color: const Color(0xFF32ADE6),
          )),
          const SizedBox(width: 8),
          Expanded(child: _MacroBox(
            label: 'Fat',
            value: calc.fatG.round().toString(),
            color: const Color(0xFFFFD60A),
          )),
        ]),

      ]),
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFF32ADE6);
    if (bmi < 25) return const Color(0xFF34C759);
    if (bmi < 30) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}

class _ResultBox extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Widget? bottom;
  const _ResultBox({required this.label, required this.value, this.unit, this.bottom});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        if (unit != null)
          Text(unit!,
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.4))),
        if (bottom != null) bottom!,
      ]),
    );
  }
}

class _MacroBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text('g/day',
            style: TextStyle(
                fontSize: 9, color: cs.onSurface.withValues(alpha: 0.35))),
      ]),
    );
  }
}

// ── Pace picker ───────────────────────────────────────────────────────────────

class _PacePicker extends StatelessWidget {
  final String goal;
  final double selected;
  final ValueChanged<double> onChanged;
  const _PacePicker(
      {required this.goal, required this.selected, required this.onChanged});

  // (rate kg/week, emoji, label, kcal/day rounded)
  static const _loseOptions = [
    (0.25, '🧘', 'Gentle', 275),
    (0.5,  '✅', 'Recommended', 550),
    (0.75, '⚡', 'Aggressive', 825),
    (1.0,  '🔥', 'Very fast', 1100),
  ];
  static const _buildOptions = [
    (0.1,  '🌱', 'Very lean', 110),
    (0.25, '✅', 'Recommended', 275),
    (0.5,  '⚡', 'Aggressive', 550),
    (0.75, '🔥', 'Very fast', 825),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = goal == 'lose' ? _loseOptions : _buildOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly pace',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.35),
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        Row(
          children: options.map((opt) {
            final (rate, emoji, label, kcal) = opt;
            final isSelected = (selected - rate).abs() < 0.01;
            final warning = _warningFor(goal, rate);
            final pillColor = warning == 'danger'
                ? const Color(0xFFFF453A)
                : warning == 'warn'
                    ? const Color(0xFFFF9F0A)
                    : const Color(0xFF34C759);
            final kcalStr = goal == 'lose' ? '−$kcal kcal' : '+$kcal kcal';

            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(rate),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? pillColor.withValues(alpha: 0.18)
                        : cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? pillColor.withValues(alpha: 0.55)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text('${rate}kg',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? pillColor
                                : cs.onSurface.withValues(alpha: 0.55))),
                    const SizedBox(height: 2),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? pillColor.withValues(alpha: 0.8)
                                : cs.onSurface.withValues(alpha: 0.3))),
                    const SizedBox(height: 5),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            pillColor.withValues(alpha: isSelected ? 0.15 : 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(kcalStr,
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: pillColor
                                  .withValues(alpha: isSelected ? 0.9 : 0.45))),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static String? _warningFor(String goal, double rate) {
    if (goal == 'lose') {
      if (rate >= 1.0) return 'danger';
      if (rate > 0.5) return 'warn';
    } else if (goal == 'build') {
      if (rate >= 0.75) return 'danger';
      if (rate > 0.25) return 'warn';
    }
    return null;
  }
}

// ── Pace warning banner ───────────────────────────────────────────────────────

class _PaceWarningBanner extends StatelessWidget {
  final String level; // 'warn' | 'danger'
  final String goal;
  const _PaceWarningBanner({required this.level, required this.goal});

  @override
  Widget build(BuildContext context) {
    final isDanger = level == 'danger';
    final color =
        isDanger ? const Color(0xFFFF453A) : const Color(0xFFFF9F0A);

    final message = isDanger
        ? (goal == 'lose'
            ? 'A deficit this large risks muscle loss, fatigue, and nutrient deficiencies. Most health guidelines cap weight loss at 0.5–1 kg/week.'
            : 'A surplus this large will lead to significant fat gain alongside muscle. A lean bulk is typically 0.1–0.25 kg/week.')
        : (goal == 'lose'
            ? 'This is on the aggressive side. You may experience hunger and some muscle loss. Manageable for most people, but listen to your body.'
            : 'A faster bulk means more fat gain alongside muscle. This is fine if you plan to cut later.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isDanger ? '⛔' : '⚠️', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isDanger ? 'Not recommended' : 'Heads up',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 3),
            Text(message,
                style: TextStyle(
                    fontSize: 11.5,
                    color: color.withValues(alpha: 0.8),
                    height: 1.45)),
            const SizedBox(height: 6),
            Text('You can still proceed — this is your choice.',
                style: TextStyle(
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    color: color.withValues(alpha: 0.55))),
          ]),
        ),
      ]),
    );
  }
}

// ── Timeline card ─────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final ProfileCalculations calc;
  const _TimelineCard({required this.calc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weeks = calc.estimatedWeeks!;
    final dateLabel = calc.estimatedDateLabel;
    final isLosing = calc.fitnessGoal == 'lose';

    final color = isLosing ? const Color(0xFF32ADE6) : const Color(0xFF34C759);
    final icon = isLosing ? '📉' : '📈';
    final verb = isLosing ? 'reach' : 'reach';
    final targetStr =
        '${calc.targetWeightKg.toStringAsFixed(1)} kg';

    // Progress so far (assume we start at weightKg)
    final totalDiff = (calc.weightKg - calc.targetWeightKg).abs();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('Your timeline',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
          const Spacer(),
          if (dateLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(dateLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(weeks.round().toString(),
              style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  height: 1.0)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('weeks to $verb\n$targetStr',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    height: 1.4)),
          ),
        ]),
        const SizedBox(height: 10),
        // Progress bar (starts empty — we're at the beginning)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(
                height: 6,
                color: color.withValues(alpha: 0.12)),
            Container(
                height: 6,
                width: 0, // no progress yet — user just set the goal
                color: color),
          ]),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${calc.weightKg.toStringAsFixed(1)} kg now',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.35))),
            Text('$targetStr goal',
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.35))),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'At ${calc.weeklyRateKg < 0.15 ? calc.weeklyRateKg.toStringAsFixed(2) : calc.weeklyRateKg.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} kg/week · ${(calc.dailyCalories - calc.tdee).abs().round()} kcal ${isLosing ? 'deficit' : 'surplus'}/day · ${totalDiff.toStringAsFixed(1)} kg to go',
          style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.4),
              height: 1.3),
        ),
      ]),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ));
  }
}
