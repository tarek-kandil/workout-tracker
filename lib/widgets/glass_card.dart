import 'package:flutter/material.dart';
import 'liquid_glass_container.dart';

/// Opinionated glass card surface. Wraps [LiquidGlassContainer] with
/// defaults that match Option B: neutral white tint, no primary-colour bleed.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? tintColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint = tintColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.78));
    return LiquidGlassContainer(
      borderRadius: borderRadius,
      tintColor: effectiveTint,
      blurSigma: 18,
      padding: padding,
      child: child,
    );
  }
}
