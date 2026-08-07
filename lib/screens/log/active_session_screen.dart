import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
import '../../models/wod_item.dart';
import '../../providers/database_provider.dart';
import '../../providers/home_providers.dart';
import '../../providers/next_workout_provider.dart';
import '../../providers/program_providers.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/glass_background.dart';
import 'models/session_models.dart';
import 'audio/session_sounds.dart';
import 'session_formatters.dart';
import 'widgets/session_common.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final NextWodResult result;
  final bool autoResume;
  const ActiveSessionScreen({super.key, required this.result, this.autoResume = false});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  // ── Data maps ─────────────────────────────────────────────────────────────────
  final Map<int, List<SetData>> _setData = {};
  final Map<int, List<WorkoutSet>> _lastSets = {};
  final Map<int, double?> _prData = {};
  final Map<int, int> _prBestReps = {};
  final Map<int, int?> _prDurationData = {};
  final Map<int, bool> _historyExpanded = {};

  // ── Mutable session items ──────────────────────────────────────────────────────
  final List<SessionItem> _sessionItems = [];
  int _nextItemId = 0;

  bool _loading = true;
  bool _saving = false;

  // ── Progress cursors ───────────────────────────────────────────────────────────
  int _currentItemIdx = 0;
  int _currentSetIdx = 0;
  int _circuitExerciseIdx = 0;
  /// True once the last set of the last planned exercise has been marked done.
  /// Used so that ad-hoc exercises added afterwards become immediately active.
  bool _allExercisesDone = false;

  // ── Rest timer ─────────────────────────────────────────────────────────────────
  Timer? _restTimer;
  int _restSecondsLeft = 90;
  int _restTotalSeconds = 90;
  bool _resting = false;
  DateTime? _restEndsAt;

  // ── Exercise timer ─────────────────────────────────────────────────────────────
  Timer? _exerciseTicker;
  int _timedElapsed = 0;
  bool _timedRunning = false;
  bool _timedStopped = false;

  // ── Audio ──────────────────────────────────────────────────────────────────────
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  Uint8List? _beepBytes;
  Uint8List? _tickBytes;
  Uint8List? _doneBytes;

  // ── Circuit autopilot ──────────────────────────────────────────────────────────
  bool _countingDown = false;
  int _countdownLeft = 3;
  Timer? _countdownTimer;
  DateTime? _exerciseStartTime;

  // ── Resume prompt ──────────────────────────────────────────────────────────────
  bool _showResumePrompt = false;
  int? _savedAtMs;
  String? _pendingResumeJson;

  // ── Helpers ───────────────────────────────────────────────────────────────────

  CardState _cardStateFor(int i) {
    if (_sessionItems[i].skipped) return CardState.completed;
    if (i < _currentItemIdx) return CardState.completed;
    if (i == _currentItemIdx) return CardState.active;
    return CardState.upcoming;
  }

  int _nextNonSkippedSet(int itemIdx, int fromSet, int totalSets) {
    int next = fromSet;
    while (next < totalSets && _sessionItems[itemIdx].skippedSets.contains(next)) {
      next++;
    }
    return next;
  }

  WodExerciseEntry get _currentEntry {
    final item = _sessionItems[_currentItemIdx].wodItem;
    return switch (item) {
      StandaloneWodExercise(:final entry) => entry,
      WodCircuit(:final exercises) => exercises[_circuitExerciseIdx],
    };
  }

  WodCircuit? get _currentCircuit {
    final item = _sessionItems[_currentItemIdx].wodItem;
    return item is WodCircuit ? item : null;
  }

  bool get _isCircuit => _currentCircuit != null;

  String? get _circuitName {
    final c = _currentCircuit;
    if (c == null) return null;
    return (c.name != null && c.name!.isNotEmpty) ? c.name! : 'Circuit';
  }

  String? get _circuitRoundLabel {
    final c = _currentCircuit;
    if (c == null) return null;
    return 'Round ${_currentSetIdx + 1} / ${c.rounds}';
  }

  String? get _circuitContext {
    final name = _circuitName;
    final round = _circuitRoundLabel;
    if (name == null) return null;
    return '$name · $round';
  }

  String? get _circuitNextLabel {
    final c = _currentCircuit;
    if (c == null) return null;
    final isLastInRound = _circuitExerciseIdx >= c.exercises.length - 1;
    final isLastRound = _currentSetIdx >= c.rounds - 1;
    if (!isLastInRound) return 'Next: ${c.exercises[_circuitExerciseIdx + 1].exercise.name}';
    if (!isLastRound) return 'Next round → ${c.exercises[0].exercise.name}';
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _beepBytes = generateBeepWav();
    _tickBytes = generateTickBeepWav();
    _doneBytes = generateDoneBeepWav();
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

  // ── Load ──────────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final wodId = widget.result.wodTemplate.id;

    final slotsNeeded = <int, int>{};
    for (final item in widget.result.items) {
      switch (item) {
        case StandaloneWodExercise(:final entry):
          slotsNeeded[entry.templateExercise.exerciseId] = entry.templateExercise.targetSets;
        case WodCircuit(:final rounds, :final exercises):
          for (final e in exercises) {
            slotsNeeded[e.templateExercise.exerciseId] = rounds;
          }
      }
    }

    for (final entry in widget.result.allExercises) {
      final te = entry.templateExercise;
      final exerciseId = te.exerciseId;
      final lastSets = await db.setsDao.getLastSetsForExerciseInWod(exerciseId, wodId);
      _lastSets[exerciseId] = lastSets;
      if (entry.exercise.isTimed) {
        _prDurationData[exerciseId] = await db.setsDao.getPersonalRecordDuration(exerciseId);
      } else {
        _prData[exerciseId] = await db.setsDao.getPersonalRecord(exerciseId);
      }
      final numSets = slotsNeeded[exerciseId] ?? te.targetSets;
      final isTimed = entry.exercise.isTimed;
      _setData[exerciseId] = List.generate(numSets, (idx) {
        if (idx < lastSets.length) {
          final ls = lastSets[idx];
          return SetData(
            weightKg: ls.weightKg,
            reps: isTimed ? 0 : ls.reps,
            durationSeconds: isTimed ? (ls.durationSeconds ?? te.repRangeMin) : 0,
          );
        }
        if (idx == 0 && !isTimed) {
          return SetData(weightKg: entry.suggestion.suggestedKg ?? 0.0, reps: (te.repRangeMax * 0.8).round());
        }
        return SetData(weightKg: 0, reps: 0);
      });
    }

    // Build mutable session items from the original result
    _sessionItems.addAll(widget.result.items.map((i) => SessionItem(id: _nextItemId++, wodItem: i)));

    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('workout_progress_${widget.result.wodTemplate.id}');
    if (savedJson != null) {
      final data = jsonDecode(savedJson) as Map<String, dynamic>;
      _savedAtMs = data['savedAt'] as int?;
      _pendingResumeJson = savedJson;
      if (widget.autoResume) {
        _applyResumeData(data);
        setState(() { _loading = false; _pendingResumeJson = null; });
      } else {
        setState(() { _loading = false; _showResumePrompt = true; });
      }
    } else {
      setState(() => _loading = false);
      _updateNotification();
    }
  }

  void _applyResumeData(Map<String, dynamic> data) {
    final savedSets = data['sets'] as Map<String, dynamic>;
    for (final entry in savedSets.entries) {
      final exerciseId = int.parse(entry.key);
      final list = (entry.value as List).map((s) {
        final m = s as Map<String, dynamic>;
        return SetData(weightKg: (m['w'] as num).toDouble(), reps: m['r'] as int, durationSeconds: m['d'] as int);
      }).toList();
      _setData[exerciseId] = list;
    }
    _currentItemIdx = data['itemIdx'] as int? ?? 0;
    _currentSetIdx = data['setIdx'] as int;
    _circuitExerciseIdx = data['circuitExIdx'] as int? ?? 0;

    // Restore skip state
    final savedItems = data['items'] as List<dynamic>?;
    if (savedItems != null && savedItems.length == _sessionItems.length) {
      for (int i = 0; i < savedItems.length; i++) {
        final m = savedItems[i] as Map<String, dynamic>;
        _sessionItems[i].skipped = m['skipped'] as bool? ?? false;
        final skippedSets = ((m['skippedSets'] as List<dynamic>?) ?? []).cast<int>();
        _sessionItems[i].skippedSets.addAll(skippedSets);
      }
    }
  }

  // ── Set change ────────────────────────────────────────────────────────────────

  void _onSetChanged(int exerciseId, int setIndex, SetData data) {
    setState(() => _setData[exerciseId]![setIndex] = data);
  }

  // ── Done set ──────────────────────────────────────────────────────────────────

  // ── PR helpers ────────────────────────────────────────────────────────────────

  int _bestRepsAtPrWeight(int exerciseId) {
    final pr = _prData[exerciseId];
    if (pr == null || pr == 0) return 0;
    int best = _prBestReps[exerciseId] ?? 0;
    for (final s in (_lastSets[exerciseId] ?? [])) {
      if (s.weightKg == pr && s.reps > best) best = s.reps;
    }
    for (final s in (_setData[exerciseId] ?? [])) {
      if (s.weightKg == pr && s.reps > best) best = s.reps;
    }
    return best;
  }

  /// Returns true if this set is a new PR; updates _prData / _prBestReps when it is.
  bool _checkPrAndUpdate(int exerciseId, double weightKg, int reps) {
    final currentPr = _prData[exerciseId] ?? 0.0;
    final isNewWeight = weightKg > currentPr;
    final isMoreReps = weightKg == currentPr && reps > _bestRepsAtPrWeight(exerciseId);
    if (isNewWeight) {
      _prData[exerciseId] = weightKg;
      _prBestReps.remove(exerciseId);
    } else if (isMoreReps) {
      _prBestReps[exerciseId] = reps;
    }
    return isNewWeight || isMoreReps;
  }

  Future<double?> _showRpeSheet(String exerciseName, int setNumber) {
    return showModalBottomSheet<double>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RpeSheet(exerciseName: exerciseName, setNumber: setNumber),
    );
  }

  Future<void> _onDoneSet() async {
    // ── Capture BEFORE state mutation ────────────────────────────────────────
    final entry = _currentEntry;
    final exerciseId = entry.templateExercise.exerciseId;
    final capturedSetIdx = _currentSetIdx;
    final capturedSetNumber = capturedSetIdx + 1;
    final capturedName = entry.exercise.name;
    final isTimed = entry.exercise.isTimed;
    final loggedData = _setData[exerciseId]?[capturedSetIdx];

    // ── Existing advance logic ────────────────────────────────────────────────
    final item = _sessionItems[_currentItemIdx].wodItem;
    final isLastItem = _currentItemIdx >= _sessionItems.length - 1;
    bool startRestAfter = true;
    int restDuration = widget.result.wodTemplate.restSeconds;
    bool needAutoStart = false;

    switch (item) {
      case StandaloneWodExercise(:final entry, :final restSeconds):
        final targetSets = entry.templateExercise.targetSets;
        final isLastSet = _currentSetIdx >= targetSets - 1;
        setState(() {
          if (!isLastSet) {
            final next = _nextNonSkippedSet(_currentItemIdx, _currentSetIdx + 1, targetSets);
            if (next < targetSets) {
              _currentSetIdx = next;
            } else if (!isLastItem) {
              _currentItemIdx++;
              _currentSetIdx = 0;
              _circuitExerciseIdx = 0;
            }
          } else if (!isLastItem) {
            _currentItemIdx++;
            _currentSetIdx = 0;
            _circuitExerciseIdx = 0;
          }
          _timedRunning = false;
          _timedStopped = false;
          _timedElapsed = 0;
          _exerciseTicker?.cancel();
        });
        if (isLastSet && isLastItem) {
          startRestAfter = false;
          _allExercisesDone = true;
        }
        restDuration = restSeconds ?? widget.result.wodTemplate.restSeconds;

      case WodCircuit():
        final circuit = item;
        final isLastInRound = _circuitExerciseIdx >= circuit.exercises.length - 1;
        final isLastRound = _currentSetIdx >= circuit.rounds - 1;
        setState(() {
          _timedRunning = false;
          _timedStopped = false;
          _timedElapsed = 0;
          _exerciseTicker?.cancel();
          if (!isLastInRound) {
            _circuitExerciseIdx++;
          } else if (!isLastRound) {
            _circuitExerciseIdx = 0;
            _currentSetIdx++;
          } else {
            _circuitExerciseIdx = 0;
            _currentSetIdx = 0;
            if (!isLastItem) _currentItemIdx++;
          }
        });
        final circuitDone = isLastInRound && isLastRound;
        if (circuitDone && isLastItem) {
          startRestAfter = false;
        } else if (!isLastInRound) {
          restDuration = circuit.restBetweenExercisesSeconds;
          if (restDuration == 0) startRestAfter = false;
        } else if (!isLastRound) {
          restDuration = circuit.restBetweenRoundsSeconds;
        }
        if (!startRestAfter && (!circuitDone || !isLastItem)) needAutoStart = true;
    }

    // ── PR overlay (non-timed only) ──────────────────────────────────────────
    if (!isTimed && loggedData != null && loggedData.reps > 0 && mounted) {
      final oldPrKg = _prData[exerciseId];
      if (_checkPrAndUpdate(exerciseId, loggedData.weightKg, loggedData.reps)) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          await showPrOverlay(
            context,
            exerciseName: capturedName,
            newWeightKg: loggedData.weightKg,
            reps: loggedData.reps,
            oldWeightKg: oldPrKg,
          );
        }
      }
    }

    // ── RPE sheet (non-timed only) ───────────────────────────────────────────
    if (!isTimed && loggedData != null && loggedData.reps > 0 && mounted) {
      final rpe = await _showRpeSheet(capturedName, capturedSetNumber);
      if (rpe != null && mounted) {
        setState(() {
          _setData[exerciseId]![capturedSetIdx] = SetData(
            weightKg: loggedData.weightKg,
            reps: loggedData.reps,
            rpe: rpe,
          );
        });
      }
    }

    // ── Persist + rest ───────────────────────────────────────────────────────
    if (!mounted) return;
    _saveProgress();
    _updateNotification();
    if (startRestAfter) {
      _startRest(restDuration);
    } else if (needAutoStart) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _maybeAutoStartCountdown();
      });
    }
  }

  // ── Rest timer ────────────────────────────────────────────────────────────────

  void _startRest(int seconds) {
    _restTimer?.cancel();
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    setState(() { _restTotalSeconds = seconds; _restSecondsLeft = seconds; _resting = true; });
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

  // ── Exercise timer ────────────────────────────────────────────────────────────

  void _startExerciseTimer() {
    _exerciseTicker?.cancel();
    _exerciseStartTime = DateTime.now();
    setState(() { _timedElapsed = 0; _timedRunning = true; _timedStopped = false; });
    _updateNotification();
    _exerciseTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timedElapsed++);
      if (_isCircuit) {
        final target = _currentEntry.templateExercise.repRangeMin;
        if (_timedElapsed >= target) _stopExerciseTimer();
      }
    });
  }

  void _stopExerciseTimer() {
    _exerciseTicker?.cancel();
    final exerciseId = _currentEntry.templateExercise.exerciseId;
    setState(() {
      _timedRunning = false;
      _timedStopped = true;
      _setData[exerciseId]![_currentSetIdx] = SetData(weightKg: 0, reps: 0, durationSeconds: _timedElapsed);
    });
    _playDoneSound();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _onDoneSet();
    });
  }

  // ── Audio ─────────────────────────────────────────────────────────────────────

  Future<void> _playBeep() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    if (_beepBytes != null) await _audioPlayer.play(BytesSource(_beepBytes!));
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
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_resting) _maybeAutoStartCountdown();
    });
  }

  void _maybeAutoStartCountdown() {
    if (!_isCircuit) return;
    if (_resting || _countingDown || _timedRunning || _timedStopped) return;
    if (!_currentEntry.exercise.isTimed) return;
    _startCountdown();
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

  // ── Notification ──────────────────────────────────────────────────────────────

  void _updateNotification() {
    if (_loading || _sessionItems.isEmpty) return;
    final current = _currentEntry;
    final circuit = _currentCircuit;
    final contextLabel = circuit != null
        ? 'Round ${_currentSetIdx + 1}/${circuit.rounds}'
        : 'Set ${_currentSetIdx + 1}/${current.templateExercise.targetSets}';
    String title;
    String body;
    int? chronoMs;
    bool countDown = false;

    if (_countingDown) {
      title = current.exercise.name;
      body = '$contextLabel · Get ready...';
    } else if (_resting) {
      title = 'Rest';
      body = _getCurrentRestLabel();
      chronoMs = _restEndsAt?.millisecondsSinceEpoch;
      countDown = true;
    } else if (_timedRunning) {
      title = current.exercise.name;
      body = contextLabel;
      chronoMs = _exerciseStartTime?.millisecondsSinceEpoch;
    } else {
      title = current.exercise.name;
      body = contextLabel;
    }

    NotificationService.showWorkoutStatus(
      title: title, body: body, chronoMs: chronoMs, chronoCountDown: countDown,
    );
  }

  /// What the user is about to do after the current rest (shown as primary in the pill).
  String _getCurrentRestLabel() {
    if (_sessionItems.isEmpty || _currentItemIdx >= _sessionItems.length) return '';
    final circuit = _currentCircuit;
    if (circuit != null) {
      return _circuitContext ?? 'Round ${_currentSetIdx + 1}/${circuit.rounds}';
    }
    final entry = _currentEntry;
    return '${entry.exercise.name}  ·  Set ${_currentSetIdx + 1}/${entry.templateExercise.targetSets}';
  }

  /// What comes AFTER the upcoming set — shown as secondary hint in the pill.
  String _getNextLabel() {
    final circuit = _currentCircuit;
    final isLastItem = _currentItemIdx >= _sessionItems.length - 1;

    if (circuit != null) {
      final isLastInRound = _circuitExerciseIdx >= circuit.exercises.length - 1;
      final isLastRound = _currentSetIdx >= circuit.rounds - 1;
      if (isLastInRound && isLastRound && isLastItem) return '';
      if (!isLastInRound) return 'Then: ${circuit.exercises[_circuitExerciseIdx + 1].exercise.name}';
      if (!isLastRound) return 'Then: Round ${_currentSetIdx + 2}';
    } else {
      final targetSets = _currentEntry.templateExercise.targetSets;
      final isLastSet = _currentSetIdx >= targetSets - 1;
      if (isLastSet && isLastItem) return '';
      if (!isLastSet) return 'Then: Set ${_currentSetIdx + 2}/$targetSets';
    }

    if (!isLastItem) {
      final nextItem = _sessionItems[_currentItemIdx + 1].wodItem;
      final name = switch (nextItem) {
        StandaloneWodExercise(:final entry) => entry.exercise.name,
        WodCircuit(:final exercises) => 'Circuit (${exercises.length} exercises)',
      };
      return 'Then: $name';
    }
    return '';
  }

  // ── Save / restore ────────────────────────────────────────────────────────────

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final setsJson = <String, dynamic>{};
    for (final e in _setData.entries) {
      setsJson[e.key.toString()] = e.value
          .map((s) => {'w': s.weightKg, 'r': s.reps, 'd': s.durationSeconds})
          .toList();
    }
    final itemsJson = _sessionItems.map((si) => switch (si.wodItem) {
      StandaloneWodExercise(:final entry) => {
        'type': 'standalone',
        'exerciseId': entry.templateExercise.exerciseId,
        'isAdHoc': si.isAdHoc,
        'skipped': si.skipped,
        'skippedSets': si.skippedSets.toList(),
      },
      WodCircuit(:final groupId) => {
        'type': 'circuit',
        'groupId': groupId,
        'skipped': si.skipped,
      },
    }).toList();

    await prefs.setString(
      'workout_progress_${widget.result.wodTemplate.id}',
      jsonEncode({
        'itemIdx': _currentItemIdx,
        'setIdx': _currentSetIdx,
        'circuitExIdx': _circuitExerciseIdx,
        'sets': setsJson,
        'items': itemsJson,
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
    _applyResumeData(data);
    setState(() { _showResumePrompt = false; _pendingResumeJson = null; });
  }

  Future<void> _restartWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Workout?'),
        content: const Text('Your saved progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restart')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _clearProgress();
      setState(() { _showResumePrompt = false; _pendingResumeJson = null; });
    }
  }

  Future<void> _discardWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Workout?'),
        content: const Text('You will return to the home screen with no sets logged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
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

  // ── Finish ────────────────────────────────────────────────────────────────────

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

    for (final si in _sessionItems) {
      if (si.skipped) continue;
      final entries = switch (si.wodItem) {
        StandaloneWodExercise(:final entry) => [(entry, si.skippedSets)],
        WodCircuit(:final exercises) => exercises.map((e) => (e, <int>{})).toList(),
      };
      for (final (entry, skippedSets) in entries) {
        final exerciseId = entry.templateExercise.exerciseId;
        final isTimed = entry.exercise.isTimed;
        final sets = _setData[exerciseId] ?? [];
        for (int i = 0; i < sets.length; i++) {
          if (skippedSets.contains(i)) continue;
          final s = sets[i];
          if (isTimed ? s.durationSeconds == 0 : s.reps == 0) continue;
          await db.setsDao.insertSet(WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            setNumber: i + 1,
            reps: isTimed ? 0 : s.reps,
            weightKg: s.weightKg,
            rpe: Value(s.rpe),
            durationSeconds: isTimed ? Value(s.durationSeconds) : const Value.absent(),
          ));
        }
      }
    }

    ref.invalidate(nextWodProvider);
    ref.invalidate(activeProgramProvider);
    ref.invalidate(currentProgramWeekProvider);
    ref.invalidate(pointsScoreProvider);
    if (mounted) {
      await showWorkoutCompleteOverlay(context, wod.name);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  void _skipExercise(int itemIdx) {
    setState(() {
      _sessionItems[itemIdx].skipped = true;
      if (itemIdx == _currentItemIdx) {
        int next = _currentItemIdx + 1;
        while (next < _sessionItems.length && _sessionItems[next].skipped) next++;
        if (next < _sessionItems.length) {
          _currentItemIdx = next;
          _currentSetIdx = 0;
          _circuitExerciseIdx = 0;
        }
      }
    });
    _restTimer?.cancel();
    setState(() { _resting = false; _restEndsAt = null; });
    _saveProgress();
    _updateNotification();
  }

  void _skipSet(int itemIdx, int setIdx) {
    setState(() {
      _sessionItems[itemIdx].skippedSets.add(setIdx);
      if (itemIdx == _currentItemIdx && setIdx == _currentSetIdx) {
        final totalSets = switch (_sessionItems[itemIdx].wodItem) {
          StandaloneWodExercise(:final entry) => entry.templateExercise.targetSets,
          WodCircuit(:final rounds) => rounds,
        };
        final next = _nextNonSkippedSet(itemIdx, _currentSetIdx + 1, totalSets);
        if (next >= totalSets) {
          final nextItem = _currentItemIdx + 1;
          if (nextItem < _sessionItems.length) {
            _currentItemIdx = nextItem;
            _currentSetIdx = 0;
            _circuitExerciseIdx = 0;
          }
        } else {
          _currentSetIdx = next;
        }
      }
    });
    _saveProgress();
  }

  Future<void> _editSet(BuildContext context, int itemIdx, int setIdx) async {
    final si = _sessionItems[itemIdx];
    if (si.wodItem is! StandaloneWodExercise) return;
    final entry = (si.wodItem as StandaloneWodExercise).entry;
    final exerciseId = entry.templateExercise.exerciseId;
    final isTimed = entry.exercise.isTimed;
    final sets = _setData[exerciseId] ?? [];
    final current = setIdx < sets.length ? sets[setIdx] : SetData(weightKg: 0, reps: 0);

    final weightCtrl = TextEditingController(text: current.weightKg > 0 ? fmtW(current.weightKg) : '');
    final secondaryCtrl = TextEditingController(
        text: isTimed
            ? (current.durationSeconds > 0 ? '${current.durationSeconds}' : '')
            : (current.reps > 0 ? '${current.reps}' : ''));

    final saved = await showModalBottomSheet<SetData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1e2030),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Edit Set ${setIdx + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(entry.exercise.name, style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 20),
            if (!isTimed) ...[
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Weight (kg)', labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: secondaryCtrl,
              keyboardType: TextInputType.number,
              autofocus: isTimed,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: isTimed ? 'Duration (seconds)' : 'Reps',
                labelStyle: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: () {
                  final w = double.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? current.weightKg;
                  final s = int.tryParse(secondaryCtrl.text);
                  Navigator.pop(ctx, SetData(
                    weightKg: isTimed ? 0 : w,
                    reps: isTimed ? 0 : (s ?? current.reps),
                    durationSeconds: isTimed ? (s ?? current.durationSeconds) : 0,
                    rpe: current.rpe,
                  ));
                },
                child: const Text('Save'),
              )),
            ]),
          ]),
        ),
      ),
    );

    weightCtrl.dispose();
    secondaryCtrl.dispose();

    if (saved != null && mounted) {
      _onSetChanged(entry.templateExercise.exerciseId, setIdx, saved);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    // Completed/skipped exercises have no drag handle, so oldIndex should always
    // be the active exercise or an upcoming one. Guard defensively, and never let
    // an item land in the completed region (before the active exercise): that
    // would falsely mark an exercise as done. Keeping _currentItemIdx fixed means
    // the set of completed exercises (indices < _currentItemIdx) never changes —
    // whichever exercise ends up in the active slot simply becomes current.
    if (oldIndex < _currentItemIdx) return;
    if (newIndex < _currentItemIdx) newIndex = _currentItemIdx;
    if (newIndex == oldIndex) return;
    setState(() {
      final item = _sessionItems.removeAt(oldIndex);
      _sessionItems.insert(newIndex, item);
    });
    _saveProgress();
  }

  void _removeAdHocItem(int i) {
    if (!_sessionItems[i].isAdHoc) return;
    setState(() {
      _sessionItems.removeAt(i);
      if (_currentItemIdx > i) _currentItemIdx--;
      _currentItemIdx = _currentItemIdx.clamp(0, (_sessionItems.length - 1).clamp(0, 999));
    });
    _saveProgress();
  }

  // ── Action sheets ─────────────────────────────────────────────────────────────

  void _showExerciseActions(BuildContext context, int itemIdx) {
    final si = _sessionItems[itemIdx];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
                onTap: () { Navigator.pop(ctx); _showSwapExerciseSheet(itemIdx); }),
            ActionTile(icon: Icons.add, label: 'Add Exercise',
                onTap: () { Navigator.pop(ctx); _showAddExerciseSheet(itemIdx + 1); }),
            ActionTile(icon: Icons.skip_next, label: 'Skip Exercise',
                onTap: () { Navigator.pop(ctx); _skipExercise(itemIdx); }),
            if (si.isAdHoc)
              ActionTile(icon: Icons.delete_outline, label: 'Remove', color: Colors.red.shade300,
                  onTap: () { Navigator.pop(ctx); _removeAdHocItem(itemIdx); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  void _showCircuitExerciseActions(BuildContext context, int itemIdx, int exIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
                onTap: () { Navigator.pop(ctx); _showSwapCircuitExerciseSheet(itemIdx, exIdx); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  // ── Swap exercise ─────────────────────────────────────────────────────────────

  void _showSwapExerciseSheet(int itemIdx) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ExerciseLibrarySheet(
        title: 'Swap Exercise',
        onSelected: (exercise) { Navigator.pop(context); _swapExercise(itemIdx, exercise); },
      ),
    );
  }

  void _swapExercise(int itemIdx, Exercise exercise) {
    final original = _sessionItems[itemIdx].wodItem;
    if (original is! StandaloneWodExercise) return;
    final origEntry = original.entry;
    final fakeTe = WodTemplateExercise(
      id: -(DateTime.now().millisecondsSinceEpoch),
      wodTemplateId: widget.result.wodTemplate.id,
      exerciseId: exercise.id,
      sortOrder: itemIdx,
      targetSets: origEntry.templateExercise.targetSets,
      repRangeMin: origEntry.templateExercise.repRangeMin,
      repRangeMax: origEntry.templateExercise.repRangeMax,
      restSeconds: original.restSeconds,
    );
    final newEntry = WodExerciseEntry(
      templateExercise: fakeTe, exercise: exercise, suggestion: WeightSuggestion.noHistory,
    );
    setState(() {
      _sessionItems[itemIdx] = SessionItem(
        id: _sessionItems[itemIdx].id,
        wodItem: StandaloneWodExercise(entry: newEntry, restSeconds: original.restSeconds),
        isAdHoc: true,
      );
      _setData[exercise.id] = List.generate(origEntry.templateExercise.targetSets, (_) => SetData(weightKg: 0, reps: 0));
      _lastSets[exercise.id] = [];
      _prData[exercise.id] = null;
      if (itemIdx == _currentItemIdx) { _currentSetIdx = 0; _circuitExerciseIdx = 0; }
    });
    _loadExerciseHistory(exercise.id);
    _saveProgress();
  }

  void _showSwapCircuitExerciseSheet(int itemIdx, int exIdx) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ExerciseLibrarySheet(
        title: 'Swap Exercise',
        onSelected: (exercise) { Navigator.pop(context); _swapCircuitExercise(itemIdx, exIdx, exercise); },
      ),
    );
  }

  void _swapCircuitExercise(int itemIdx, int exIdx, Exercise newExercise) {
    final circuit = _sessionItems[itemIdx].wodItem as WodCircuit;
    final original = circuit.exercises[exIdx];
    final fakeTe = WodTemplateExercise(
      id: -(DateTime.now().millisecondsSinceEpoch),
      wodTemplateId: widget.result.wodTemplate.id,
      exerciseId: newExercise.id,
      sortOrder: exIdx,
      groupId: circuit.groupId,
      targetSets: circuit.rounds,
      repRangeMin: original.templateExercise.repRangeMin,
      repRangeMax: original.templateExercise.repRangeMax,
    );
    final newEntry = WodExerciseEntry(
      templateExercise: fakeTe, exercise: newExercise, suggestion: WeightSuggestion.noHistory,
    );
    final newExercises = List<WodExerciseEntry>.from(circuit.exercises);
    newExercises[exIdx] = newEntry;
    final newCircuit = WodCircuit(
      groupId: circuit.groupId, name: circuit.name, rounds: circuit.rounds,
      restBetweenExercisesSeconds: circuit.restBetweenExercisesSeconds,
      restBetweenRoundsSeconds: circuit.restBetweenRoundsSeconds,
      exercises: newExercises,
    );
    setState(() {
      _sessionItems[itemIdx] = SessionItem(id: _sessionItems[itemIdx].id, wodItem: newCircuit, isAdHoc: _sessionItems[itemIdx].isAdHoc);
      _setData[newExercise.id] = List.generate(circuit.rounds, (_) => SetData(weightKg: 0, reps: 0));
      _lastSets[newExercise.id] = [];
      _prData[newExercise.id] = null;
      if (itemIdx == _currentItemIdx && exIdx == _circuitExerciseIdx) _currentSetIdx = 0;
    });
    _loadExerciseHistory(newExercise.id);
    _saveProgress();
  }

  Future<void> _loadExerciseHistory(int exerciseId) async {
    final db = ref.read(databaseProvider);
    final lastSets = await db.setsDao.getLastSetsForExerciseInWod(exerciseId, widget.result.wodTemplate.id);
    final pr = await db.setsDao.getPersonalRecord(exerciseId);
    if (mounted) setState(() { _lastSets[exerciseId] = lastSets; _prData[exerciseId] = pr; });
  }

  // ── Add exercise ──────────────────────────────────────────────────────────────

  void _showAddExerciseSheet(int insertAt) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ExerciseLibrarySheet(
        title: 'Add Exercise',
        onSelected: (exercise) { Navigator.pop(context); _showAddExerciseConfig(insertAt, exercise); },
      ),
    );
  }

  void _showAddExerciseConfig(int insertAt, Exercise exercise) {
    int sets = 3, repMax = 12, durationSecs = 30;
    final isTimed = exercise.isTimed;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exercise.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Configure for this session', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
            const SizedBox(height: 20),
            if (isTimed)
              Row(children: [
                Expanded(child: ConfigStepper(label: 'Sets', value: sets, min: 1, max: 10, onChanged: (v) => setM(() => sets = v))),
                const SizedBox(width: 12),
                Expanded(child: ConfigStepper(label: 'Duration (s)', value: durationSecs, min: 5, max: 600, step: 5, onChanged: (v) => setM(() => durationSecs = v))),
              ])
            else
              Row(children: [
                Expanded(child: ConfigStepper(label: 'Sets', value: sets, min: 1, max: 10, onChanged: (v) => setM(() => sets = v))),
                const SizedBox(width: 12),
                Expanded(child: ConfigStepper(label: 'Reps', value: repMax, min: 1, max: 100, onChanged: (v) => setM(() => repMax = v))),
              ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _insertAdHocExercise(
                  insertAt, exercise, sets,
                  isTimed ? durationSecs : (repMax * 0.8).round(),
                  isTimed ? durationSecs : repMax,
                );
              },
              child: const Text('Add to Workout'),
            )),
          ]),
        ),
      ),
    );
  }

  void _insertAdHocExercise(int insertAt, Exercise exercise, int sets, int repMin, int repMax) {
    final fakeTe = WodTemplateExercise(
      id: -(DateTime.now().millisecondsSinceEpoch),
      wodTemplateId: widget.result.wodTemplate.id,
      exerciseId: exercise.id,
      sortOrder: insertAt,
      targetSets: sets,
      repRangeMin: repMin,
      repRangeMax: repMax,
    );
    final entry = WodExerciseEntry(
      templateExercise: fakeTe, exercise: exercise, suggestion: WeightSuggestion.noHistory,
    );
    final si = SessionItem(id: _nextItemId++, wodItem: StandaloneWodExercise(entry: entry, restSeconds: null), isAdHoc: true);
    setState(() {
      _sessionItems.insert(insertAt, si);
      _setData[exercise.id] = List.generate(sets, (_) => SetData(weightKg: 0, reps: 0));
      _lastSets[exercise.id] = [];
      _prData[exercise.id] = null;
      if (_allExercisesDone) {
        // All previous exercises were finished — make the new item active.
        _currentItemIdx = insertAt;
        _currentSetIdx = 0;
        _allExercisesDone = false;
      } else if (insertAt < _currentItemIdx) {
        // Inserting before the current item shifts it forward.
        _currentItemIdx++;
      }
      // insertAt >= _currentItemIdx and not all done → new item is upcoming,
      // current item stays active (user will reach it naturally).
    });
    _saveProgress();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalItems = _sessionItems.length;
    final progressValue = totalItems == 0 ? 0.0 : _currentItemIdx / totalItems;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.result.wodTemplate.name),
          Text(
            () {
              if (_loading || _sessionItems.isEmpty) return 'Week ${widget.result.weekNumberInProgram}';
              final circuit = _currentCircuit;
              if (circuit != null) {
                final name = (circuit.name != null && circuit.name!.isNotEmpty) ? circuit.name! : 'Circuit';
                return 'Week ${widget.result.weekNumberInProgram} · $name · Round ${_currentSetIdx + 1}/${circuit.rounds}';
              }
              final ts = _currentEntry.templateExercise.targetSets;
              return 'Week ${widget.result.weekNumberInProgram} · Set ${_currentSetIdx + 1}/$ts';
            }(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 4,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving || _loading ? null : _finish,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
            ReorderableListView.builder(
              padding: EdgeInsets.fromLTRB(16, _resting ? 72 : 8, 16, 24),
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              itemCount: _sessionItems.length,
              itemBuilder: (_, itemIdx) {
                final state = _cardStateFor(itemIdx);
                final si = _sessionItems[itemIdx];
                return Padding(
                  key: ValueKey(si.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: switch (si.wodItem) {
                    StandaloneWodExercise(:final entry) => ExerciseCard(
                        entry: entry,
                        cardState: state,
                        itemIndex: itemIdx,
                        dragIndex: state == CardState.completed ? null : itemIdx,
                        setData: _setData[entry.templateExercise.exerciseId] ?? [],
                        currentSetIdx: itemIdx == _currentItemIdx ? _currentSetIdx : -1,
                        lastSets: _lastSets[entry.templateExercise.exerciseId] ?? [],
                        prKg: _prData[entry.templateExercise.exerciseId],
                        prDurationSeconds: _prDurationData[entry.templateExercise.exerciseId],
                        skippedSets: si.skippedSets,
                        isAdHoc: si.isAdHoc,
                        timedRunning: itemIdx == _currentItemIdx ? _timedRunning : false,
                        timedElapsed: itemIdx == _currentItemIdx ? _timedElapsed : 0,
                        timedStopped: itemIdx == _currentItemIdx ? _timedStopped : false,
                        historyExpanded: _historyExpanded[entry.templateExercise.exerciseId] ?? false,
                        onToggleHistory: () => setState(() {
                          final id = entry.templateExercise.exerciseId;
                          _historyExpanded[id] = !(_historyExpanded[id] ?? false);
                        }),
                        onSetDataChanged: (setIdx, data) => _onSetChanged(entry.templateExercise.exerciseId, setIdx, data),
                        onDoneSet: itemIdx == _currentItemIdx ? _onDoneSet : null,
                        onStartTimer: itemIdx == _currentItemIdx ? _startExerciseTimer : null,
                        onStopTimer: itemIdx == _currentItemIdx ? _stopExerciseTimer : null,
                        onSkipSet: (setIdx) => _skipSet(itemIdx, setIdx),
                        onEditSet: (setIdx) => _editSet(context, itemIdx, setIdx),
                        onShowActions: () => _showExerciseActions(context, itemIdx),
                      ),
                    WodCircuit() => CircuitCard(
                        circuit: si.wodItem as WodCircuit,
                        cardState: state,
                        itemIndex: itemIdx,
                        dragIndex: state == CardState.completed ? null : itemIdx,
                        currentItemIdx: _currentItemIdx,
                        currentSetIdx: _currentSetIdx,
                        currentCircuitExIdx: _circuitExerciseIdx,
                        setData: _setData,
                        lastSets: _lastSets,
                        prData: _prData,
                        prDurationData: _prDurationData,
                        historyExpanded: _historyExpanded,
                        onToggleHistory: (exerciseId) => setState(() {
                          _historyExpanded[exerciseId] = !(_historyExpanded[exerciseId] ?? false);
                        }),
                        onSetDataChanged: _onSetChanged,
                        onDoneSet: itemIdx == _currentItemIdx ? _onDoneSet : null,
                        onStartTimer: itemIdx == _currentItemIdx ? _startExerciseTimer : null,
                        onStopTimer: itemIdx == _currentItemIdx ? _stopExerciseTimer : null,
                        onShowCircuitActions: () => _showExerciseActions(context, itemIdx),
                        onShowExerciseActions: (exIdx) => _showCircuitExerciseActions(context, itemIdx, exIdx),
                        timedRunning: itemIdx == _currentItemIdx ? _timedRunning : false,
                        timedElapsed: itemIdx == _currentItemIdx ? _timedElapsed : 0,
                        timedStopped: itemIdx == _currentItemIdx ? _timedStopped : false,
                      ),
                  },
                );
              },
            ),
          if (!_loading && _sessionItems.isNotEmpty)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              top: _resting ? 8 : -80,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _resting ? 1.0 : 0.0,
                child: RestPill(
                  secondsLeft: _restSecondsLeft,
                  totalSeconds: _restTotalSeconds,
                  currentLabel: _getCurrentRestLabel(),
                  nextLabel: _getNextLabel(),
                  onSkip: _skipRest,
                ),
              ),
            ),
          if (_showResumePrompt && !_loading)
            ResumePromptOverlay(
              savedAtMs: _savedAtMs,
              onResume: _resumeWorkout,
              onRestart: _restartWorkout,
              onDiscard: _discardWorkout,
            ),
          if (_countingDown && !_loading && _sessionItems.isNotEmpty)
            CountdownOverlay(
              secondsLeft: _countdownLeft,
              exerciseName: _currentEntry.exercise.name,
              setLabel: _circuitContext ?? 'Set ${_currentSetIdx + 1} / ${_currentEntry.templateExercise.targetSets}',
              circuitNextLabel: _circuitNextLabel,
            ),
        ],
      ),
    );
  }
}

// ─── HistoryChipRow ──────────────────────────────────────────────────────────

class HistoryChipRow extends StatelessWidget {
  final List<WorkoutSet> lastSets;
  final bool isTimed;
  final double? prKg;
  final int? prDurationSeconds;
  final bool expanded;
  final VoidCallback onToggle;

  const HistoryChipRow({super.key, 
    required this.lastSets, required this.isTimed,
    required this.prKg, required this.prDurationSeconds,
    required this.expanded, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasHistory = lastSets.isNotEmpty;
    final prStr = isTimed
        ? (prDurationSeconds != null && prDurationSeconds! > 0 ? fmtSec(prDurationSeconds!) : null)
        : (prKg != null && prKg! > 0 ? '${fmtW(prKg!)} kg' : null);

    if (!hasHistory && prStr == null) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (hasHistory)
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Last', style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 13, color: Colors.white38),
              ]),
            ),
          ),
        if (hasHistory && prStr != null) const SizedBox(width: 8),
        if (prStr != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Text('PR $prStr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber)),
          ),
      ]),
      if (expanded && hasHistory) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (int i = 0; i < lastSets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 46, child: Text('Set ${i + 1}', style: const TextStyle(fontSize: 10, color: Colors.white38))),
                  if (!isTimed)
                    Expanded(child: Text('${fmtW(lastSets[i].weightKg)} kg',
                        style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(
                    isTimed ? fmtSec(lastSets[i].durationSeconds ?? 0) : '× ${lastSets[i].reps} reps',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  )),
                  if (lastSets[i].rpe != null)
                    Text('RPE ${fmtRpe(lastSets[i].rpe!)}',
                        style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }
}

// ─── SetRowItem ──────────────────────────────────────────────────────────────

class SetRowItem extends StatelessWidget {
  final int setIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final bool isSkipped;
  final bool canSkip;
  final SetData data;
  final void Function(SetData)? onChanged;
  final VoidCallback onSkip;
  final VoidCallback? onEdit;

  const SetRowItem({
    super.key,
    required this.setIndex, required this.isTimed,
    required this.isActive, required this.isDone, required this.isSkipped,
    required this.canSkip, required this.data,
    required this.onChanged, required this.onSkip, this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onLongPress: canSkip ? onSkip : null,
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 46, child: Text('Set ${setIndex + 1}', style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            color: isActive ? accent : Colors.white.withValues(alpha: isDone ? 0.4 : 0.22),
            decoration: isSkipped ? TextDecoration.lineThrough : null,
          ))),
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: isSkipped ? Colors.white12 : isDone ? Colors.green : isActive ? accent : Colors.white24,
          ),
          const SizedBox(width: 8),
          if (isActive && onChanged != null)
            Expanded(child: SetRow(
              key: ValueKey('srinput-$setIndex'),
              setNumber: setIndex + 1, isTimed: isTimed,
              data: data, onChanged: onChanged!,
            ))
          else ...[
            if (!isTimed) ...[
              Expanded(child: ReadOnlyField(
                label: 'WEIGHT',
                value: isSkipped || data.weightKg == 0 ? '—' : '${fmtW(data.weightKg)} kg',
                dim: !isDone,
              )),
              const SizedBox(width: 6),
            ],
            Expanded(child: ReadOnlyField(
              label: isTimed ? 'DURATION' : 'REPS',
              value: isSkipped ? 'skip'
                  : isTimed ? (data.durationSeconds > 0 ? fmtSec(data.durationSeconds) : '—')
                  : (data.reps > 0 ? '${data.reps}' : '—'),
              dim: !isDone,
              strikethrough: isSkipped,
              accent: isSkipped ? Colors.orange : null,
            )),
            if (onEdit != null)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.edit, size: 12, color: Colors.white24),
              ),
          ],
        ]),
      ),
    );
  }
}

// ─── ExerciseCard ────────────────────────────────────────────────────────────

class ExerciseCard extends StatelessWidget {
  final WodExerciseEntry entry;
  final CardState cardState;
  final int itemIndex;
  final int? dragIndex;
  final List<SetData> setData;
  final int currentSetIdx;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final Set<int> skippedSets;
  final bool isAdHoc;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final void Function(int) onSkipSet;
  final void Function(int) onEditSet;
  final VoidCallback onShowActions;

  const ExerciseCard({super.key, 
    required this.entry, required this.cardState, required this.itemIndex,
    this.dragIndex,
    required this.setData, required this.currentSetIdx, required this.lastSets,
    required this.prKg, required this.prDurationSeconds, required this.skippedSets,
    required this.isAdHoc, required this.timedRunning, required this.timedElapsed,
    required this.timedStopped, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onSkipSet, required this.onEditSet, required this.onShowActions,
  });

  static void _showCoachingNotes(
      BuildContext context, WodExerciseEntry entry, WodTemplateExercise te) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1e2030),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(entry.exercise.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            const Text('Coaching Notes',
                style: TextStyle(fontSize: 10, color: Colors.white38)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                te.notes!,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5),
              ),
            ),
            if (te.targetRpe != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Target RPE',
                      style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text(
                    te.targetRpe! == te.targetRpe!.truncateToDouble()
                        ? te.targetRpe!.toInt().toString()
                        : te.targetRpe!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFBBF24)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final te = entry.templateExercise;
    final isTimed = entry.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;
    final isActive = cardState == CardState.active;
    final isDone = cardState == CardState.completed;

    final borderColor = isActive
        ? accent.withValues(alpha: 0.6)
        : isDone ? Colors.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08);
    final bgColor = isActive
        ? accent.withValues(alpha: 0.09)
        : isDone ? Colors.green.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isActive ? 1.5 : 1.0),
        boxShadow: isActive ? [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 14, spreadRadius: 1)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isActive) StatusBadge(label: '▶ NOW', color: accent)
              else if (isDone) const StatusBadge(label: '✓ DONE', color: Colors.green)
              else if (isAdHoc) const StatusBadge(label: '＋ added', color: Colors.orange),
              Text(entry.exercise.name,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                isTimed ? '${te.targetSets} sets · ${fmtSec(te.repRangeMin)}'
                        : '${te.targetSets} sets · ${te.repRangeMin}–${te.repRangeMax} reps',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (te.notes != null && te.notes!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      onPressed: () => _showCoachingNotes(context, entry, te),
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.white38,
                      ),
                    ),
                  if (dragIndex != null)
                    ReorderableDragStartListener(
                      index: dragIndex!,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Icon(Icons.drag_handle, size: 20, color: Colors.white24),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: onShowActions,
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white38,
                    ),
                  ),
                ],
              ),
              if (!isTimed) SuggestionBadge(suggestion: entry.suggestion),
            ]),
          ]),
          const SizedBox(height: 8),
          // History chip
          HistoryChipRow(
            lastSets: lastSets, isTimed: isTimed,
            prKg: prKg, prDurationSeconds: prDurationSeconds,
            expanded: historyExpanded, onToggle: onToggleHistory,
          ),
          const SizedBox(height: 10),
          if (isActive && te.targetRpe != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set ${currentSetIdx + 1} / ${te.targetSets}',
                  style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Target RPE ${te.targetRpe! == te.targetRpe!.truncateToDouble() ? te.targetRpe!.toInt() : te.targetRpe!.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Set rows
          ...List.generate(te.targetSets, (setIdx) {
            final isSetActive = isActive && setIdx == currentSetIdx;
            final isSetDone = (isActive && setIdx < currentSetIdx) ||
                (isDone && !skippedSets.contains(setIdx));
            final isSetSkipped = skippedSets.contains(setIdx);
            return SetRowItem(
              key: ValueKey('set-${te.exerciseId}-$itemIndex-$setIdx'),
              setIndex: setIdx, isTimed: isTimed,
              isActive: isSetActive, isDone: isSetDone, isSkipped: isSetSkipped,
              canSkip: !isSetActive && !isSetDone && !isSetSkipped && isActive,
              data: setIdx < setData.length ? setData[setIdx] : SetData(weightKg: 0, reps: 0),
              onChanged: isSetActive ? (data) => onSetDataChanged(setIdx, data) : null,
              onSkip: () => onSkipSet(setIdx),
              onEdit: isSetDone ? () => onEditSet(setIdx) : null,
            );
          }),
          // Done button / timer
          if (isActive && onDoneSet != null) ...[
            const SizedBox(height: 12),
            if (isTimed)
              TimedSetInput(
                running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
                target: te.repRangeMin, isCircuit: false,
                onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
              )
            else
              Center(child: CheckCircleButton(
                key: ValueKey('check-${entry.exercise.id}-$currentSetIdx'),
                onDone: onDoneSet!,
              )),
          ],
        ]),
      ),
    );
  }
}

// ─── RoundRowItem ────────────────────────────────────────────────────────────

class RoundRowItem extends StatelessWidget {
  final int roundIndex;
  final bool isTimed;
  final bool isActive;
  final bool isDone;
  final SetData data;
  final void Function(SetData)? onChanged;

  const RoundRowItem({super.key, 
    required this.roundIndex, required this.isTimed,
    required this.isActive, required this.isDone,
    required this.data, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 54, child: Text('Round ${roundIndex + 1}', style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          color: isActive ? teal : Colors.white.withValues(alpha: isDone ? 0.4 : 0.2),
        ))),
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13, color: isDone ? teal : isActive ? accent : Colors.white24),
        const SizedBox(width: 8),
        if (isActive && onChanged != null)
          Expanded(child: SetRow(
            key: ValueKey('round-input-$roundIndex'),
            setNumber: roundIndex + 1, isTimed: isTimed,
            data: data, onChanged: onChanged!,
          ))
        else ...[
          if (!isTimed) ...[
            Expanded(child: ReadOnlyField(label: 'WEIGHT',
                value: data.weightKg > 0 ? '${fmtW(data.weightKg)} kg' : '—', dim: !isDone)),
            const SizedBox(width: 6),
          ],
          Expanded(child: ReadOnlyField(
            label: isTimed ? 'DURATION' : 'REPS',
            value: isTimed ? (data.durationSeconds > 0 ? fmtSec(data.durationSeconds) : '—')
                           : (data.reps > 0 ? '${data.reps}' : '—'),
            dim: !isDone,
          )),
        ],
      ]),
    );
  }
}

// ─── CircuitExerciseSection ──────────────────────────────────────────────────

class CircuitExerciseSection extends StatelessWidget {
  final WodExerciseEntry exercise;
  final int rounds;
  final bool isCurrentExercise;
  final int currentRound;
  final List<SetData> setData;
  final List<WorkoutSet> lastSets;
  final double? prKg;
  final int? prDurationSeconds;
  final bool historyExpanded;
  final VoidCallback onToggleHistory;
  final void Function(int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;

  const CircuitExerciseSection({super.key, 
    required this.exercise, required this.rounds,
    required this.isCurrentExercise, required this.currentRound,
    required this.setData, required this.lastSets,
    required this.prKg, required this.prDurationSeconds,
    required this.historyExpanded, required this.onToggleHistory,
    required this.onSetDataChanged, required this.onDoneSet,
    required this.onStartTimer, required this.onStopTimer,
    required this.onShowActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
  });

  @override
  Widget build(BuildContext context) {
    final te = exercise.templateExercise;
    final isTimed = exercise.exercise.isTimed;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isCurrentExercise) StatusBadge(label: '▶ NOW', color: accent),
            Text(exercise.exercise.name,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            Text(
              isTimed ? fmtSec(te.repRangeMin) : '${te.repRangeMax} reps',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ])),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 18),
            onPressed: onShowActions,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
          ),
        ]),
        const SizedBox(height: 6),
        HistoryChipRow(
          lastSets: lastSets, isTimed: isTimed,
          prKg: prKg, prDurationSeconds: prDurationSeconds,
          expanded: historyExpanded, onToggle: onToggleHistory,
        ),
        const SizedBox(height: 8),
        for (int r = 0; r < rounds; r++)
          RoundRowItem(
            roundIndex: r, isTimed: isTimed,
            isActive: isCurrentExercise && r == currentRound,
            isDone: r < currentRound || (!isCurrentExercise && r < setData.length &&
                (isTimed ? setData[r].durationSeconds > 0 : setData[r].reps > 0)),
            data: r < setData.length ? setData[r] : SetData(weightKg: 0, reps: 0),
            onChanged: isCurrentExercise && r == currentRound ? (d) => onSetDataChanged(r, d) : null,
          ),
        if (isCurrentExercise && onDoneSet != null) ...[
          const SizedBox(height: 10),
          if (isTimed)
            TimedSetInput(
              running: timedRunning, elapsed: timedElapsed, stopped: timedStopped,
              target: te.repRangeMin, isCircuit: true,
              onStart: onStartTimer ?? () {}, onStop: onStopTimer ?? () {},
            )
          else
            Center(child: CheckCircleButton(
              key: ValueKey('circ-check-${te.exerciseId}-$currentRound'),
              onDone: onDoneSet!,
            )),
        ],
      ]),
    );
  }
}

// ─── CircuitCard ─────────────────────────────────────────────────────────────

class CircuitCard extends StatelessWidget {
  final WodCircuit circuit;
  final CardState cardState;
  final int itemIndex;
  final int currentItemIdx;
  final int currentSetIdx;
  final int currentCircuitExIdx;
  final Map<int, List<SetData>> setData;
  final Map<int, List<WorkoutSet>> lastSets;
  final Map<int, double?> prData;
  final Map<int, int?> prDurationData;
  final Map<int, bool> historyExpanded;
  final void Function(int) onToggleHistory;
  final void Function(int, int, SetData) onSetDataChanged;
  final VoidCallback? onDoneSet;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback onShowCircuitActions;
  final void Function(int) onShowExerciseActions;
  final bool timedRunning;
  final int timedElapsed;
  final bool timedStopped;
  final int? dragIndex;

  const CircuitCard({super.key, 
    required this.circuit, required this.cardState, required this.itemIndex,
    required this.currentItemIdx, required this.currentSetIdx,
    required this.currentCircuitExIdx, required this.setData, required this.lastSets,
    required this.prData, required this.prDurationData, required this.historyExpanded,
    required this.onToggleHistory, required this.onSetDataChanged,
    required this.onDoneSet, required this.onStartTimer, required this.onStopTimer,
    required this.onShowCircuitActions, required this.onShowExerciseActions,
    required this.timedRunning, required this.timedElapsed, required this.timedStopped,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final teal = Theme.of(context).colorScheme.secondary;
    final isActive = cardState == CardState.active && itemIndex == currentItemIdx;
    final isDone = cardState == CardState.completed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: isDone ? 0.04 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? teal.withValues(alpha: 0.55) : isDone ? Colors.green.withValues(alpha: 0.25) : teal.withValues(alpha: 0.18),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive ? [BoxShadow(color: teal.withValues(alpha: 0.12), blurRadius: 12)] : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Circuit header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(children: [
            Icon(Icons.loop, size: 14, color: teal),
            const SizedBox(width: 7),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                circuit.name != null && circuit.name!.isNotEmpty ? circuit.name! : 'Circuit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: teal),
              ),
              Text(
                '${circuit.rounds} rounds · ${circuit.restBetweenRoundsSeconds}s rest between rounds',
                style: TextStyle(fontSize: 9, color: teal.withValues(alpha: 0.6)),
              ),
            ])),
            if (isDone) const StatusBadge(label: '✓ DONE', color: Colors.green),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.drag_handle, size: 20, color: Colors.white24),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_horiz, size: 18),
              onPressed: onShowCircuitActions,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: Colors.white38),
            ),
          ]),
        ),
        Divider(height: 1, color: teal.withValues(alpha: 0.08)),
        for (int exIdx = 0; exIdx < circuit.exercises.length; exIdx++) ...[
          CircuitExerciseSection(
            exercise: circuit.exercises[exIdx],
            rounds: circuit.rounds,
            isCurrentExercise: isActive && exIdx == currentCircuitExIdx,
            currentRound: isActive ? currentSetIdx : -1,
            setData: setData[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
            lastSets: lastSets[circuit.exercises[exIdx].templateExercise.exerciseId] ?? [],
            prKg: prData[circuit.exercises[exIdx].templateExercise.exerciseId],
            prDurationSeconds: prDurationData[circuit.exercises[exIdx].templateExercise.exerciseId],
            historyExpanded: historyExpanded[circuit.exercises[exIdx].templateExercise.exerciseId] ?? false,
            onToggleHistory: () => onToggleHistory(circuit.exercises[exIdx].templateExercise.exerciseId),
            onSetDataChanged: (r, d) => onSetDataChanged(circuit.exercises[exIdx].templateExercise.exerciseId, r, d),
            onDoneSet: isActive && exIdx == currentCircuitExIdx ? onDoneSet : null,
            onStartTimer: isActive && exIdx == currentCircuitExIdx ? onStartTimer : null,
            onStopTimer: isActive && exIdx == currentCircuitExIdx ? onStopTimer : null,
            onShowActions: () => onShowExerciseActions(exIdx),
            timedRunning: isActive && exIdx == currentCircuitExIdx ? timedRunning : false,
            timedElapsed: isActive && exIdx == currentCircuitExIdx ? timedElapsed : 0,
            timedStopped: isActive && exIdx == currentCircuitExIdx ? timedStopped : false,
          ),
          if (exIdx < circuit.exercises.length - 1)
            const Divider(height: 1, color: Color(0x08FFFFFF)),
        ],
        const SizedBox(height: 6),
      ]),
    );
  }
}

// ─── _cfgBtn helper ──────────────────────────────────────────────────────────

Widget _cfgBtn(ColorScheme cs, bool enabled, IconData icon, VoidCallback cb) =>
    SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: cs.onSurface.withValues(alpha: enabled ? 0.09 : 0.04),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: enabled ? cb : null,
          borderRadius: BorderRadius.circular(7),
          child: Center(
            child: Icon(icon, size: 14,
                color: cs.onSurface.withValues(alpha: enabled ? 0.8 : 0.25)),
          ),
        ),
      ),
    );

// ─── ConfigStepper ───────────────────────────────────────────────────────────

class ConfigStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final void Function(int) onChanged;
  const ConfigStepper({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged, this.step = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.55))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _cfgBtn(cs, value > min, Icons.remove, () => onChanged((value - step).clamp(min, max))),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        _cfgBtn(cs, value < max, Icons.add, () => onChanged((value + step).clamp(min, max))),
      ]),
    ]);
  }
}

// ─── ExerciseLibrarySheet ────────────────────────────────────────────────────

class ExerciseLibrarySheet extends ConsumerStatefulWidget {
  final String title;
  final void Function(Exercise) onSelected;
  const ExerciseLibrarySheet({super.key, required this.title, required this.onSelected});

  @override
  ConsumerState<ExerciseLibrarySheet> createState() => _ExerciseLibrarySheetState();
}

class _ExerciseLibrarySheetState extends ConsumerState<ExerciseLibrarySheet> {
  String _query = '';
  List<Exercise> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider).exercisesDao.getAllExercises().then((list) {
      if (mounted) setState(() { _all = list; _loading = false; });
    });
  }

  List<Exercise> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect(String name) async {
    final db = ref.read(databaseProvider);
    final id = await db.exercisesDao.insertExercise(ExercisesCompanion.insert(name: name));
    final created = Exercise(id: id, name: name, isTimed: false, category: 'Other', notes: null);
    if (mounted) widget.onSelected(created);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final showCreate = _query.isNotEmpty &&
        filtered.every((e) => e.name.toLowerCase() != _query.toLowerCase());

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(controller: scroll, children: [
                    if (showCreate)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                        title: Text('Create "$_query"', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('Add to exercise library'),
                        onTap: () => _createAndSelect(_query),
                      ),
                    for (final ex in filtered)
                      ListTile(
                        title: Text(ex.name),
                        subtitle: Text(ex.isTimed ? 'Timed' : 'Weighted', style: const TextStyle(fontSize: 11)),
                        onTap: () => widget.onSelected(ex),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ─── RestPill ─────────────────────────────────────────────────────────────────

class RestPill extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final String currentLabel;
  final String nextLabel;
  final VoidCallback onSkip;

  const RestPill({super.key, 
    required this.secondsLeft,
    required this.totalSeconds,
    required this.currentLabel,
    required this.nextLabel,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final progress = totalSeconds > 0 ? secondsLeft / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        SizedBox(
          width: 36, height: 36,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: Colors.white12,
              color: accent,
            ),
            Text(
              fmtSec(secondsLeft),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLabel,
                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              if (nextLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  nextLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.skip_next, size: 14),
          label: const Text('Skip', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white54,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
    );
  }
}

// ─── ResumePromptOverlay ─────────────────────────────────────────────────────

class ResumePromptOverlay extends StatelessWidget {
  final int? savedAtMs;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onDiscard;

  const ResumePromptOverlay({super.key, required this.savedAtMs, required this.onResume, required this.onRestart, required this.onDiscard});

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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.fitness_center, size: 52, color: accent),
              const SizedBox(height: 20),
              const Text('Resume Workout?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              if (_timeAgo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Last saved $_timeAgo', style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
              const SizedBox(height: 36),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: onResume,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                PromptAction(icon: Icons.restart_alt, label: 'Restart', color: Colors.white70, onTap: onRestart),
                const SizedBox(width: 40),
                PromptAction(icon: Icons.close, label: 'Discard', color: Colors.red.shade300, onTap: onDiscard),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class PromptAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const PromptAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    IconButton.outlined(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.4))),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  ]);
}

// ─── CountdownOverlay ────────────────────────────────────────────────────────

class CountdownOverlay extends StatelessWidget {
  final int secondsLeft;
  final String exerciseName;
  final String setLabel;
  final String? circuitNextLabel;

  const CountdownOverlay({super.key, required this.secondsLeft, required this.exerciseName, required this.setLabel, this.circuitNextLabel});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isGo = secondsLeft <= 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('AUTOPILOT', style: TextStyle(color: accent.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
          const SizedBox(height: 12),
          Text(exerciseName, style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          Text(setLabel, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          if (circuitNextLabel != null) ...[
            const SizedBox(height: 4),
            Text(circuitNextLabel!, style: const TextStyle(color: Colors.white24, fontSize: 12)),
          ],
          const SizedBox(height: 48),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isGo ? 'GO!' : '$secondsLeft',
              key: ValueKey(secondsLeft),
              style: TextStyle(color: isGo ? Colors.greenAccent : Colors.white, fontSize: 100, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          const SizedBox(height: 32),
          Text(isGo ? 'Starting...' : 'Get ready', style: const TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      ),
    );
  }
}

// ─── SetRow (stepper widget) ─────────────────────────────────────────────────

class SetRow extends StatefulWidget {
  final int setNumber;
  final bool isTimed;
  final SetData data;
  final void Function(SetData) onChanged;

  const SetRow({
    super.key,
    required this.setNumber, required this.isTimed,
    required this.data, required this.onChanged,
  });

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  bool _editingWeight = false;
  bool _editingSecondary = false;
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

  void _handleWeight(double delta) {
    widget.onChanged(SetData(
      weightKg: (widget.data.weightKg + delta).clamp(0.0, double.infinity),
      reps: widget.data.reps,
      durationSeconds: widget.data.durationSeconds,
      rpe: widget.data.rpe,
    ));
  }

  void _handleReps(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: (widget.data.reps + delta).clamp(1, 999), rpe: widget.data.rpe));
  }

  void _handleDuration(int delta) {
    widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: (widget.data.durationSeconds + delta).clamp(5, 3600), rpe: widget.data.rpe));
  }

  void _commitWeight() {
    final v = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (v != null && v >= 0) {
      widget.onChanged(SetData(weightKg: v, reps: widget.data.reps, durationSeconds: widget.data.durationSeconds, rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingWeight = false);
  }

  void _commitReps() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: v, rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  void _commitDuration() {
    final v = int.tryParse(_secondaryCtrl.text);
    if (v != null && v >= 1) {
      widget.onChanged(SetData(weightKg: widget.data.weightKg, reps: 0, durationSeconds: v.clamp(5, 3600), rpe: widget.data.rpe));
    }
    if (mounted) setState(() => _editingSecondary = false);
  }

  @override
  Widget build(BuildContext context) {
    final isTimed = widget.isTimed;
    final dur = widget.data.durationSeconds;

    return Row(children: [
      if (!isTimed) ...[
        Expanded(child: StepperField(
          label: _editingWeight ? null : '${fmtW(widget.data.weightKg)} kg',
          editingController: _editingWeight ? _weightCtrl : null,
          onDecrement: () => _handleWeight(-2.5),
          onIncrement: () => _handleWeight(2.5),
          onTapValue: () => setState(() {
            _weightCtrl.text = fmtW(widget.data.weightKg);
            _weightCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _weightCtrl.text.length);
            _editingWeight = true; _editingSecondary = false;
          }),
          onCommit: _commitWeight,
        )),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: isTimed
            ? StepperField(
                label: _editingSecondary ? null : fmtSec(dur),
                editingController: _editingSecondary ? _secondaryCtrl : null,
                isInteger: true,
                onDecrement: () => _handleDuration(-5),
                onIncrement: () => _handleDuration(5),
                onTapValue: () => setState(() {
                  _secondaryCtrl.text = dur.toString();
                  _secondaryCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                  _editingSecondary = true; _editingWeight = false;
                }),
                onCommit: _commitDuration,
              )
            : StepperField(
                label: _editingSecondary ? null : '${widget.data.reps}',
                editingController: _editingSecondary ? _secondaryCtrl : null,
                isInteger: true,
                onDecrement: () => _handleReps(-1),
                onIncrement: () => _handleReps(1),
                onTapValue: () => setState(() {
                  _secondaryCtrl.text = widget.data.reps.toString();
                  _secondaryCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _secondaryCtrl.text.length);
                  _editingSecondary = true; _editingWeight = false;
                }),
                onCommit: _commitReps,
              ),
      ),
    ]);
  }
}

// ─── StepperField ────────────────────────────────────────────────────────────

class StepperField extends StatelessWidget {
  final String? label;
  final TextEditingController? editingController;
  final bool isInteger;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onTapValue;
  final VoidCallback onCommit;

  const StepperField({super.key, 
    this.label, this.editingController, this.isInteger = false,
    required this.onDecrement, required this.onIncrement,
    required this.onTapValue, required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      StepBtn(icon: Icons.remove, onTap: onDecrement),
      Expanded(
        child: editingController != null
            ? TextField(
                controller: editingController,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6)),
                onSubmitted: (_) => onCommit(),
                onTapOutside: (_) => onCommit(),
              )
            : GestureDetector(
                onTap: onTapValue,
                child: Text(label ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
      ),
      StepBtn(icon: Icons.add, onTap: onIncrement),
    ]);
  }
}

class StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const StepBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16),
    onPressed: onTap,
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ─── CheckCircleButton ───────────────────────────────────────────────────────

class CheckCircleButton extends StatefulWidget {
  final VoidCallback onDone;
  const CheckCircleButton({super.key, required this.onDone});

  @override
  State<CheckCircleButton> createState() => _CheckCircleButtonState();
}

class _CheckCircleButtonState extends State<CheckCircleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 420), vsync: this);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.transparent, Colors.green, fill),
                  border: Border.all(color: Color.lerp(Colors.white30, Colors.green, fill)!, width: 2.5),
                  boxShadow: v > 0.05 ? [BoxShadow(color: Colors.green.withValues(alpha: fill * 0.4), blurRadius: 14, spreadRadius: 2)] : null,
                ),
                child: Icon(Icons.check, color: Color.lerp(Colors.white30, Colors.white, fill), size: 28),
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
          child: Text('Done Set', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
        ),
      ),
    ]);
  }
}

// ─── RpeSheet ────────────────────────────────────────────────────────────────

class RpeSheet extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  const RpeSheet({super.key, required this.exerciseName, required this.setNumber});
  @override
  State<RpeSheet> createState() => _RpeSheetState();
}

class _RpeSheetState extends State<RpeSheet> {
  double? _selected;

  static const _rpeValues = [6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0];
  static final _rpeLabels = <double, String>{
    6.0: 'Very easy',
    6.5: 'Easy',
    7.0: 'Moderate',
    7.5: 'Somewhat hard',
    8.0: 'Hard, 2–3 reps left',
    8.5: 'Very hard, 1–2 reps left',
    9.0: '1 rep left',
    9.5: 'Could not do more reps',
    10.0: 'Max effort',
  };

  void _select(double rpe) {
    setState(() => _selected = rpe);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.of(context).pop(rpe);
    });
  }

  String _label(double rpe) =>
      rpe == rpe.truncateToDouble() ? rpe.toInt().toString() : rpe.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1e2030),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('How hard was that?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Set ${widget.setNumber} · ${widget.exerciseName} · optional',
              style: const TextStyle(fontSize: 10, color: Colors.white38)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: _rpeValues.map((rpe) {
              final isSelected = _selected == rpe;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _select(rpe),
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.07),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFBBF24)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _label(rpe),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : Colors.white38,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selected == null
                ? const Text(
                    'Tap to log · swipe down to skip',
                    key: ValueKey('hint'),
                    style: TextStyle(fontSize: 9, color: Colors.white24),
                  )
                : Container(
                    key: ValueKey(_selected),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_rpeLabels[_selected] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.white54)),
                        Text(
                          'RPE ${_label(_selected!)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
