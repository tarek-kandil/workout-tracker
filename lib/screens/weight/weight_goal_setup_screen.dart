import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/weight_goal_plan.dart';
import '../../providers/home_providers.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/weight_goal_providers.dart';
import '../../utils/weight_goal_calculations.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/glass_card.dart';

/// Goal-setup screen (FR-004 — FR-013): choose direction, weights, target
/// date/duration and cadence, with a live pace/calorie/macro readout that
/// updates on every input change, plus caution/danger pace guardrails.
class WeightGoalSetupScreen extends ConsumerStatefulWidget {
  const WeightGoalSetupScreen({super.key});

  @override
  ConsumerState<WeightGoalSetupScreen> createState() =>
      _WeightGoalSetupScreenState();
}

class _WeightGoalSetupScreenState extends ConsumerState<WeightGoalSetupScreen> {
  String _goalDirection = 'lose';
  double _currentWeightKg = 70;
  double _desiredWeightKg = 65;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 56));
  int _cadenceDays = 7;
  bool _remindersEnabled = true;

  bool _initialized = false;
  bool _saving = false;

  late final TextEditingController _currentWeightCtrl;
  late final TextEditingController _desiredWeightCtrl;
  late final TextEditingController _customCadenceCtrl;

  @override
  void initState() {
    super.initState();
    _currentWeightCtrl = TextEditingController();
    _desiredWeightCtrl = TextEditingController();
    _customCadenceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _currentWeightCtrl.dispose();
    _desiredWeightCtrl.dispose();
    _customCadenceCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile() {
    if (_initialized) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    final latest = ref.read(latestBodyweightProvider).valueOrNull;
    final plan = ref.read(weightGoalPlanProvider);

    if (plan != null) {
      // Editing an existing plan.
      _goalDirection = plan.goalDirection;
      _currentWeightKg = latest?.weightKg ?? plan.startWeightKg;
      _desiredWeightKg = plan.targetWeightKg;
      _targetDate = plan.targetDate;
      _cadenceDays = plan.weighInIntervalDays;
      _remindersEnabled = plan.remindersEnabled;
    } else {
      final rawGoal = profile?.fitnessGoal;
      _goalDirection =
          (rawGoal == 'lose' || rawGoal == 'build' || rawGoal == 'maintain')
              ? rawGoal!
              : 'maintain';
      _currentWeightKg = latest?.weightKg ?? profile?.weightKg ?? 70;
      _desiredWeightKg = profile?.targetWeightKg ?? _currentWeightKg;
    }
    _currentWeightCtrl.text = _currentWeightKg.toStringAsFixed(1);
    _desiredWeightCtrl.text = _desiredWeightKg.toStringAsFixed(1);
    _customCadenceCtrl.text = '$_cadenceDays';
    _initialized = true;
  }

  double get _durationWeeks {
    final days = _targetDate.difference(DateTime.now()).inHours / 24.0;
    return (days / 7.0).clamp(1 / 7, double.infinity);
  }

  bool get _isMaintenance =>
      _goalDirection == 'maintain' ||
      (_desiredWeightKg - _currentWeightKg).abs() < 0.05;

  double get _requiredWeeklyRateKg {
    if (_isMaintenance) return 0;
    return (_desiredWeightKg - _currentWeightKg).abs() / _durationWeeks;
  }

  String? get _paceWarning {
    if (_isMaintenance) return null;
    return WeightGoalCalculations.paceWarningFor(
        _goalDirection, _requiredWeeklyRateKg);
  }

  WeightGoalPlanPreview get _preview {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final plan = _buildPreviewPlan(profile);
    final macros = WeightGoalCalculations.macrosFor(
      plan,
      weightKgForCalc: _currentWeightKg,
    );
    return WeightGoalPlanPreview(plan: plan, macros: macros);
  }

  WeightGoalPlan _buildPreviewPlan(dynamic profile) {
    return WeightGoalPlan(
      goalDirection: _isMaintenance ? 'maintain' : _goalDirection,
      startDate: DateTime.now(),
      startWeightKg: _currentWeightKg,
      targetWeightKg: _desiredWeightKg,
      targetDate: _targetDate,
      weighInIntervalDays: _cadenceDays,
      remindersEnabled: _remindersEnabled,
      gender: profile?.gender ?? 'male',
      age: profile?.age ?? 30,
      heightCm: profile?.heightCm ?? 170,
      activityLevel: profile?.activityLevel ?? 'moderate',
    );
  }

  @override
  Widget build(BuildContext context) {
    _initFromProfile();
    final preview = _preview;
    final warning = _paceWarning;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Weight Goal')),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _sectionLabel('GOAL'),
              const SizedBox(height: 8),
              _goalChips(),
              const SizedBox(height: 20),
              _sectionLabel('WEIGHTS'),
              const SizedBox(height: 8),
              _weightFields(),
              const SizedBox(height: 20),
              _sectionLabel('TARGET DATE'),
              const SizedBox(height: 8),
              _targetDateSection(),
              const SizedBox(height: 20),
              _sectionLabel('WEIGH-IN CADENCE'),
              const SizedBox(height: 8),
              _cadenceSection(),
              const SizedBox(height: 20),
              _remindersSwitch(),
              const SizedBox(height: 20),
              _sectionLabel('LIVE READOUT'),
              const SizedBox(height: 8),
              _readoutCard(preview, warning),
              if (warning != null) ...[
                const SizedBox(height: 12),
                _warningCard(warning),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () => _onSavePressed(warning),
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save goal'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0x73FFFFFF))),
      );

  Widget _goalChips() {
    final options = const [
      ('lose', 'Lose weight'),
      ('build', 'Build muscle'),
      ('maintain', 'Maintain'),
    ];
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final selected = _goalDirection == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: selected,
          onSelected: (_) => setState(() => _goalDirection = o.$1),
        );
      }).toList(),
    );
  }

  Widget _weightFields() {
    return GlassCard(
      child: Column(
        children: [
          TextField(
            controller: _currentWeightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Current weight (kg)', suffixText: 'kg'),
            onChanged: (v) {
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed != null) setState(() => _currentWeightKg = parsed);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desiredWeightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Desired weight (kg)', suffixText: 'kg'),
            onChanged: (v) {
              final parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed != null) setState(() => _desiredWeightKg = parsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _targetDateSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [8, 12, 16, 24].map((weeks) {
              final candidate =
                  DateTime.now().add(Duration(days: weeks * 7));
              final selected = candidate.difference(_targetDate).inDays.abs() < 2;
              return ChoiceChip(
                label: Text('$weeks wks'),
                selected: selected,
                onSelected: (_) => setState(() => _targetDate = candidate),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('Target: ${DateFormat('d MMM y').format(_targetDate)}'),
          ),
        ],
      ),
    );
  }

  Widget _cadenceSection() {
    final options = const [
      (3, 'Every 3 days'),
      (7, 'Weekly'),
      (14, 'Every 2 weeks'),
    ];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...options.map((o) {
                final selected = _cadenceDays == o.$1;
                return ChoiceChip(
                  label: Text(o.$2),
                  selected: selected,
                  onSelected: (_) => setState(() => _cadenceDays = o.$1),
                );
              }),
              ChoiceChip(
                label: const Text('Custom'),
                selected: ![3, 7, 14].contains(_cadenceDays),
                onSelected: (_) => setState(() => _cadenceDays = 10),
              ),
            ],
          ),
          if (![3, 7, 14].contains(_cadenceDays)) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customCadenceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Days between weigh-ins'),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) {
                  setState(() => _cadenceDays = parsed);
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _remindersSwitch() {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined,
              color: Color(0xFF818CF8)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Weigh-in reminders')),
          Switch(
            value: _remindersEnabled,
            onChanged: (v) => setState(() => _remindersEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _readoutCard(WeightGoalPlanPreview preview, String? warning) {
    final color = warning == 'danger'
        ? const Color(0xFFFF453A)
        : warning == 'warn'
            ? const Color(0xFFFF9F0A)
            : const Color(0xFF38BDF8);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                preview.plan.goalDirection == 'maintain'
                    ? 'Maintenance'
                    : '${preview.plan.requiredWeeklyRateKg.toStringAsFixed(2)} kg/week required',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _readoutStat(
                      'Calories', '${preview.macros.dailyCalories.round()} kcal')),
              Expanded(
                  child: _readoutStat(
                      'Protein', '${preview.macros.proteinG.round()} g')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _readoutStat('Fat', '${preview.macros.fatG.round()} g')),
              Expanded(
                  child:
                      _readoutStat('Carbs', '${preview.macros.carbsG.round()} g')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readoutStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _warningCard(String level) {
    final isDanger = level == 'danger';
    final color = isDanger ? const Color(0xFFFF453A) : const Color(0xFFFF9F0A);
    final recommended = _recommendedRateFor(_goalDirection);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isDanger ? Icons.error_rounded : Icons.warning_amber_rounded,
                  color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDanger
                      ? 'This pace is not recommended for safe, sustainable progress.'
                      : 'This pace may be aggressive.',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _useRecommendedPace(recommended),
                child: const Text('Use recommended pace'),
              ),
              if (isDanger)
                TextButton(
                  onPressed: _confirmSaveAnyway,
                  child: Text('Save anyway', style: TextStyle(color: color)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _recommendedRateFor(String goal) {
    switch (goal) {
      case 'lose':
        return 0.5;
      case 'build':
        return 0.25;
      default:
        return 0;
    }
  }

  void _useRecommendedPace(double recommendedRate) {
    if (recommendedRate <= 0) return;
    final distance = (_desiredWeightKg - _currentWeightKg).abs();
    final weeks = (distance / recommendedRate).ceil();
    setState(() {
      _targetDate = DateTime.now().add(Duration(days: weeks * 7));
    });
  }

  Future<void> _onSavePressed(String? warning) async {
    if (!_targetDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target date must be in the future.')),
      );
      return;
    }
    if (warning == 'danger') {
      final confirmed = await _confirmSaveAnyway();
      if (confirmed != true) return;
    }
    await _save();
  }

  Future<bool?> _confirmSaveAnyway() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save this pace anyway?'),
        content: const Text(
            'This pace is faster than recommended. You can still save it, '
            'but consider extending your timeframe or using the recommended '
            'pace instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(weightGoalActionsProvider).savePlan(
          goalDirection: _isMaintenance ? 'maintain' : _goalDirection,
          startDate: DateTime.now(),
          startWeightKg: _currentWeightKg,
          targetWeightKg: _desiredWeightKg,
          targetDate: _targetDate,
          weighInIntervalDays: _cadenceDays,
          remindersEnabled: _remindersEnabled,
        );
    if (mounted) Navigator.of(context).pop();
  }
}

/// Live-readout bundle for the setup screen's preview card.
class WeightGoalPlanPreview {
  final WeightGoalPlan plan;
  final MacroTargets macros;
  const WeightGoalPlanPreview({required this.plan, required this.macros});
}
