import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/home_providers.dart';
import '../../../providers/weight_goal_providers.dart';
import '../../../utils/weight_goal_calculations.dart';
import '../../../utils/weight_goal_ui.dart';

/// Opens the "Log weigh-in" glass bottom sheet. After saving, the same
/// sheet switches to a coaching STATUS card (icon + color + plain sentence
/// + suggested kcal-delta pill + actual-vs-expected mini summary) per
/// User Story 2.
Future<void> showWeighInSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _WeighInSheet(),
  );
}

class _WeighInSheet extends ConsumerStatefulWidget {
  const _WeighInSheet();

  @override
  ConsumerState<_WeighInSheet> createState() => _WeighInSheetState();
}

class _WeighInSheetState extends ConsumerState<_WeighInSheet> {
  final _weightCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  WeightGoalProgress? _result;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e2030),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (_result == null) _buildForm(context) else _buildResult(context, _result!),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final plan = ref.watch(weightGoalPlanProvider);
    final progress = ref.watch(weightGoalProgressProvider);
    final expected = progress.expectedWeightTodayKg;
    final latest = ref.watch(latestBodyweightProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Log weigh-in',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          controller: _weightCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Weight (kg)',
            border: OutlineInputBorder(),
            suffixText: 'kg',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _date = picked);
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(DateFormat('EEE, d MMM y').format(_date)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (plan != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expected != null
                        ? 'Expected today: ${expected.toStringAsFixed(1)} kg'
                            '${latest != null ? ' · Last: ${latest.weightKg.toStringAsFixed(1)} kg' : ''}'
                        : latest != null
                            ? 'Last: ${latest.weightKg.toStringAsFixed(1)} kg'
                            : 'No previous readings yet',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final kg = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (kg == null || kg <= 0) return;

    setState(() => _saving = true);
    final notes = _noteCtrl.text.trim();
    await ref.read(weightGoalActionsProvider).logWeighIn(
          weightKg: kg,
          date: _date,
          notes: notes.isEmpty ? null : notes,
        );

    if (!mounted) return;
    // Re-evaluate coaching status with the freshly logged entry included.
    final plan = ref.read(weightGoalPlanProvider);
    final weighIns = ref.read(allBodyweightsProvider).valueOrNull ?? const [];
    final result = WeightGoalCalculations.evaluate(plan: plan, weighIns: weighIns);
    setState(() {
      _saving = false;
      _result = result;
    });
  }

  Widget _buildResult(BuildContext context, WeightGoalProgress result) {
    final style = WeightGoalStatusStyle.of(result.verdict);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(style.icon, color: style.color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(style.label,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: style.color)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(result.message, style: const TextStyle(fontSize: 14, height: 1.4)),
        if (result.suggestedKcalDelta != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: style.color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    result.suggestedKcalDelta! >= 0
                        ? Icons.add_rounded
                        : Icons.remove_rounded,
                    size: 16,
                    color: style.color),
                const SizedBox(width: 4),
                Text(
                  '${result.suggestedKcalDelta!.abs()} kcal/day '
                  '${result.suggestedKcalDelta! >= 0 ? 'more' : 'less'}'
                  '${result.isConfirmed ? '' : ' (if it continues)'}',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: style.color),
                ),
              ],
            ),
          ),
        ],
        if (result.trendWeightKg != null && result.expectedWeightTodayKg != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Actual (trend)',
                  value: '${result.trendWeightKg!.toStringAsFixed(1)} kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Expected',
                  value: '${result.expectedWeightTodayKg!.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}
