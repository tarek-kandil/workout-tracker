import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Static colour blob background that gives BackdropFilter something to blur.
/// No animation — keeps the UI calm and consistent with Option B (clean/minimal).
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -60,
          child: _Blob(color: cs.primary, opacity: 0.18, size: 320),
        ),
        Positioned(
          top: 240,
          left: -80,
          child: _Blob(color: cs.secondary, opacity: 0.12, size: 260),
        ),
        Positioned(
          bottom: 100,
          right: 40,
          child: _Blob(color: cs.primary, opacity: 0.10, size: 240),
        ),
      ],
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
