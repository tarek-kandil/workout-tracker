import 'dart:async';
import 'package:flutter/material.dart';

/// Brief green checkmark that pops and fades — for task completion.
void showTaskDoneFlash(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TaskDoneFlash(onRemove: () {
      if (entry.mounted) entry.remove();
    }),
  );
  overlay.insert(entry);
}

/// Full-screen celebration overlay — for finishing a workout.
/// Returns when the overlay has dismissed itself (caller can then pop the route).
Future<void> showWorkoutCompleteOverlay(
    BuildContext context, String wodName) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _WorkoutCompleteOverlay(
      wodName: wodName,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

// ─── Task done flash ───────────────────────────────────────────────────────────

class _TaskDoneFlash extends StatefulWidget {
  final VoidCallback onRemove;
  const _TaskDoneFlash({required this.onRemove});

  @override
  State<_TaskDoneFlash> createState() => _TaskDoneFlashState();
}

class _TaskDoneFlashState extends State<_TaskDoneFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // Scale: pop up with slight overshoot, then settle
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
    ]).animate(_ctrl);

    // Opacity: fully visible then fade out at the end
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 80),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
    ]).animate(_ctrl);

    _ctrl.forward().whenComplete(widget.onRemove);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PR overlay ───────────────────────────────────────────────────────────────

/// Animated overlay card shown when a new personal record is logged.
/// Returns when the overlay has dismissed itself (tap or 3-second auto-dismiss).
Future<void> showPrOverlay(
  BuildContext context, {
  required String exerciseName,
  required double newWeightKg,
  required int reps,
  double? oldWeightKg,
}) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PrOverlay(
      exerciseName: exerciseName,
      newWeightKg: newWeightKg,
      reps: reps,
      oldWeightKg: oldWeightKg,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _PrOverlay extends StatefulWidget {
  final String exerciseName;
  final double newWeightKg;
  final int reps;
  final double? oldWeightKg;
  final VoidCallback onDone;
  const _PrOverlay({
    required this.exerciseName,
    required this.newWeightKg,
    required this.reps,
    required this.oldWeightKg,
    required this.onDone,
  });
  @override
  State<_PrOverlay> createState() => _PrOverlayState();
}

class _PrOverlayState extends State<_PrOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: const ElasticOutCurve(0.7));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _autoTimer = Timer(const Duration(seconds: 3), widget.onDone);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtW(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final delta = widget.oldWeightKg != null && widget.oldWeightKg! > 0
        ? widget.newWeightKg - widget.oldWeightKg!
        : null;

    return GestureDetector(
      onTap: widget.onDone,
      child: AnimatedBuilder(
        animation: _fade,
        builder: (_, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.72 * _fade.value),
          child: child,
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: GestureDetector(
              onTap: () {}, // absorb taps on card so backdrop tap still works
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1e1b4b), Color(0xFF1a1a2e)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFBBF24).withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 36, decoration: TextDecoration.none)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'NEW PR!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD700),
                        letterSpacing: 0.05,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmtW(widget.newWeightKg)} kg',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (delta != null && delta > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '↑ +${_fmtW(delta)} kg from ${_fmtW(widget.oldWeightKg!)} kg',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.45),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${widget.exerciseName} · ${widget.reps} reps',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: widget.onDone,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Crush it! 💪',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Workout complete overlay ──────────────────────────────────────────────────

class _WorkoutCompleteOverlay extends StatefulWidget {
  final String wodName;
  final VoidCallback onDone;
  const _WorkoutCompleteOverlay(
      {required this.wodName, required this.onDone});

  @override
  State<_WorkoutCompleteOverlay> createState() =>
      _WorkoutCompleteOverlayState();
}

class _WorkoutCompleteOverlayState extends State<_WorkoutCompleteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _fade,
        builder: (_, child) => ColoredBox(
          color: Colors.black.withValues(alpha: 0.78 * _fade.value),
          child: child,
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.5),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 64),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Workout Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.wodName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
