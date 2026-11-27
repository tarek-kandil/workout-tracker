import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/app_database.dart';
import '../../models/exercise_tracking_mode.dart';
import '../../providers/challenges_providers.dart';
import '../../providers/database_provider.dart';
import '../../widgets/celebration_overlay.dart';
import '../log/audio/session_sound_player.dart';

Future<void> showChallengeAttemptSheet(
  BuildContext context,
  WidgetRef ref,
  ChallengeViewData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF131827),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _ChallengeAttemptSheet(data: data),
  );
}

class _ChallengeAttemptSheet extends ConsumerStatefulWidget {
  final ChallengeViewData data;
  const _ChallengeAttemptSheet({required this.data});

  @override
  ConsumerState<_ChallengeAttemptSheet> createState() =>
      _ChallengeAttemptSheetState();
}

enum _TimerPhase { ready, countdown, running, review }

class _ChallengeAttemptSheetState
    extends ConsumerState<_ChallengeAttemptSheet> {
  // Timed stopwatch state
  _TimerPhase _phase = _TimerPhase.ready;
  int _prepSecondsLeft = 5;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _crossedBest = false;
  bool _crossedGoal = false;
  final SessionSoundPlayer _sound = SessionSoundPlayer();

  // Bodyweight / Weighted inputs
  late int _repsInput;
  late double _weightInput;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sound.load();
    final prev = widget.data.previousAttempt;
    final best = widget.data.bestAttempt;
    _repsInput = (best?.reps ?? prev?.reps ?? 1).clamp(1, 500);
    _weightInput = best?.weightKg ?? prev?.weightKg ?? 20.0;
    _weightCtrl = TextEditingController(
      text: _weightInput > 0 ? fmtChallengeKg(_weightInput) : '',
    );
    _repsCtrl = TextEditingController(text: '$_repsInput');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sound.dispose();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  int get _bestSec => widget.data.bestAttempt?.durationSeconds ?? 0;
  int get _goalSec => widget.data.challenge.targetDurationSeconds ?? 60;

  void _startPrepCountdown() {
    _timer?.cancel();
    setState(() {
      _phase = _TimerPhase.countdown;
      _prepSecondsLeft = 5;
      _elapsedSeconds = 0;
      _crossedBest = false;
      _crossedGoal = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_prepSecondsLeft > 1) {
        setState(() => _prepSecondsLeft--);
        if (_prepSecondsLeft <= 3) {
          _sound.playTick();
        }
      } else {
        t.cancel();
        _sound.playGoSound();
        _startStopwatch();
      }
    });
  }

  void _startStopwatch() {
    _timer?.cancel();
    setState(() => _phase = _TimerPhase.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final next = _elapsedSeconds + 1;
      setState(() => _elapsedSeconds = next);

      if (_bestSec > 0 && !_crossedBest && next >= _bestSec) {
        _crossedBest = true;
        _sound.playMilestoneChime();
      }
      if (_goalSec > 0 && !_crossedGoal && next >= _goalSec) {
        _crossedGoal = true;
        _sound.playMilestoneChime();
      }
    });
  }

  void _stopForReview() {
    _timer?.cancel();
    setState(() => _phase = _TimerPhase.review);
  }

  Future<void> _editManualSeconds() async {
    final ctrl = TextEditingController(
      text: _elapsedSeconds > 0 ? '$_elapsedSeconds' : '',
    );
    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Time (seconds)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration in seconds',
            hintText: 'e.g. 90 for 1:30',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (res != null && res > 0 && mounted) {
      setState(() {
        _elapsedSeconds = res.clamp(1, 7200);
        _phase = _TimerPhase.review;
      });
    }
  }

  Future<void> _saveAttempt() async {
    if (_saving) return;
    final data = widget.data;
    final mode = data.mode;

    double w = 0.0;
    int r = 0;
    int? dur;

    switch (mode) {
      case ExerciseTrackingMode.timed:
        if (_elapsedSeconds <= 0) return;
        dur = _elapsedSeconds;
      case ExerciseTrackingMode.bodyweightReps:
        r = int.tryParse(_repsCtrl.text.trim()) ?? _repsInput;
        if (r <= 0) return;
      case ExerciseTrackingMode.weightedReps:
        w = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ??
            _weightInput;
        r = int.tryParse(_repsCtrl.text.trim()) ?? _repsInput;
        if (w <= 0 || r <= 0) return;
    }

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    final now = DateTime.now();
    final newAttempt = ChallengeAttempt(
      id: -1,
      challengeId: data.challenge.id,
      weightKg: w,
      reps: r,
      durationSeconds: dur,
      date: now,
      syncId: '',
      updatedAt: now.toUtc(),
    );

    final wasNewBest = data.isNewBest(newAttempt);
    final hitTarget = data.isTargetMetBy(newAttempt);

    await db.challengesDao.insertAttempt(ChallengeAttemptsCompanion.insert(
      challengeId: data.challenge.id,
      weightKg: Value(w),
      reps: Value(r),
      durationSeconds: Value(dur),
    ));

    if (hitTarget) {
      await db.challengesDao.insertMilestone(ChallengeMilestonesCompanion.insert(
        challengeId: data.challenge.id,
        targetWeightKg: Value(data.challenge.targetWeightKg),
        targetReps: Value(data.challenge.targetReps),
        targetDurationSeconds: Value(data.challenge.targetDurationSeconds),
      ));
    }

    ref.invalidate(activeChallengesProvider);
    ref.invalidate(completedChallengesProvider);

    if (!mounted) return;
    final nav = Navigator.of(context);
    final rootContext = nav.context;
    nav.pop();
    if (!rootContext.mounted) return;

    if (hitTarget) {
      HapticFeedback.heavyImpact();
      await _showTargetConqueredDialog(rootContext, ref, data);
    } else if (wasNewBest) {
      HapticFeedback.heavyImpact();
      await showPrOverlay(
        rootContext,
        exerciseName: '${data.exercise.name} Challenge',
        newWeightKg: w,
        reps: r,
        oldWeightKg: data.bestAttempt?.weightKg,
        isBodyweight: mode == ExerciseTrackingMode.bodyweightReps,
        oldReps: data.bestAttempt?.reps,
        newDurationSeconds: dur,
        oldDurationSeconds: data.bestAttempt?.durationSeconds,
      );
    }
  }

  Future<void> _showTargetConqueredDialog(
    BuildContext context,
    WidgetRef ref,
    ChallengeViewData data,
  ) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🏁 Target Conquered!'),
        content: Text(
          'You hit your ${data.targetLabel} goal on ${data.exercise.name}!\n\n'
          'Would you like to mark this challenge complete or extend it to a higher target?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'complete'),
            child: const Text('Complete Challenge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'extend'),
            child: const Text('Extend Target'),
          ),
        ],
      ),
    );

    final db = container.read(databaseProvider);
    if (choice == 'complete') {
      await db.challengesDao.completeChallenge(data.challenge.id);
      container.invalidate(activeChallengesProvider);
      container.invalidate(completedChallengesProvider);
    } else if (choice == 'extend' && context.mounted) {
      await showExtendChallengeDialog(context, ref, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final mode = data.mode;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '🏁 ${data.exercise.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // ── Previous / Current Best / Goal Strip ─────────────────────────
          Row(
            children: [
              _MetricBox(
                label: 'PREVIOUS',
                value: data.previousAttempt != null
                    ? data.formatAttempt(data.previousAttempt!)
                    : '—',
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              _MetricBox(
                label: 'CURRENT BEST',
                value: data.bestLabel,
                color: const Color(0xFFFBBF24),
                highlighted: _crossedBest,
              ),
              const SizedBox(width: 8),
              _MetricBox(
                label: 'GOAL',
                value: data.targetLabel,
                color: const Color(0xFF34D399),
                highlighted: _crossedGoal,
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (mode == ExerciseTrackingMode.timed)
            _buildTimedBody()
          else if (mode == ExerciseTrackingMode.bodyweightReps)
            _buildBodyweightBody()
          else
            _buildWeightedBody(),
        ],
      ),
    );
  }

  Widget _buildTimedBody() {
    final goal = _goalSec > 0 ? _goalSec : 60;
    final progress = switch (_phase) {
      _TimerPhase.ready => 0.0,
      _TimerPhase.countdown => (5 - _prepSecondsLeft) / 5.0,
      _TimerPhase.running || _TimerPhase.review =>
        (_elapsedSeconds / goal).clamp(0.0, 1.0),
    };
    final ringColor = switch (_phase) {
      _TimerPhase.countdown => const Color(0xFFFBBF24),
      _TimerPhase.running =>
        _crossedGoal ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
      _TimerPhase.review => const Color(0xFF34D399),
      _TimerPhase.ready => const Color(0xFF38BDF8),
    };

    return Column(
      children: [
        SizedBox(
          width: 164,
          height: 164,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 156,
                height: 156,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              GestureDetector(
                onTap: _phase == _TimerPhase.review || _phase == _TimerPhase.ready
                    ? _editManualSeconds
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _phase == _TimerPhase.countdown
                          ? '$_prepSecondsLeft'
                          : fmtChallengeSec(_elapsedSeconds),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      switch (_phase) {
                        _TimerPhase.ready => '5s prep on Start',
                        _TimerPhase.countdown => 'Get in position...',
                        _TimerPhase.running => _crossedGoal
                            ? 'Goal Reached!'
                            : '${(goal - _elapsedSeconds).clamp(0, 9999)}s to Goal',
                        _TimerPhase.review => 'Tap to edit or trim below',
                      },
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_phase == _TimerPhase.ready) ...[
          FilledButton.icon(
            onPressed: _startPrepCountdown,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF082F49),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Start Stopwatch (5s Prep)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _editManualSeconds,
            child: const Text('Or enter time manually'),
          ),
        ] else if (_phase == _TimerPhase.countdown) ...[
          OutlinedButton(
            onPressed: () {
              _timer?.cancel();
              setState(() => _phase = _TimerPhase.ready);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cancel'),
          ),
        ] else if (_phase == _TimerPhase.running) ...[
          FilledButton.icon(
            onPressed: _stopForReview,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.stop_rounded),
            label: const Text(
              'Stop Timer',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ] else ...[
          // Review & trim seconds before saving
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final delta in const [-5, -1, 1, 5])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _elapsedSeconds =
                          (_elapsedSeconds + delta).clamp(1, 7200);
                    }),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      delta > 0 ? '+${delta}s' : '${delta}s',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAttempt,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF34D399),
              foregroundColor: const Color(0xFF052E16),
            ),
            icon: const Icon(Icons.check_rounded),
            label: Text(
              'Save Attempt (${fmtChallengeSec(_elapsedSeconds)})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBodyweightBody() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: _repsInput > 1
                  ? () => setState(() {
                        _repsInput--;
                        _repsCtrl.text = '$_repsInput';
                      })
                  : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 144,
              child: TextField(
                controller: _repsCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed > 0) _repsInput = parsed;
                },
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              onPressed: () => setState(() {
                _repsInput++;
                _repsCtrl.text = '$_repsInput';
              }),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _saveAttempt,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF34D399),
            foregroundColor: const Color(0xFF052E16),
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text(
            'Save Attempt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightedBody() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _saveAttempt,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: const Color(0xFF082F49),
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text(
            'Save Attempt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlighted;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.09),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: color.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showExtendChallengeDialog(
  BuildContext context,
  WidgetRef ref,
  ChallengeViewData data,
) async {
  final mode = data.mode;
  final durCtrl = TextEditingController(
    text: '${(data.challenge.targetDurationSeconds ?? 60) + 15}',
  );
  final repsCtrl = TextEditingController(
    text: '${(data.challenge.targetReps ?? 10) + 5}',
  );
  final weightCtrl = TextEditingController(
    text: fmtChallengeKg((data.challenge.targetWeightKg ?? 60) + 5),
  );

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Extend ${data.exercise.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mode == ExerciseTrackingMode.timed)
            TextField(
              controller: durCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Target Duration (seconds)',
                suffixText: 's',
                border: OutlineInputBorder(),
              ),
            )
          else if (mode == ExerciseTrackingMode.bodyweightReps)
            TextField(
              controller: repsCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Target Reps',
                suffixText: 'reps',
                border: OutlineInputBorder(),
              ),
            )
          else ...[
            TextField(
              controller: weightCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'New Target Weight',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Reps',
                suffixText: 'reps',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save New Target')),
      ],
    ),
  );

  if (ok != true || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final db = container.read(databaseProvider);
  await db.challengesDao.extendChallengeTarget(
    challengeId: data.challenge.id,
    newTargetDurationSeconds: mode == ExerciseTrackingMode.timed
        ? int.tryParse(durCtrl.text.trim())
        : null,
    newTargetReps: mode != ExerciseTrackingMode.timed
        ? int.tryParse(repsCtrl.text.trim())
        : null,
    newTargetWeightKg: mode == ExerciseTrackingMode.weightedReps
        ? double.tryParse(weightCtrl.text.replaceAll(',', '.'))
        : null,
  );
  container.invalidate(activeChallengesProvider);
  container.invalidate(completedChallengesProvider);
}
