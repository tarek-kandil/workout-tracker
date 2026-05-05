import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';

/// Animated color blob background that gives BackdropFilter something to blur.
class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final cs = Theme.of(context).colorScheme;
        return Stack(
          children: [
            Positioned(
              top: lerpDouble(-60, 20, t),
              right: lerpDouble(-40, 40, t),
              child: _Blob(color: cs.primary, opacity: 0.24, size: 280),
            ),
            Positioned(
              top: lerpDouble(200, 280, t),
              left: lerpDouble(-80, -20, t),
              child: _Blob(color: cs.secondary, opacity: 0.18, size: 240),
            ),
            Positioned(
              bottom: lerpDouble(60, 140, t),
              right: lerpDouble(20, 80, t),
              child: _Blob(color: cs.primary, opacity: 0.15, size: 220),
            ),
          ],
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;

  const _Blob({required this.color, required this.opacity, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
