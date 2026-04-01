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
