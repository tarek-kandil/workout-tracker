import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/app_database.dart';
import '../../services/notification_service.dart';
import '../../models/next_wod_result.dart';
import '../../models/weight_suggestion.dart';
import '../../providers/database_provider.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/vibrant_text.dart';

// ─── Local data model ──────────────────────────────────────────────────────────

class _SetData {
  double weightKg;
  int reps;
  int durationSeconds; // only used for timed exercises
  _SetData({required this.weightKg, required this.reps, this.durationSeconds = 0});
}

// ─── WAV generators (top-level) ───────────────────────────────────────────────

Uint8List _makeBeepWav({required int hz, required int ms, int amplitude = 26000}) {
  const sampleRate = 44100;
  final numSamples = sampleRate * ms ~/ 1000;
  final totalSize = 44 + numSamples * 2;
  final buf = ByteData(totalSize);
  void setStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) { buf.setUint8(offset + i, s.codeUnitAt(i)); }
  }
  setStr(0, 'RIFF'); buf.setUint32(4, totalSize - 8, Endian.little);
  setStr(8, 'WAVE'); setStr(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little); buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little); setStr(36, 'data');
  buf.setUint32(40, numSamples * 2, Endian.little);
  final dur = ms / 1000.0;
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double env = 1.0;
    if (t < 0.015) { env = t / 0.015; }
    else if (t > dur - 0.060) { env = (dur - t) / 0.060; }
    final sample = (sin(2 * pi * hz * t) * env * amplitude).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, sample, Endian.little);
  }
  return buf.buffer.asUint8List();
}

// Rest-end beep (880 Hz, 350 ms)
Uint8List _generateBeepWav() => _makeBeepWav(hz: 880, ms: 350);

// Countdown tick (440 Hz, 120 ms — subtle)
Uint8List _generateTickBeepWav() => _makeBeepWav(hz: 440, ms: 120, amplitude: 20000);

// Two-tone exercise-done sound (660 Hz → 880 Hz)
Uint8List _generateDoneBeepWav() {
  const sampleRate = 44100;
  const durationMs = 600;
  final numSamples = sampleRate * durationMs ~/ 1000;
  final totalSize = 44 + numSamples * 2;
  final buf = ByteData(totalSize);
  void setStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) { buf.setUint8(offset + i, s.codeUnitAt(i)); }
  }
  setStr(0, 'RIFF'); buf.setUint32(4, totalSize - 8, Endian.little);
  setStr(8, 'WAVE'); setStr(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little); buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little); setStr(36, 'data');
  buf.setUint32(40, numSamples * 2, Endian.little);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final hz = t < 0.30 ? 660 : 880;
    double env = 1.0;
    if (t < 0.010) { env = t / 0.010; }
    else if (t > 0.540) { env = (0.600 - t) / 0.060; }
    final sample = (sin(2 * pi * hz * t) * env * 24000).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, sample, Endian.little);
  }
  return buf.buffer.asUint8List();
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final NextWodResult result;
  final bool autoResume;
  const ActiveSessionScreen({super.key, required this.result, this.autoResume = false});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  final Map<int, List<_SetData>> _setData = {};
  final Map<int, List<WorkoutSet>> _lastSets = {};
  final Map<int, double?> _prData = {};
  final Map<int, int?> _prDurationData = {};
  bool _loading = true;
  bool _saving = false;

  int _currentExerciseIdx = 0;
  int _currentSetIdx = 0;

  // Rest timer
  Timer? _restTimer;
  int _restSecondsLeft = 90;
  int _restTotalSeconds = 90;
  bool _resting = false;
  DateTime? _restEndsAt; // absolute end time — survives backgrounding

  // Timed exercise timer
  Timer? _exerciseTicker;
  int _timedElapsed = 0;
  bool _timedRunning = false;
  bool _timedStopped = false;

  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer(); // rest-end sounds
  final AudioPlayer _sfxPlayer = AudioPlayer();   // exercise sounds
  Uint8List? _beepBytes;
  Uint8List? _tickBytes;
  Uint8List? _doneBytes;

  // Autopilot
  bool _autopilot = false;
  bool _countingDown = false;
  int _countdownLeft = 3;
  Timer? _countdownTimer;
  DateTime? _exerciseStartTime;

  // Resume prompt state
  bool _showResumePrompt = false;
  int? _savedAtMs;
  String? _pendingResumeJson;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _beepBytes = _generateBeepWav();
    _tickBytes = _generateTickBeepWav();
    _doneBytes = _generateDoneBeepWav();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _exerciseTicker?.cancel();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    _sfxPlayer.dispose();
    NotificationService.cancelWorkoutStatus();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resting && _restEndsAt != null) {
      // Recalculate remaining time from the absolute end timestamp
      final remaining = _restEndsAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _restTimer?.cancel();
        setState(() { _resting = false; _restSecondsLeft = 0; });
        _playBeep();
      } else {
        setState(() => _restSecondsLeft = remaining);
      }
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final wodId = widget.result.wodTemplate.id;

    for (final entry in widget.result.exercises) {
      final te = entry.templateExercise;
      final exerciseId = te.exerciseId;
      final lastSets =
          await db.setsDao.getLastSetsForExerciseInWod(exerciseId, wodId);
      _lastSets[exerciseId] = lastSets;
      if (entry.exercise.isTimed) {
        _prDurationData[exerciseId] =
            await db.setsDao.getPersonalRecordDuration(exerciseId);
      } else {
        _prData[exerciseId] = await db.setsDao.getPersonalRecord(exerciseId);
      }

      // All sets start blank — values are filled in on first stepper press
      _setData[exerciseId] = List.generate(
        te.targetSets,
        (_) => _SetData(weightKg: 0, reps: 0),
      );
    }

    // Check for saved progress
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('workout_progress_${widget.result.wodTemplate.id}');
    if (savedJson != null) {
      final data = jsonDecode(savedJson) as Map<String, dynamic>;
      _savedAtMs = data['savedAt'] as int?;
      _pendingResumeJson = savedJson;
      if (widget.autoResume) {
        // Apply saved data directly without showing the prompt
        final savedSets = data['sets'] as Map<String, dynamic>;
        for (final entry in savedSets.entries) {
          final exerciseId = int.parse(entry.key);
          final list = (entry.value as List).map((s) {
            final m = s as Map<String, dynamic>;
            return _SetData(
              weightKg: (m['w'] as num).toDouble(),
              reps: m['r'] as int,
              durationSeconds: m['d'] as int,
            );
          }).toList();
          _setData[exerciseId] = list;
        }
        setState(() {
          _loading = false;
          _currentExerciseIdx = data['exerciseIdx'] as int;
          _currentSetIdx = data['setIdx'] as int;
          _pendingResumeJson = null;
        });
      } else {
        setState(() {
          _loading = false;
          _showResumePrompt = true;
        });
      }
    } else {
      setState(() => _loading = false);
      _updateNotification();
    }
  }

  void _onSetChanged(int exerciseId, int setIndex, _SetData data) {
    setState(() => _setData[exerciseId]![setIndex] = data);
  }

  void _onDoneSet() {
    final exercises = widget.result.exercises;
    final entry = exercises[_currentExerciseIdx];
    final targetSets = entry.templateExercise.targetSets;
    final restSeconds = widget.result.wodTemplate.restSeconds;

    final isLastSet = _currentSetIdx >= targetSets - 1;
    final isLastExercise = _currentExerciseIdx >= exercises.length - 1;

    setState(() {
      if (!isLastSet) {
        _currentSetIdx++;
      } else if (!isLastExercise) {
        _currentExerciseIdx++;
        _currentSetIdx = 0;
      }
      _timedRunning = false;
      _timedStopped = false;
      _timedElapsed = 0;
      _exerciseTicker?.cancel();
    });

    _saveProgress();
    _updateNotification();

    if (!(isLastSet && isLastExercise)) {
      _startRest(restSeconds);
    }
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    setState(() {
      _restTotalSeconds = seconds;
      _restSecondsLeft = seconds;
      _resting = true;
    });
    _updateNotification();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final remaining = _restEndsAt!.difference(DateTime.now()).inSeconds;
      setState(() {
        _restSecondsLeft = remaining.clamp(0, _restTotalSeconds);
        if (_restSecondsLeft <= 0) {
          t.cancel();
          _resting = false;
          _restEndsAt = null;
          _onRestComplete();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() { _resting = false; _restEndsAt = null; });
  }

  void _startExerciseTimer() {
    _exerciseTicker?.cancel();
    _exerciseStartTime = DateTime.now();
    setState(() { _timedElapsed = 0; _timedRunning = true; _timedStopped = false; });
    _updateNotification();
    _exerciseTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timedElapsed++);
      if (_autopilot) {
        final target = widget.result.exercises[_currentExerciseIdx]
            .templateExercise.repRangeMin;
        if (_timedElapsed >= target) _stopExerciseTimer();
      }
    });
  }

  void _stopExerciseTimer() {
    _exerciseTicker?.cancel();
    final exerciseId = widget.result.exercises[_currentExerciseIdx].templateExercise.exerciseId;
    setState(() {
      _timedRunning = false;
      _timedStopped = true;
      _setData[exerciseId]![_currentSetIdx] = _SetData(weightKg: 0, reps: 0, durationSeconds: _timedElapsed);
    });
    _playDoneSound();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _onDoneSet();
    });
  }

  Future<void> _playBeep() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    if (_beepBytes != null) {
      await _audioPlayer.play(BytesSource(_beepBytes!));
    }
  }

  Future<void> _playTick() async {
    HapticFeedback.lightImpact();
    if (_tickBytes != null) await _sfxPlayer.play(BytesSource(_tickBytes!));
  }

  Future<void> _playGoSound() async {
    HapticFeedback.mediumImpact();
    if (_beepBytes != null) await _sfxPlayer.play(BytesSource(_beepBytes!));
  }

  Future<void> _playDoneSound() async {
    HapticFeedback.heavyImpact();
    if (_doneBytes != null) await _sfxPlayer.play(BytesSource(_doneBytes!));
  }

  void _onRestComplete() {
    _playBeep();
    _updateNotification();
    if (_autopilot) {
      final current = widget.result.exercises[_currentExerciseIdx];
      if (current.exercise.isTimed) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _autopilot && !_resting) _startCountdown();
        });
      }
    }
  }

  void _toggleAutopilot() {
    final nowOn = !_autopilot;
    setState(() => _autopilot = nowOn);
    if (nowOn) {
      final exercise = widget.result.exercises[_currentExerciseIdx];
      if (exercise.exercise.isTimed &&
          !_timedRunning && !_timedStopped && !_resting && !_countingDown) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _autopilot) _startCountdown();
        });
      }
    } else {
      _countdownTimer?.cancel();
      if (_countingDown) setState(() => _countingDown = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() { _countingDown = true; _countdownLeft = 3; });
    _playTick();
    _updateNotification();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdownLeft--);
      if (_countdownLeft > 0) {
        _playTick();
      } else {
        t.cancel();
        setState(() => _countingDown = false);
        _playGoSound();
        _startExerciseTimer();
      }
    });
  }

  void _updateNotification() {
    if (_loading) return;
    final exercises = widget.result.exercises;
    if (exercises.isEmpty) return;
    final current = exercises[_currentExerciseIdx];
    final totalSets = current.templateExercise.targetSets;
    final setLabel = 'Set ${_currentSetIdx + 1}/$totalSets';
    final nextLabel = _getNextLabel();

    String title;
    String body;
    int? chronoMs;
    bool countDown = false;

    if (_countingDown) {
      title = '${current.exercise.name} — $setLabel';
      body = 'Get ready... $_countdownLeft • $nextLabel';
    } else if (_resting) {
      title = 'Rest';
      body = '${_fmtSec(_restTotalSeconds)} recovery • $nextLabel';
      chronoMs = _restEndsAt?.millisecondsSinceEpoch;
      countDown = true;
    } else if (_timedRunning) {
      final target = current.templateExercise.repRangeMin;
      title = '${current.exercise.name} — $setLabel';
      body = 'Target ${_fmtSec(target)} • $nextLabel';
      chronoMs = _exerciseStartTime?.millisecondsSinceEpoch;
    } else {
      title = '${current.exercise.name} — $setLabel';
      body = nextLabel;
    }

    NotificationService.showWorkoutStatus(
      title: title,
      body: body,
      chronoMs: chronoMs,
      chronoCountDown: countDown,
    );
  }

  String _getNextLabel() {
    final exercises = widget.result.exercises;
    final isLastSet = _currentSetIdx >=
        exercises[_currentExerciseIdx].templateExercise.targetSets - 1;
    final isLastExercise = _currentExerciseIdx >= exercises.length - 1;
    if (isLastSet && isLastExercise) return 'Last set!';
    if (!isLastSet) return 'Next: Set ${_currentSetIdx + 2}';
    return 'Next: ${exercises[_currentExerciseIdx + 1].exercise.name}';
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final setsJson = <String, dynamic>{};
    for (final e in _setData.entries) {
      setsJson[e.key.toString()] = e.value
          .map((s) => {'w': s.weightKg, 'r': s.reps, 'd': s.durationSeconds})
          .toList();
    }
    await prefs.setString(
      'workout_progress_${widget.result.wodTemplate.id}',
      jsonEncode({
        'exerciseIdx': _currentExerciseIdx,
        'setIdx': _currentSetIdx,
        'sets': setsJson,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('workout_progress_${widget.result.wodTemplate.id}');
  }

  void _resumeWorkout() {
    if (_pendingResumeJson == null) return;
    final data = jsonDecode(_pendingResumeJson!) as Map<String, dynamic>;
    final savedSets = data['sets'] as Map<String, dynamic>;
    for (final entry in savedSets.entries) {
      final exerciseId = int.parse(entry.key);
      final list = (entry.value as List).map((s) {
        final m = s as Map<String, dynamic>;
        return _SetData(
          weightKg: (m['w'] as num).toDouble(),
          reps: m['r'] as int,
          durationSeconds: m['d'] as int,
        );
      }).toList();
      _setData[exerciseId] = list;
    }
    setState(() {
      _showResumePrompt = false;
      _currentExerciseIdx = data['exerciseIdx'] as int;
      _currentSetIdx = data['setIdx'] as int;
      _pendingResumeJson = null;
    });
  }

  Future<void> _restartWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Workout?'),
        content: const Text('Your saved progress will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restart')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearProgress();
      setState(() {
        _showResumePrompt = false;
        _pendingResumeJson = null;
      });
    }
  }

  Future<void> _discardWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text('You will return to the home screen with no sets logged.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearProgress();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    _countdownTimer?.cancel();
    _exerciseTicker?.cancel();
    NotificationService.cancelWorkoutStatus();
    await _clearProgress();
    final db = ref.read(databaseProvider);
    final wod = widget.result.wodTemplate;

    final sessionId = await db.sessionsDao.insertSession(
      WorkoutSessionsCompanion.insert(
        date: DateTime.now(),
        workoutName: wod.name,
        wodTemplateId: Value(wod.id),
        weekNumber: Value(widget.result.weekNumberInProgram),
      ),
    );

    for (final entry in widget.result.exercises) {
      final exerciseId = entry.templateExercise.exerciseId;
      final isTimed = entry.exercise.isTimed;
      final sets = _setData[exerciseId] ?? [];
      // Skip sets the user never filled in
      final filledSets = isTimed
          ? sets.where((s) => s.durationSeconds > 0).toList()
          : sets.where((s) => s.reps > 0).toList();
      for (int i = 0; i < filledSets.length; i++) {
        await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: i + 1,
          reps: isTimed ? 0 : filledSets[i].reps,
          weightKg: filledSets[i].weightKg,
          durationSeconds: isTimed
              ? Value(filledSets[i].durationSeconds)
              : const Value.absent(),
        ));
      }
    }

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);
    ref.invalidate(currentProgramWeekProvider);
    if (mounted) {
      await showWorkoutCompleteOverlay(context, wod.name);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.result.exercises;
    final totalExercises = exercises.length;
    final progressValue = totalExercises == 0
        ? 0.0
        : _currentExerciseIdx / totalExercises;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.result.wodTemplate.name),
            Text(
              'Week ${widget.result.weekNumberInProgram} · Exercise ${_currentExerciseIdx + 1} of $totalExercises',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (!_loading && exercises[_currentExerciseIdx].exercise.isTimed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(
                  _autopilot ? Icons.smart_toy : Icons.smart_toy_outlined,
                ),
                color: _autopilot
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white54,
                tooltip: _autopilot ? 'Autopilot On' : 'Autopilot Off',
                onPressed: _toggleAutopilot,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 4,
            backgroundColor: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.12),
          ),
        ),
      ),
      bottomNavigationBar: _resting
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _saving || _loading ? null : _finish,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Finish Workout'),
                ),
              ),
            ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                // Current exercise card
                _CurrentExerciseCard(
                  entry: exercises[_currentExerciseIdx],
                  setData: _setData[exercises[_currentExerciseIdx].templateExercise.exerciseId] ?? [],
                  currentSetIdx: _currentSetIdx,
                  currentExerciseIdx: _currentExerciseIdx,
                  totalExercises: totalExercises,
                  lastSets: _lastSets[exercises[_currentExerciseIdx].templateExercise.exerciseId] ?? [],
                  prKg: _prData[exercises[_currentExerciseIdx].templateExercise.exerciseId],
                  prDurationSeconds: _prDurationData[exercises[_currentExerciseIdx].templateExercise.exerciseId],
                  timedRunning: _timedRunning,
                  timedElapsed: _timedElapsed,
                  timedStopped: _timedStopped,
                  onSetDataChanged: (setIndex, data) => _onSetChanged(
                    exercises[_currentExerciseIdx].templateExercise.exerciseId,
                    setIndex,
                    data,
                  ),
                  onDoneSet: _onDoneSet,
                  onStartTimer: _startExerciseTimer,
                  onStopTimer: _stopExerciseTimer,
                ),
                // Completed exercises section
                if (_currentExerciseIdx > 0) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'COMPLETED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.38),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (int i = 0; i < _currentExerciseIdx; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _CompletedExerciseTile(
                        entry: exercises[i],
                        sets: _setData[exercises[i].templateExercise.exerciseId] ?? [],
                      ),
                    ),
                ],
                // Upcoming exercises section
                if (_currentExerciseIdx < totalExercises - 1) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'UP NEXT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.38),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (int i = _currentExerciseIdx + 1; i < totalExercises; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _UpcomingExerciseTile(entry: exercises[i]),
                    ),
                ],
              ],
            ),
          // Rest timer overlay
          if (_resting && !_loading)
            _RestTimerOverlay(
              secondsLeft: _restSecondsLeft,
              totalSeconds: _restTotalSeconds,
              onSkip: _skipRest,
            ),
          if (_showResumePrompt && !_loading)
            _ResumePromptOverlay(
              savedAtMs: _savedAtMs,
              onResume: _resumeWorkout,
              onRestart: _restartWorkout,
              onDiscard: _discardWorkout,
            ),
          if (_countingDown && !_loading)
            _CountdownOverlay(
              secondsLeft: _countdownLeft,
              exerciseName: exercises[_currentExerciseIdx].exercise.name,
              setLabel:
                  'Set ${_currentSetIdx + 1} / ${exercises[_currentExerciseIdx].templateExercise.targetSets}',
            ),
        ],
      ),
    );
  }
}

// ─── Current Exercise Card ─────────────────────────────────────────────────────

class _CurrentExerciseCard extends StatelessWidget {
  final WodExerciseEntry entry;
  final List<_SetData> setData;
  final int currentSetIdx;
  final int currentExerciseIdx;
  final int totalExercises;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final void Function(int setIndex, _SetData data) onSetDataChanged;
  final VoidCallback onDoneSet;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;

  const _CurrentExerciseCard({
    required this.entry,
    required this.setData,
    required this.currentSetIdx,
    required this.currentExerciseIdx,
    required this.totalExercises,
    required this.lastSets,
    required this.prKg,
    required this.prDurationSeconds,
    required this.timedRunning,
    required this.timedElapsed,
    required this.timedStopped,
    required this.onSetDataChanged,
    required this.onDoneSet,
    required this.onStartTimer,
    required this.onStopTimer,
  });

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    final isTimed = entry.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;
    final totalSets = te.targetSets;

    // Compute referenceData for the current set input
    final _SetData refData;
    if (currentSetIdx == 0) {
      if (isTimed) {
        final lastDur = lastSets.isNotEmpty
            ? (lastSets[0].durationSeconds ?? te.repRangeMin)
            : te.repRangeMin;
        refData = _SetData(weightKg: 0, reps: 0, durationSeconds: lastDur);
      } else {
        refData = _SetData(
          weightKg: entry.suggestion.suggestedKg ?? 0.0,
          reps: lastSets.isNotEmpty ? lastSets[0].reps : te.repRangeMax,
        );
      }
    } else {
      refData = setData.isNotEmpty && currentSetIdx - 1 < setData.length
          ? setData[currentSetIdx - 1]
          : _SetData(weightKg: 0, reps: 0);
    }

    return LiquidGlassContainer(
      borderRadius: 20,
      blurSigma: 12,
      tintColor: accent.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VibrantText(
                        entry.exercise.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isTimed
                            ? '$totalSets sets · ${_fmtSec(te.repRangeMin)}'
                            : '$totalSets sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _SuggestionBadge(suggestion: entry.suggestion),
              ],
            ),

            const SizedBox(height: 14),

            // Completed sets log
            if (currentSetIdx > 0) ...[
              for (int i = 0; i < currentSetIdx; i++) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Set ${i + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        i < setData.length
                            ? (isTimed
                                ? _fmtSec(setData[i].durationSeconds)
                                : '${_fmtW(setData[i].weightKg)} kg × ${setData[i].reps}')
                            : '—',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 16),
            ],

            // Current set label
            Text(
              'SET ${currentSetIdx + 1} / $totalSets',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 8),

            // Input area
            if (isTimed)
              _TimedSetInput(
                running: timedRunning,
                elapsed: timedElapsed,
                stopped: timedStopped,
                target: te.repRangeMin,
                onStart: onStartTimer,
                onStop: onStopTimer,
              )
            else
              _SetRow(
                key: ValueKey('set-${te.exerciseId}-$currentSetIdx'),
                setNumber: currentSetIdx + 1,
                isTimed: false,
                data: currentSetIdx < setData.length
                    ? setData[currentSetIdx]
                    : _SetData(weightKg: 0, reps: 0),
                referenceData: refData,
                onChanged: (data) => onSetDataChanged(currentSetIdx, data),
              ),

            const SizedBox(height: 14),

            // Done Set button (circle for weighted, nothing for timed — timed auto-advances)
            if (!isTimed)
              Center(
                child: _CheckCircleButton(
                  key: ValueKey('check-${entry.exercise.id}-$currentSetIdx'),
                  onDone: onDoneSet,
                ),
              ),

            const Divider(height: 24),

            // Stats row
            _ExerciseStats(
              lastSets: lastSets,
              isTimed: isTimed,
              prKg: prKg,
              prDurationSeconds: prDurationSeconds,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timed Set Input ──────────────────────────────────────────────────────────

class _TimedSetInput extends StatelessWidget {
  final bool running;
  final int elapsed;
  final bool stopped;
  final int target;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _TimedSetInput({
    required this.running,
    required this.elapsed,
    required this.stopped,
    required this.target,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (stopped)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                _fmtSec(elapsed),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                'logged',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
              ),
            ],
          )
        else if (running)
          Column(
            children: [
              Text(
                _fmtSec(elapsed),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Text(
                'Target: ${_fmtSec(target)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_circle_outlined),
                  label: const Text('Start Timer'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Rest Timer Overlay ───────────────────────────────────────────────────────

class _RestTimerOverlay extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final VoidCallback onSkip;

  const _RestTimerOverlay({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'REST',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: totalSeconds > 0 ? secondsLeft / totalSeconds : 0,
                    strokeWidth: 6,
                    backgroundColor: Colors.white12,
                    color: Colors.indigoAccent,
                  ),
                ),
                Text(
                  _fmtSec(secondsLeft),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onSkip,
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip Rest'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Completed Exercise Tile ──────────────────────────────────────────────────

class _CompletedExerciseTile extends StatelessWidget {
  final WodExerciseEntry entry;
  final List<_SetData> sets;

  const _CompletedExerciseTile({
    required this.entry,
    required this.sets,
  });

  @override
  Widget build(BuildContext context) {
    final isTimed = entry.exercise.isTimed;
    final filledSets = isTimed
        ? sets.where((s) => s.durationSeconds > 0).toList()
        : sets.where((s) => s.reps > 0).toList();

    final String summary;
    if (filledSets.isEmpty) {
      summary = '—';
    } else if (isTimed) {
      summary = filledSets.map((s) => _fmtSec(s.durationSeconds)).join(' · ');
    } else {
      summary = filledSets.map((s) => '${_fmtW(s.weightKg)}×${s.reps}').join(' · ');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.exercise.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming Exercise Tile ───────────────────────────────────────────────────

class _UpcomingExerciseTile extends StatelessWidget {
  final WodExerciseEntry entry;

  const _UpcomingExerciseTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    return Opacity(
      opacity: 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.radio_button_unchecked, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(entry.exercise.name),
            ),
            Text(
              '${te.targetSets} sets',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exercise stats (last best + PR) ─────────────────────────────────────────

class _ExerciseStats extends StatelessWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final double? prKg;
  final int? prDurationSeconds;

  const _ExerciseStats({
    required this.lastSets,
    required this.isTimed,
    required this.prKg,
    required this.prDurationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final String lastStr;
    final String prStr;

    if (isTimed) {
      WorkoutSet? bestLast;
      for (final s in lastSets) {
        final dur = s.durationSeconds ?? 0;
        if (bestLast == null || dur > (bestLast.durationSeconds ?? 0)) {
          bestLast = s;
        }
      }
      lastStr = bestLast != null && (bestLast.durationSeconds ?? 0) > 0
          ? _fmtSec(bestLast.durationSeconds!)
          : '--';
      prStr = prDurationSeconds != null && prDurationSeconds! > 0
          ? _fmtSec(prDurationSeconds!)
          : '--';
    } else {
      WorkoutSet? bestLast;
      for (final s in lastSets) {
        if (bestLast == null ||
            s.weightKg > bestLast.weightKg ||
            (s.weightKg == bestLast.weightKg && s.reps > bestLast.reps)) {
          bestLast = s;
        }
      }
      lastStr = bestLast != null && bestLast.weightKg > 0
          ? '${_fmtW(bestLast.weightKg)}×${bestLast.reps}'
          : '--';
      prStr = prKg != null && prKg! > 0 ? '${_fmtW(prKg!)} kg' : '--';
    }

    final dim = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45));

    return Row(
      children: [
        _StatChip(label: 'Last', value: lastStr, style: dim),
        const SizedBox(width: 12),
        _StatChip(label: 'PR', value: prStr, style: dim),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? style;
  const _StatChip({required this.label, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$label  ',
            style: style?.copyWith(
              color: style?.color?.withValues(alpha: 0.6),
            ),
          ),
          TextSpan(
            text: value,
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Set input row ────────────────────────────────────────────────────────────

class _SetRow extends StatefulWidget {
  final int setNumber;
  final bool isTimed;
  final _SetData data;
  // On the very first stepper press, snap to this value instead of incrementing
  final _SetData referenceData;
  final void Function(_SetData) onChanged;

  const _SetRow({
    super.key,
    required this.setNumber,
    required this.isTimed,
    required this.data,
    required this.referenceData,
    required this.onChanged,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  // True once the user has interacted with any stepper on this set
  bool _initialized = false;
  bool _editingWeight = false;
  bool _editingSecondary = false; // reps or duration
  late final TextEditingController _weightCtrl;
  late final TextEditingController _secondaryCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController();
    _secondaryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _secondaryCtrl.dispose();
    super.dispose();
  }

  // On first press: snap to reference. On subsequent presses: normal delta.
  void _handleWeight(double delta) {
    if (!_initialized) {
      _initialized = true;
      widget.onChanged(widget.referenceData);
    } else {
      widget.onChanged(_SetData(
        weightKg: (widget.data.weightKg + delta).clamp(0.0, double.infinity),
        reps: widget.data.reps,
        durationSeconds: widget.data.durationSeconds,
      ));
    }
  }

  void _handleReps(int delta) {
    if (!_initialized) {
      _initialized = true;
      widget.onChanged(widget.referenceData);
    } else {
      widget.onChanged(_SetData(
        weightKg: widget.data.weightKg,
        reps: (widget.data.reps + delta).clamp(1, 999),
      ));
    }
  }

  void _handleDuration(int delta) {
    if (!_initialized) {
      _initialized = true;
      widget.onChanged(widget.referenceData);
    } else {
      widget.onChanged(_SetData(
        weightKg: widget.data.weightKg,
        reps: 0,
        durationSeconds: (widget.data.durationSeconds + delta).clamp(5, 3600),
      ));
    }
  }

  void _commitWeight() {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (v != null && v >= 0) {
      _initialized = true;
      widget.onChanged(_SetData(
        weightKg: v,
        reps: widget.data.reps,
        durationSeconds: widget.data.durationSeconds,
      ));
    }
    if (mounted) setState(() => _editingWeight = false);
  }

  void _commitReps() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      _initialized = true;
      widget.onChanged(_SetData(weightKg: widget.data.weightKg, reps: v));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  void _commitDuration() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      _initialized = true;
      widget.onChanged(_SetData(
        weightKg: widget.data.weightKg,
        reps: 0,
        durationSeconds: v.clamp(5, 3600),
      ));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTimed = widget.isTimed;
    final dur = widget.data.durationSeconds;
    final durationLabel = _editingSecondary ? null : _fmtSec(dur);
    final repsLabel = _editingSecondary ? null : '${widget.data.reps} reps';

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            'Set ${widget.setNumber}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
          ),
        ),
        if (!isTimed) ...[
          Expanded(
            child: _StepperField(
              label: _editingWeight ? null : '${_fmtW(widget.data.weightKg)} kg',
              editingController: _editingWeight ? _weightCtrl : null,
              onDecrement: () => _handleWeight(-2.5),
              onIncrement: () => _handleWeight(2.5),
              onTapValue: () => setState(() {
                _weightCtrl.text = _fmtW(widget.data.weightKg);
                _weightCtrl.selection = TextSelection(
                    baseOffset: 0, extentOffset: _weightCtrl.text.length);
                _editingWeight = true;
                _editingSecondary = false;
              }),
              onCommit: _commitWeight,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: isTimed
              ? _StepperField(
                  label: durationLabel,
                  editingController: _editingSecondary ? _secondaryCtrl : null,
                  isInteger: true,
                  onDecrement: () => _handleDuration(-5),
                  onIncrement: () => _handleDuration(5),
                  onTapValue: () => setState(() {
                    _secondaryCtrl.text = dur.toString();
                    _secondaryCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                    _editingSecondary = true;
                    _editingWeight = false;
                  }),
                  onCommit: _commitDuration,
                )
              : _StepperField(
                  label: repsLabel,
                  editingController: _editingSecondary ? _secondaryCtrl : null,
                  isInteger: true,
                  onDecrement: () => _handleReps(-1),
                  onIncrement: () => _handleReps(1),
                  onTapValue: () => setState(() {
                    _secondaryCtrl.text = widget.data.reps.toString();
                    _secondaryCtrl.selection = TextSelection(
                        baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                    _editingSecondary = true;
                    _editingWeight = false;
                  }),
                  onCommit: _commitReps,
                ),
        ),
      ],
    );
  }
}

// ─── Stepper field ────────────────────────────────────────────────────────────

class _StepperField extends StatelessWidget {
  final String? label;
  final TextEditingController? editingController;
  final bool isInteger;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapValue;
  final VoidCallback onCommit;

  const _StepperField({
    this.label,
    this.editingController,
    this.isInteger = false,
    required this.onDecrement,
    required this.onIncrement,
    required this.onTapValue,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBtn(icon: Icons.remove, onTap: onDecrement),
        Expanded(
          child: editingController != null
              ? TextField(
                  controller: editingController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: !isInteger,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  ),
                  onSubmitted: (_) => onCommit(),
                  onTapOutside: (_) => onCommit(),
                )
              : GestureDetector(
                  onTap: onTapValue,
                  child: Text(
                    label ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
        ),
        _StepBtn(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 16),
      onPressed: onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─── Suggestion badge ─────────────────────────────────────────────────────────

class _SuggestionBadge extends StatelessWidget {
  final WeightSuggestion suggestion;
  const _SuggestionBadge({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    if (suggestion.type == SuggestionType.noHistory) {
      return const SizedBox.shrink();
    }
    Color color;
    IconData icon;
    switch (suggestion.type) {
      case SuggestionType.increase:
        color = Colors.green;
        icon = Icons.trending_up;
      case SuggestionType.decrease:
        color = Colors.orange;
        icon = Icons.trending_down;
      case SuggestionType.maintain:
      case SuggestionType.noHistory:
        color = Theme.of(context).colorScheme.secondary;
        icon = Icons.trending_flat;
    }
    final kg = suggestion.suggestedKg != null
        ? '${_fmtW(suggestion.suggestedKg!)} kg'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (kg.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(kg,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

// ─── Animated check-circle Done button ────────────────────────────────────────

class _CheckCircleButton extends StatefulWidget {
  final VoidCallback onDone;
  const _CheckCircleButton({super.key, required this.onDone});

  @override
  State<_CheckCircleButton> createState() => _CheckCircleButtonState();
}

class _CheckCircleButtonState extends State<_CheckCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() {
    if (_triggered) return;
    _triggered = true;
    HapticFeedback.mediumImpact();
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _tap,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final v = _ctrl.value;
              final fill = Curves.easeOutCubic.transform(v);
              final scale = 1.0 + 0.12 * sin(v * pi);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(Colors.transparent, Colors.green, fill),
                    border: Border.all(
                      color: Color.lerp(Colors.white30, Colors.green, fill)!,
                      width: 2.5,
                    ),
                    boxShadow: v > 0.05
                        ? [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: fill * 0.4),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Color.lerp(Colors.white30, Colors.white, fill),
                    size: 28,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Opacity(
            opacity: (1.0 - _ctrl.value).clamp(0.0, 1.0),
            child: Text(
              'Done Set',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Resume Prompt Overlay ─────────────────────────────────────────────────────

class _ResumePromptOverlay extends StatelessWidget {
  final int? savedAtMs;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onDiscard;

  const _ResumePromptOverlay({
    required this.savedAtMs,
    required this.onResume,
    required this.onRestart,
    required this.onDiscard,
  });

  String get _timeAgo {
    if (savedAtMs == null) return '';
    final diffMs = DateTime.now().millisecondsSinceEpoch - savedAtMs!;
    final minutes = diffMs ~/ 60000;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m ago';
    return '${minutes ~/ 60}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fitness_center, size: 52, color: accent),
                const SizedBox(height: 20),
                const Text(
                  'Resume Workout?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Last saved $_timeAgo',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 36),
                // Resume — primary CTA
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onResume,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Resume',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Restart / Discard secondary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PromptAction(
                      icon: Icons.restart_alt,
                      label: 'Restart',
                      color: Colors.white70,
                      onTap: onRestart,
                    ),
                    const SizedBox(width: 40),
                    _PromptAction(
                      icon: Icons.close,
                      label: 'Discard',
                      color: Colors.red.shade300,
                      onTap: onDiscard,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PromptAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PromptAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          onPressed: onTap,
          icon: Icon(icon, color: color),
          style: IconButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ─── Countdown Overlay ────────────────────────────────────────────────────────

class _CountdownOverlay extends StatelessWidget {
  final int secondsLeft;
  final String exerciseName;
  final String setLabel;

  const _CountdownOverlay({
    required this.secondsLeft,
    required this.exerciseName,
    required this.setLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isGo = secondsLeft <= 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AUTOPILOT',
              style: TextStyle(
                color: accent.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              exerciseName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              setLabel,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 48),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                isGo ? 'GO!' : '$secondsLeft',
                key: ValueKey(secondsLeft),
                style: TextStyle(
                  color: isGo ? Colors.greenAccent : Colors.white,
                  fontSize: 100,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isGo ? 'Starting...' : 'Get ready',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtW(double w) =>
    w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

String _fmtSec(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
