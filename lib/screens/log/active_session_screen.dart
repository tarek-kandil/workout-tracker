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
import '../../services/personal_record_detection.dart';
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
import 'widgets/exercise_notes_sheet.dart';
import 'widgets/exercise_swap_sheet.dart';
import 'widgets/rest_pill.dart';
import 'widgets/resume_prompt_overlay.dart';
import 'widgets/countdown_overlay.dart';

enum _ProgramChangeScope { temporary, permanent }

class _ProgramOrderItem {
  final String key;
  final int sortOrder;
  final WodTemplateExercise? exercise;
  final WodExerciseGroup? group;

  _ProgramOrderItem.exercise(WodTemplateExercise templateExercise)
      : key = 'e:${templateExercise.id}',
        sortOrder = templateExercise.sortOrder,
        exercise = templateExercise,
        group = null;

  _ProgramOrderItem.group(WodExerciseGroup exerciseGroup)
      : key = 'g:${exerciseGroup.id}',
        sortOrder = exerciseGroup.sortOrder,
        group = exerciseGroup,
        exercise = null;
}

// ─── Screen ────────────────────────────────────────────────────────────────────

/// Snapshot of session progress used by the Review & Finish flow and the
/// incomplete-finish warning. Derived from the actual planned item structure
/// (standalone exercises + circuit exercises/rounds), current cursors, and
/// skip state — not from a single overall completion flag.
class _SessionCompletionSummary {
  /// Total planned exercises (each circuit exercise counts individually).
  final int totalExercises;

  /// Exercises whose planned sets are all logged or skipped (resolved).
  final int resolvedExercises;

  /// Exercises resolved solely because the whole item was skipped.
  final int skippedExercises;

  /// Count of sets that hold real logged data (non-skipped, non-zero).
  final int setsLogged;

  /// Names of exercises that still have at least one unresolved planned set.
  final List<String> unfinishedExercises;

  const _SessionCompletionSummary({
    required this.totalExercises,
    required this.resolvedExercises,
    required this.skippedExercises,
    required this.setsLogged,
    required this.unfinishedExercises,
  });

  /// True when no planned set remains neither logged nor skipped.
  bool get isComplete => unfinishedExercises.isEmpty;
}

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

  /// Whether a standalone exercise's set has been passed by the progress cursor
  /// (i.e. logged/done). Mirrors the completion model used across the screen.
  bool _standaloneSetLogged(int itemIdx, int setIdx) =>
      itemIdx < _currentItemIdx ||
      (_allExercisesDone && itemIdx == _currentItemIdx) ||
      (itemIdx == _currentItemIdx && setIdx < _currentSetIdx);

  /// Whether a circuit slot (a given exercise in a given round) has been passed
  /// by the progress cursor. Handles the multi-exercise / multi-round structure.
  bool _circuitSlotLogged(int itemIdx, int round, int exIdx) =>
      itemIdx < _currentItemIdx ||
      (_allExercisesDone && itemIdx == _currentItemIdx) ||
      (itemIdx == _currentItemIdx &&
          (round < _currentSetIdx ||
              (round == _currentSetIdx && exIdx < _circuitExerciseIdx)));

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
        final pr = await db.setsDao.getPersonalRecord(exerciseId);
        _prData[exerciseId] = pr;
        if (pr != null && pr > 0) {
          _prBestReps[exerciseId] = await db.setsDao.getBestRepsAtWeight(exerciseId, pr);
        }
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
        await _refreshAllPrBaselines(notify: false);
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

  /// Returns true if this set is a new PR; updates _prData / _prBestReps when it is.
  bool _checkPrAndUpdate(int exerciseId, double weightKg, int reps) {
    final result = evaluateWeightPersonalRecord(
      currentTopWeightKg: _prData[exerciseId],
      bestRepsAtCurrentTopWeight: _prBestReps[exerciseId] ?? 0,
      weightKg: weightKg,
      reps: reps,
    );
    if (result.isNewTopWeight) {
      _prData[exerciseId] = weightKg;
      _prBestReps[exerciseId] = reps;
    } else if (result.isMoreRepsAtTopWeight) {
      _prBestReps[exerciseId] = reps;
    }
    return result.isPersonalRecord;
  }

  Iterable<SetData> _loggedSetDataForExercise(int exerciseId) sync* {
    for (int itemIdx = 0; itemIdx < _sessionItems.length; itemIdx++) {
      final item = _sessionItems[itemIdx];
      if (item.skipped) continue;
      switch (item.wodItem) {
        case StandaloneWodExercise(:final entry):
          if (entry.templateExercise.exerciseId != exerciseId) continue;
          final sets = _setData[exerciseId] ?? [];
          for (int setIdx = 0; setIdx < sets.length; setIdx++) {
            if (item.skippedSets.contains(setIdx)) continue;
            final isLogged = _standaloneSetLogged(itemIdx, setIdx);
            if (isLogged) yield sets[setIdx];
          }
        case WodCircuit(:final rounds, :final exercises):
          for (int exIdx = 0; exIdx < exercises.length; exIdx++) {
            final entry = exercises[exIdx];
            if (entry.templateExercise.exerciseId != exerciseId) continue;
            final sets = _setData[exerciseId] ?? [];
            for (int round = 0; round < rounds && round < sets.length; round++) {
              final isLogged = _circuitSlotLogged(itemIdx, round, exIdx);
              if (isLogged) yield sets[round];
            }
          }
      }
    }
  }

  Future<({double? topWeightKg, int bestRepsAtTopWeight})>
      _calculatePrBaseline(int exerciseId) async {
    final db = ref.read(databaseProvider);
    double topWeight = await db.setsDao.getPersonalRecord(exerciseId) ?? 0.0;
    int bestReps = topWeight > 0
        ? await db.setsDao.getBestRepsAtWeight(exerciseId, topWeight)
        : 0;

    for (final set in _loggedSetDataForExercise(exerciseId)) {
      final result = evaluateWeightPersonalRecord(
        currentTopWeightKg: topWeight,
        bestRepsAtCurrentTopWeight: bestReps,
        weightKg: set.weightKg,
        reps: set.reps,
      );
      if (result.isNewTopWeight) {
        topWeight = set.weightKg;
        bestReps = set.reps;
      } else if (result.isMoreRepsAtTopWeight) {
        bestReps = set.reps;
      }
    }

    return (
      topWeightKg: topWeight > 0 ? topWeight : null,
      bestRepsAtTopWeight: bestReps,
    );
  }

  Future<void> _refreshPrBaseline(int exerciseId, {bool notify = true}) async {
    final baseline = await _calculatePrBaseline(exerciseId);
    if (!mounted) return;
    void applyBaseline() {
      _prData[exerciseId] = baseline.topWeightKg;
      if (baseline.bestRepsAtTopWeight > 0) {
        _prBestReps[exerciseId] = baseline.bestRepsAtTopWeight;
      } else {
        _prBestReps.remove(exerciseId);
      }
    }
    if (notify) {
      setState(applyBaseline);
    } else {
      applyBaseline();
    }
  }

  Future<void> _refreshAllPrBaselines({bool notify = true}) async {
    final exerciseIds = _prData.keys.toList();
    for (final exerciseId in exerciseIds) {
      await _refreshPrBaseline(exerciseId, notify: false);
    }
    if (notify && mounted) setState(() {});
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
          _allExercisesDone = true;
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

  // ── Review & Finish ─────────────────────────────────────────────────────────────

  /// Computes a completion snapshot from the actual planned item structure
  /// (standalone exercises + circuit exercises across rounds), the progress
  /// cursors, and skip state. Skipped items/sets count as resolved (FR-006/FR-007).
  _SessionCompletionSummary _computeCompletionSummary() {
    int total = 0;
    int resolved = 0;
    int skipped = 0;
    int setsLogged = 0;
    final unfinished = <String>[];

    for (int itemIdx = 0; itemIdx < _sessionItems.length; itemIdx++) {
      final si = _sessionItems[itemIdx];
      final itemSkipped = si.skipped;
      switch (si.wodItem) {
        case StandaloneWodExercise(:final entry):
          total++;
          final exerciseId = entry.templateExercise.exerciseId;
          final targetSets = entry.templateExercise.targetSets;
          final isTimed = entry.exercise.isTimed;
          final sets = _setData[exerciseId] ?? const <SetData>[];
          if (itemSkipped) {
            skipped++;
            resolved++;
          } else {
            bool anyUnfinished = false;
            for (int setIdx = 0; setIdx < targetSets; setIdx++) {
              if (si.skippedSets.contains(setIdx)) continue;
              if (_standaloneSetLogged(itemIdx, setIdx)) {
                if (setIdx < sets.length) {
                  final s = sets[setIdx];
                  if (isTimed ? s.durationSeconds > 0 : s.reps > 0) setsLogged++;
                }
              } else {
                anyUnfinished = true;
              }
            }
            if (anyUnfinished) {
              unfinished.add(entry.exercise.name);
            } else {
              resolved++;
            }
          }
        case WodCircuit(:final rounds, :final exercises):
          for (int exIdx = 0; exIdx < exercises.length; exIdx++) {
            total++;
            final entry = exercises[exIdx];
            final exerciseId = entry.templateExercise.exerciseId;
            final isTimed = entry.exercise.isTimed;
            final sets = _setData[exerciseId] ?? const <SetData>[];
            if (itemSkipped) {
              skipped++;
              resolved++;
              continue;
            }
            bool anyUnfinished = false;
            for (int round = 0; round < rounds; round++) {
              if (_circuitSlotLogged(itemIdx, round, exIdx)) {
                if (round < sets.length) {
                  final s = sets[round];
                  if (isTimed ? s.durationSeconds > 0 : s.reps > 0) setsLogged++;
                }
              } else {
                anyUnfinished = true;
              }
            }
            if (anyUnfinished) {
              unfinished.add(entry.exercise.name);
            } else {
              resolved++;
            }
          }
      }
    }

    return _SessionCompletionSummary(
      totalExercises: total,
      resolvedExercises: resolved,
      skippedExercises: skipped,
      setsLogged: setsLogged,
      unfinishedExercises: unfinished,
    );
  }

  /// Entry point for the deliberate finish path (FR-002). Opens the review
  /// summary; only completes after an explicit confirmation (FR-003/FR-013).
  Future<void> _reviewAndFinish() async {
    if (_saving || _loading || _sessionItems.isEmpty) return;
    final summary = _computeCompletionSummary();
    final wantsFinish = await _showReviewSheet(summary);
    if (wantsFinish != true || !mounted) return;
    if (!summary.isComplete) {
      final finishAnyway = await _showIncompleteWarning(summary);
      if (finishAnyway != true || !mounted) return;
    }
    if (_saving) return;
    await _finish();
  }

  Future<bool?> _showReviewSheet(_SessionCompletionSummary summary) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Review & Finish', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${summary.resolvedExercises} of ${summary.totalExercises} exercises done',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _reviewStatRow(Icons.fitness_center, 'Exercises',
                          '${summary.totalExercises}'),
                      _reviewStatRow(Icons.check_circle_outline, 'Completed / resolved',
                          '${summary.resolvedExercises}'),
                      _reviewStatRow(Icons.playlist_add_check, 'Sets logged',
                          '${summary.setsLogged}'),
                      if (summary.skippedExercises > 0)
                        _reviewStatRow(Icons.skip_next, 'Skipped',
                            '${summary.skippedExercises}'),
                      if (summary.unfinishedExercises.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.error_outline, size: 18, color: cs.error),
                          const SizedBox(width: 8),
                          Text(
                            'Unfinished (${summary.unfinishedExercises.length})',
                            style: theme.textTheme.labelLarge?.copyWith(color: cs.error),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        for (final name in summary.unfinishedExercises)
                          Padding(
                            padding: const EdgeInsets.only(left: 26, top: 2),
                            child: Text('• $name', style: theme.textTheme.bodyMedium),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep logging'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Finish'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewStatRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<bool?> _showIncompleteWarning(_SessionCompletionSummary summary) {
    final unfinished = summary.unfinishedExercises;
    const maxNamed = 6;
    final named = unfinished.take(maxNamed).toList();
    final remaining = unfinished.length - named.length;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Finish with unfinished work?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'ve completed ${summary.resolvedExercises} of '
                '${summary.totalExercises} exercises. '
                'These still have unfinished sets:',
              ),
              const SizedBox(height: 10),
              for (final name in named)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• $name', style: theme.textTheme.bodyMedium),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('• +$remaining more',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finish anyway'),
            ),
          ],
        );
      },
    );
  }

  // ── Finish ────────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    if (_saving) return;
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

  Future<void> _editSet(BuildContext parentContext, int itemIdx, int setIdx) async {
    final si = _sessionItems[itemIdx];
    if (si.wodItem is! StandaloneWodExercise) return;
    final entry = (si.wodItem as StandaloneWodExercise).entry;
    await _editLoggedSet(parentContext, entry, setIdx);
  }

  Future<void> _editCircuitRound(
      BuildContext parentContext, int itemIdx, int exIdx, int round) async {
    final si = _sessionItems[itemIdx];
    if (si.wodItem is! WodCircuit) return;
    final circuit = si.wodItem as WodCircuit;
    if (exIdx < 0 || exIdx >= circuit.exercises.length) return;
    final entry = circuit.exercises[exIdx];
    await _editLoggedSet(parentContext, entry, round, unitLabel: 'Round');
  }

  Future<void> _editLoggedSet(
    BuildContext parentContext,
    WodExerciseEntry entry,
    int setIdx, {
    String unitLabel = 'Set',
  }) async {
    final exerciseId = entry.templateExercise.exerciseId;
    final isTimed = entry.exercise.isTimed;
    final sets = _setData[exerciseId] ?? [];
    final current = setIdx < sets.length ? sets[setIdx] : SetData(weightKg: 0, reps: 0);

    final saved = await showModalBottomSheet<SetData>(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSetSheet(
        title: 'Edit $unitLabel ${setIdx + 1}',
        exerciseName: entry.exercise.name,
        isTimed: isTimed,
        current: current,
      ),
    );

    if (saved != null && mounted) {
      final changed = !isTimed &&
          (!sameRecordWeight(saved.weightKg, current.weightKg) ||
              saved.reps != current.reps);
      final baseline = changed ? await _calculatePrBaseline(exerciseId) : null;
      final oldPrKg = baseline?.topWeightKg;
      final prResult = baseline == null
          ? PersonalRecordAttemptResult.none
          : evaluateWeightPersonalRecord(
              currentTopWeightKg: baseline.topWeightKg,
              bestRepsAtCurrentTopWeight: baseline.bestRepsAtTopWeight,
              weightKg: saved.weightKg,
              reps: saved.reps,
            );
      if (!mounted) return;
      _onSetChanged(exerciseId, setIdx, saved);
      await _refreshPrBaseline(exerciseId);
      if (prResult.isPersonalRecord && mounted) {
        HapticFeedback.heavyImpact();
        await showPrOverlay(
          context,
          exerciseName: entry.exercise.name,
          newWeightKg: saved.weightKg,
          reps: saved.reps,
          oldWeightKg: oldPrKg,
        );
      }
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

  void _removeSessionItem(int i) {
    setState(() {
      _sessionItems.removeAt(i);
      if (_currentItemIdx > i) _currentItemIdx--;
      _currentItemIdx = _currentItemIdx.clamp(0, (_sessionItems.length - 1).clamp(0, 999));
    });
    _saveProgress();
  }

  Future<void> _removeExerciseWithProgramChoice(int itemIdx) async {
    if (itemIdx < 0 || itemIdx >= _sessionItems.length) {
      return;
    }
    final si = _sessionItems[itemIdx];
    final wodItem = si.wodItem;
    if (wodItem is! StandaloneWodExercise) {
      return;
    }

    final templateExerciseId = wodItem.entry.templateExercise.id;
    final hasProgramEntry = !si.isAdHoc && templateExerciseId > 0;
    final choice = await _showProgramChangeScopeSheet(
      title: 'Remove ${wodItem.entry.exercise.name}?',
      message: hasProgramEntry
          ? 'Remove it only from this workout, or save the removal to the program so future sessions skip it too.'
          : 'This exercise was added only for this workout, so removing it will not change the program.',
      temporaryLabel: 'Just for this workout',
      temporaryIcon: Icons.delete_sweep_outlined,
      permanentLabel: 'Save to program permanently',
      permanentIcon: Icons.playlist_remove_rounded,
      permanentColor: Colors.red.shade300,
      showPermanent: hasProgramEntry,
    );
    if (!mounted || choice == null) {
      return;
    }

    final sessionItemId = si.id;
    if (choice == _ProgramChangeScope.permanent && hasProgramEntry) {
      await ref
          .read(databaseProvider)
          .programsDao
          .deleteWodTemplateExercise(templateExerciseId);
      ref.invalidate(nextWodProvider);
      ref.invalidate(allCurrentPhaseWodsProvider);
      if (!mounted) {
        return;
      }
    }
    final currentIndex = _sessionItems.indexWhere((item) => item.id == sessionItemId);
    if (currentIndex != -1) {
      _removeSessionItem(currentIndex);
    }
  }

  /// Removes a single exercise from a circuit (session-only). Removing the last
  /// remaining exercise removes the whole circuit item. Keeps the circuit cursor
  /// (`_circuitExerciseIdx`) consistent when the active circuit is edited.
  void _removeCircuitExercise(int itemIdx, int exIdx) {
    if (itemIdx < 0 || itemIdx >= _sessionItems.length) return;
    final si = _sessionItems[itemIdx];
    final circuit = si.wodItem;
    if (circuit is! WodCircuit) return;
    if (exIdx < 0 || exIdx >= circuit.exercises.length) return;

    // Removing the last remaining exercise removes the whole circuit item.
    if (circuit.exercises.length <= 1) {
      _removeSessionItem(itemIdx);
      return;
    }

    final newExercises = List<WodExerciseEntry>.from(circuit.exercises)..removeAt(exIdx);
    final newCircuit = WodCircuit(
      groupId: circuit.groupId, name: circuit.name, rounds: circuit.rounds,
      restBetweenExercisesSeconds: circuit.restBetweenExercisesSeconds,
      restBetweenRoundsSeconds: circuit.restBetweenRoundsSeconds,
      exercises: newExercises,
    );
    setState(() {
      si.wodItem = newCircuit;
      if (itemIdx == _currentItemIdx) {
        if (exIdx < _circuitExerciseIdx) _circuitExerciseIdx--;
        _circuitExerciseIdx = _circuitExerciseIdx.clamp(0, newExercises.length - 1);
      }
    });
    _saveProgress();
  }

  /// Removes an entire circuit item from this session (session-only).
  void _removeCircuit(int itemIdx) {
    if (itemIdx < 0 || itemIdx >= _sessionItems.length) return;
    if (_sessionItems[itemIdx].wodItem is! WodCircuit) return;
    _removeSessionItem(itemIdx);
  }

  // ── Action sheets ─────────────────────────────────────────────────────────────

  void _showExerciseActions(BuildContext context, int itemIdx) {
    final si = _sessionItems[itemIdx];
    final wodItem = si.wodItem;
    final standalone = wodItem is StandaloneWodExercise ? wodItem.entry : null;
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
            if (standalone != null)
              ActionTile(icon: Icons.notes_rounded, label: 'Notes',
                  onTap: () { Navigator.pop(ctx); _showExerciseNotesSheet(standalone); }),
            ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
                onTap: () { Navigator.pop(ctx); _showSwapExerciseSheet(itemIdx); }),
            ActionTile(icon: Icons.add, label: 'Add Exercise',
                onTap: () { Navigator.pop(ctx); _showAddExerciseSheet(itemIdx + 1); }),
            ActionTile(icon: Icons.skip_next, label: 'Skip Exercise',
                onTap: () { Navigator.pop(ctx); _skipExercise(itemIdx); }),
            if (wodItem is StandaloneWodExercise)
              ActionTile(icon: Icons.delete_outline, label: 'Remove', color: Colors.red.shade300,
                  onTap: () { Navigator.pop(ctx); _removeExerciseWithProgramChoice(itemIdx); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  void _showCircuitExerciseActions(BuildContext context, int itemIdx, int exIdx) {
    final circuit = _sessionItems[itemIdx].wodItem as WodCircuit;
    final entry = circuit.exercises[exIdx];
    final isLastInCircuit = circuit.exercises.length <= 1;
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
            ActionTile(icon: Icons.notes_rounded, label: 'Notes',
                onTap: () { Navigator.pop(ctx); _showExerciseNotesSheet(entry); }),
            ActionTile(icon: Icons.swap_horiz, label: 'Swap Exercise',
                onTap: () { Navigator.pop(ctx); _showSwapCircuitExerciseSheet(itemIdx, exIdx); }),
            ActionTile(
                icon: Icons.delete_outline,
                label: isLastInCircuit ? 'Remove (last · removes circuit)' : 'Remove from Circuit',
                color: Colors.red.shade300,
                onTap: () { Navigator.pop(ctx); _removeCircuitExercise(itemIdx, exIdx); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  void _showCircuitActions(BuildContext context, int itemIdx) {
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
            ActionTile(icon: Icons.add, label: 'Add Exercise',
                onTap: () { Navigator.pop(ctx); _showAddExerciseSheet(itemIdx + 1); }),
            ActionTile(icon: Icons.skip_next, label: 'Skip Circuit',
                onTap: () { Navigator.pop(ctx); _skipExercise(itemIdx); }),
            ActionTile(icon: Icons.delete_outline, label: 'Remove Circuit', color: Colors.red.shade300,
                onTap: () { Navigator.pop(ctx); _removeCircuit(itemIdx); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  void _showExerciseNotesSheet(WodExerciseEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseNotesSheet(
        exerciseId: entry.templateExercise.exerciseId,
        exerciseName: entry.exercise.name,
      ),
    );
  }

  // ── Swap exercise ─────────────────────────────────────────────────────────────

  void _showSwapExerciseSheet(int itemIdx) {
    final original = _sessionItems[itemIdx].wodItem;
    if (original is! StandaloneWodExercise) {
      _showSwapExercisePicker(null, null, onSwap: (e) => _swapExercise(itemIdx, e));
      return;
    }
    final entry = original.entry;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ExerciseSwapSheet(
        exerciseId: entry.templateExercise.exerciseId,
        exerciseName: entry.exercise.name,
        onVariationSelected: (exercise) {
          Navigator.pop(context);
          _swapExercise(itemIdx, exercise);
        },
        onOtherExercise: () {
          Navigator.pop(context);
          _showSwapExercisePicker(
            entry.templateExercise.exerciseId,
            entry.exercise.name,
            onSwap: (e) => _swapExercise(itemIdx, e),
          );
        },
      ),
    );
  }

  void _showSwapExercisePicker(
    int? originalExerciseId,
    String? originalExerciseName, {
    required void Function(Exercise) onSwap,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseLibrarySheet(
        title: 'Choose Swap Exercise',
        onSelected: (exercise) {
          Navigator.pop(context);
          if (originalExerciseId == null ||
              originalExerciseName == null ||
              exercise.id == originalExerciseId) {
            onSwap(exercise);
            return;
          }
          _showAddVariationPrompt(
            originalExerciseId,
            originalExerciseName,
            exercise,
            onSwap: onSwap,
          );
        },
      ),
    );
  }

  void _showAddVariationPrompt(
    int originalExerciseId,
    String originalExerciseName,
    Exercise exercise, {
    required void Function(Exercise) onSwap,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
              'Save as variation?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Save ${exercise.name} as a variation of '
              '$originalExerciseName so it appears as a quick swap next time.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Swap & Save Variation'),
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(databaseProvider)
                      .exerciseVariationsDao
                      .addVariation(originalExerciseId, exercise.id);
                  if (!mounted) {
                    return;
                  }
                  navigator.pop();
                  onSwap(exercise);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${exercise.name} saved as a variation of '
                        '$originalExerciseName',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                child: const Text('Swap once'),
                onPressed: () {
                  Navigator.pop(ctx);
                  onSwap(exercise);
                },
              ),
            ),
          ]),
        ),
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
    final circuit = _sessionItems[itemIdx].wodItem as WodCircuit;
    final entry = circuit.exercises[exIdx];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => ExerciseSwapSheet(
        exerciseId: entry.templateExercise.exerciseId,
        exerciseName: entry.exercise.name,
        onVariationSelected: (exercise) {
          Navigator.pop(context);
          _swapCircuitExercise(itemIdx, exIdx, exercise);
        },
        onOtherExercise: () {
          Navigator.pop(context);
          _showSwapExercisePicker(
            entry.templateExercise.exerciseId,
            entry.exercise.name,
            onSwap: (e) => _swapCircuitExercise(itemIdx, exIdx, e),
          );
        },
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
    final bestReps = pr != null && pr > 0
        ? await db.setsDao.getBestRepsAtWeight(exerciseId, pr)
        : 0;
    if (mounted) setState(() {
      _lastSets[exerciseId] = lastSets;
      _prData[exerciseId] = pr;
      if (bestReps > 0) {
        _prBestReps[exerciseId] = bestReps;
      } else {
        _prBestReps.remove(exerciseId);
      }
    });
  }

  Future<_ProgramChangeScope?> _showProgramChangeScopeSheet({
    required String title,
    required String message,
    required String temporaryLabel,
    required IconData temporaryIcon,
    required String permanentLabel,
    required IconData permanentIcon,
    Color? permanentColor,
    bool showPermanent = true,
  }) {
    return showModalBottomSheet<_ProgramChangeScope>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            ActionTile(
              icon: temporaryIcon,
              label: temporaryLabel,
              onTap: () => Navigator.pop(ctx, _ProgramChangeScope.temporary),
            ),
            if (showPermanent)
              ActionTile(
                icon: permanentIcon,
                label: permanentLabel,
                color: permanentColor,
                onTap: () => Navigator.pop(ctx, _ProgramChangeScope.permanent),
              ),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  String? _programOrderKeyForSessionItem(SessionItem item) {
    switch (item.wodItem) {
      case StandaloneWodExercise(:final entry):
        final id = entry.templateExercise.id;
        return !item.isAdHoc && id > 0 ? 'e:$id' : null;
      case WodCircuit(:final groupId):
        return groupId > 0 ? 'g:$groupId' : null;
    }
  }

  Future<WodTemplateExercise> _insertProgramExercise(
    int insertAt,
    Exercise exercise,
    int sets,
    int repMin,
    int repMax,
  ) async {
    final db = ref.read(databaseProvider);
    final id = await db.programsDao.insertWodTemplateExercise(
      WodTemplateExercisesCompanion(
        wodTemplateId: Value(widget.result.wodTemplate.id),
        exerciseId: Value(exercise.id),
        groupId: const Value(null),
        sortOrder: Value(insertAt + 1),
        targetSets: Value(sets),
        repRangeMin: Value(repMin),
        repRangeMax: Value(repMax),
      ),
    );
    return _moveProgramExerciseToSessionPosition(id, insertAt);
  }

  Future<WodTemplateExercise> _moveProgramExerciseToSessionPosition(
    int templateExerciseId,
    int insertAt,
  ) async {
    final db = ref.read(databaseProvider);
    final safeInsertAt = insertAt.clamp(0, _sessionItems.length).toInt();
    final standaloneExercises =
        await db.programsDao.getTemplateExercises(widget.result.wodTemplate.id);
    final groups = await db.programsDao.getGroupsForWod(widget.result.wodTemplate.id);
    final orderItems = <_ProgramOrderItem>[
      for (final exercise in standaloneExercises) _ProgramOrderItem.exercise(exercise),
      for (final group in groups) _ProgramOrderItem.group(group),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final newKey = 'e:$templateExerciseId';
    final newItemIndex = orderItems.indexWhere((item) => item.key == newKey);
    if (newItemIndex == -1) {
      throw StateError('Inserted exercise was not found in the WOD template.');
    }
    final newItem = orderItems.removeAt(newItemIndex);

    String? previousKey;
    for (int i = safeInsertAt - 1; i >= 0; i--) {
      previousKey = _programOrderKeyForSessionItem(_sessionItems[i]);
      if (previousKey != null) {
        break;
      }
    }

    String? nextKey;
    for (int i = safeInsertAt; i < _sessionItems.length; i++) {
      nextKey = _programOrderKeyForSessionItem(_sessionItems[i]);
      if (nextKey != null) {
        break;
      }
    }

    var targetIndex = orderItems.length;
    if (nextKey != null) {
      final nextIndex = orderItems.indexWhere((item) => item.key == nextKey);
      if (nextIndex != -1) {
        targetIndex = nextIndex;
      }
    } else if (previousKey != null) {
      final previousIndex = orderItems.indexWhere((item) => item.key == previousKey);
      if (previousIndex != -1) {
        targetIndex = previousIndex + 1;
      }
    } else {
      targetIndex = 0;
    }

    orderItems.insert(targetIndex, newItem);
    await _rewriteProgramOrder(orderItems);
    return (await db.programsDao.getTemplateExercises(widget.result.wodTemplate.id))
        .firstWhere((exercise) => exercise.id == templateExerciseId);
  }

  Future<void> _rewriteProgramOrder(List<_ProgramOrderItem> orderItems) async {
    final db = ref.read(databaseProvider);
    for (int i = 0; i < orderItems.length; i++) {
      final sortOrder = i + 1;
      final orderItem = orderItems[i];
      final exercise = orderItem.exercise;
      if (exercise != null) {
        if (exercise.sortOrder == sortOrder) {
          continue;
        }
        await db.programsDao.updateWodTemplateExercise(
          WodTemplateExercisesCompanion(
            id: Value(exercise.id),
            wodTemplateId: Value(exercise.wodTemplateId),
            exerciseId: Value(exercise.exerciseId),
            groupId: Value(exercise.groupId),
            sortOrder: Value(sortOrder),
            targetSets: Value(exercise.targetSets),
            repRangeMin: Value(exercise.repRangeMin),
            repRangeMax: Value(exercise.repRangeMax),
            notes: Value(exercise.notes),
            restSeconds: Value(exercise.restSeconds),
            restBetweenSetsSeconds: Value(exercise.restBetweenSetsSeconds),
            targetRpe: Value(exercise.targetRpe),
            videoUrl: Value(exercise.videoUrl),
          ),
        );
        continue;
      }

      final group = orderItem.group;
      if (group != null && group.sortOrder != sortOrder) {
        await db.programsDao.updateGroup(
          WodExerciseGroupsCompanion(
            id: Value(group.id),
            wodTemplateId: Value(group.wodTemplateId),
            sortOrder: Value(sortOrder),
            name: Value(group.name),
            rounds: Value(group.rounds),
            restBetweenExercisesSeconds: Value(group.restBetweenExercisesSeconds),
            restBetweenRoundsSeconds: Value(group.restBetweenRoundsSeconds),
          ),
        );
      }
    }
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
                _addExerciseWithProgramChoice(
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

  Future<void> _addExerciseWithProgramChoice(
    int insertAt,
    Exercise exercise,
    int sets,
    int repMin,
    int repMax,
  ) async {
    final choice = await _showProgramChangeScopeSheet(
      title: 'Add ${exercise.name}?',
      message: 'Add it only to this workout, or save it to the program so it appears in future sessions too.',
      temporaryLabel: 'Just for this workout',
      temporaryIcon: Icons.add_circle_outline_rounded,
      permanentLabel: 'Save to program permanently',
      permanentIcon: Icons.playlist_add_rounded,
    );
    if (!mounted || choice == null) {
      return;
    }

    if (choice == _ProgramChangeScope.temporary) {
      _insertAdHocExercise(insertAt, exercise, sets, repMin, repMax);
      return;
    }

    final templateExercise =
        await _insertProgramExercise(insertAt, exercise, sets, repMin, repMax);
    ref.invalidate(nextWodProvider);
    ref.invalidate(allCurrentPhaseWodsProvider);
    if (!mounted) {
      return;
    }
    _insertSessionExercise(insertAt, exercise, templateExercise, isAdHoc: false);
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
    _insertSessionExercise(insertAt, exercise, fakeTe, isAdHoc: true);
  }

  void _insertSessionExercise(
    int insertAt,
    Exercise exercise,
    WodTemplateExercise templateExercise, {
    required bool isAdHoc,
  }) {
    final entry = WodExerciseEntry(
      templateExercise: templateExercise, exercise: exercise, suggestion: WeightSuggestion.noHistory,
    );
    final si = SessionItem(id: _nextItemId++, wodItem: StandaloneWodExercise(entry: entry, restSeconds: null), isAdHoc: isAdHoc);
    final safeInsertAt = insertAt.clamp(0, _sessionItems.length).toInt();
    setState(() {
      _sessionItems.insert(safeInsertAt, si);
      _setData[exercise.id] = List.generate(templateExercise.targetSets, (_) => SetData(weightKg: 0, reps: 0));
      _lastSets[exercise.id] = [];
      _prData[exercise.id] = null;
      if (_allExercisesDone) {
        // All previous exercises were finished — make the new item active.
        _currentItemIdx = safeInsertAt;
        _currentSetIdx = 0;
        _allExercisesDone = false;
      } else if (safeInsertAt < _currentItemIdx) {
        // Inserting before the current item shifts it forward.
        _currentItemIdx++;
      }
      // insertAt >= _currentItemIdx and not all done → new item is upcoming,
      // current item stays active (user will reach it naturally).
    });
    _loadExerciseHistory(exercise.id);
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
        actions: [
          TextButton.icon(
            onPressed: _saving || _loading ? null : _reviewAndFinish,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.flag_outlined, size: 20),
            label: const Text('Finish'),
          ),
          const SizedBox(width: 4),
        ],
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
                        onShowCircuitActions: () => _showCircuitActions(context, itemIdx),
                        onShowExerciseActions: (exIdx) => _showCircuitExerciseActions(context, itemIdx, exIdx),
                        onEditRound: (exIdx, round) => _editCircuitRound(context, itemIdx, exIdx, round),
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

class _EditSetSheet extends StatefulWidget {
  final String title;
  final String exerciseName;
  final bool isTimed;
  final SetData current;

  const _EditSetSheet({
    required this.title,
    required this.exerciseName,
    required this.isTimed,
    required this.current,
  });

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late final TextEditingController weightCtrl;
  late final TextEditingController secondaryCtrl;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    weightCtrl = TextEditingController(text: current.weightKg > 0 ? fmtW(current.weightKg) : '');
    secondaryCtrl = TextEditingController(
        text: widget.isTimed
            ? (current.durationSeconds > 0 ? '${current.durationSeconds}' : '')
            : (current.reps > 0 ? '${current.reps}' : ''));
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    secondaryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final isTimed = widget.isTimed;
    final current = widget.current;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1e2030),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(widget.exerciseName, style: const TextStyle(fontSize: 12, color: Colors.white54)),
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
    );
  }
}
