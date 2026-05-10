import 'package:flutter/material.dart';

/// Subtle ambient radial glow centred in the upper portion of the screen —
/// matches the Option B mockup. No blobs, no animation, no scroll artefacts.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlowPainter(primary),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color primary;
  const _GlowPainter(this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.28),
      width: size.width * 1.4,
      height: size.height * 0.55,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: 0.13),
          primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.primary != primary;
}
