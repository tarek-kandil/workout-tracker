import 'dart:math';
import 'package:flutter/animation.dart';

/// Exponential ease-out — fast start, very smooth deceleration.
/// Used for card entrance animations and container transitions.
class EaseOutExpo extends Curve {
  const EaseOutExpo();

  @override
  double transformInternal(double t) =>
      t == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t);
}

/// Snappy elastic-out — tighter overshoot than Curves.elasticOut.
/// Used for button press feedback and highlight pulses.
class SpringElastic extends Curve {
  const SpringElastic();

  @override
  double transformInternal(double t) {
    if (t == 0.0 || t == 1.0) return t;
    const period = 0.4;
    return pow(2.0, -10.0 * t) *
            sin((t - period / 4.0) * (2.0 * pi) / period) +
        1.0;
  }
}
