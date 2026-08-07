import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
import 'audio/session_sound_player.dart';
import 'session_formatters.dart';
import 'widgets/session_common.dart';
import 'widgets/rpe_sheet.dart';
import 'widgets/exercise_card.dart';
import 'widgets/circuit_card.dart';
import 'widgets/config_stepper.dart';
import 'widgets/exercise_library_sheet.dart';
import 'widgets/rest_pill.dart';
import 'widgets/resume_prompt_overlay.dart';
import 'widgets/countdown_overlay.dart';

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
  final SessionSoundPlayer _sound = SessionSoundPlayer();

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
    _sound.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _exerciseTicker?.cancel();
    _countdownTimer?.cancel();
    _sound.dispose();
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
        _sound.playBeep();
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
    _sound.playDoneSound();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _onDoneSet();
    });
  }

  // ── Audio ─────────────────────────────────────────────────────────────────────

  void _onRestComplete() {
    _sound.playBeep();
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
    _sound.playTick();
    _updateNotification();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdownLeft--);
      if (_countdownLeft > 0) {
        _sound.playTick();
      } else {
        t.cancel();
        setState(() => _countingDown = false);
        _sound.playGoSound();
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
