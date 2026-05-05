import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

/// Opinionated glass card surface. Wraps [LiquidGlassContainer] with
/// defaults derived from the current theme — no parameters needed for the
/// common case.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tintColor; // defaults to Theme primary at 8% opacity

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tintColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return LiquidGlassContainer(
      borderRadius: borderRadius,
      tintColor: effectiveTint,
      blurSigma: 18,
      padding: padding,
      child: child,
    );
  }
}
