import 'dart:ui';
import 'package:flutter/material.dart';

/// A frosted-glass card container.
///
/// Uses ClipRRect (not ClipPath) so BackdropFilter sits inside a Positioned.fill
/// inside the Stack — this avoids the !semantics.parentDataDirty assertion that
/// fires when BackdropFilter children use SizedBox.expand() inside ClipPath
/// inside a SliverList.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color tintColor;
  final double blurSigma;
  final bool enableBlur;
  final EdgeInsets padding;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.tintColor = const Color(0x26000000),
    this.blurSigma = 18.0,
    this.enableBlur = true,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    // Shadow drawn outside the clip so it bleeds past the card edges
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000), // pure black 20%
              blurRadius: 24,
              spreadRadius: -4,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // ── 1. Blur — Positioned.fill avoids SizedBox.expand() sizing
              //    issues inside SliverList that trigger the parentDataDirty assert
              if (enableBlur)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: blurSigma, sigmaY: blurSigma),
                    child: const SizedBox.shrink(),
                  ),
                ),

              // ── 2. Tint overlay
              Positioned.fill(child: ColoredBox(color: tintColor)),

              // ── 3. Rim-light + content (sizes the Stack)
              _RimLight(
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Rim-light: gradient border via 0.8px nested padding ──────────────────────

class _RimLight extends StatelessWidget {
  final double borderRadius;
  final Widget child;

  const _RimLight({required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x5938BDF8), // Electric Sky 35% — top-left refraction catch
            Color(0x0CFFFFFF), // white 5%          — bottom-right fade
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.8),
        child: child,
      ),
    );
  }
}
