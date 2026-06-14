import 'dart:async';
import 'dart:math';
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
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _confettiCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  Timer? _autoTimer;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: const ElasticOutCurve(0.7));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _particles = List.generate(80, (_) => _Particle());
    _ctrl.forward();
    _confettiCtrl.forward();
    _autoTimer = Timer(const Duration(seconds: 3), widget.onDone);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    _confettiCtrl.dispose();
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
        child: Stack(
          children: [
            // Confetti layer
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (_, child) => CustomPaint(
                    painter: _ConfettiPainter(_particles, _confettiCtrl.value),
                  ),
                ),
              ),
            ),
            // Card
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: GestureDetector(
                  onTap: () {},
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
          ],
        ),
      ),
    );
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double angle;
  final double spin;

  _Particle()
      : x = Random().nextDouble(),
        y = -0.1 - Random().nextDouble() * 0.4,
        vx = (Random().nextDouble() - 0.5) * 0.5,
        vy = 0.5 + Random().nextDouble() * 0.8,
        color = const [
          Color(0xFFFFD700),
          Color(0xFF6366F1),
          Color(0xFFEC4899),
          Color(0xFF22D3EE),
          Color(0xFF4ADE80),
          Color(0xFFFF6B35),
        ][Random().nextInt(6)],
        size = 6 + Random().nextDouble() * 8,
        angle = Random().nextDouble() * pi * 2,
        spin = (Random().nextDouble() - 0.5) * 12;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final px = (p.x + p.vx * t) * size.width;
      final py = (p.y + p.vy * t) * size.height;
      if (py > size.height + 20) continue;
      final opacity = t < 0.7 ? 1.0 : 1.0 - ((t - 0.7) / 0.3);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.angle + p.spin * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
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
