import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CheckCircleButton extends StatefulWidget {
  final VoidCallback onDone;
  const CheckCircleButton({super.key, required this.onDone});

  @override
  State<CheckCircleButton> createState() => _CheckCircleButtonState();
}

class _CheckCircleButtonState extends State<CheckCircleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 420), vsync: this);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _tap() {
    if (_triggered) return;
    _triggered = true;
    HapticFeedback.mediumImpact();
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) widget.onDone();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final v = _ctrl.value;
            final fill = Curves.easeOutCubic.transform(v);
            final scale = 1.0 + 0.12 * sin(v * pi);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(Colors.transparent, Colors.green, fill),
                  border: Border.all(color: Color.lerp(Colors.white30, Colors.green, fill)!, width: 2.5),
                  boxShadow: v > 0.05 ? [BoxShadow(color: Colors.green.withValues(alpha: fill * 0.4), blurRadius: 14, spreadRadius: 2)] : null,
                ),
                child: Icon(Icons.check, color: Color.lerp(Colors.white30, Colors.white, fill), size: 28),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Opacity(
          opacity: (1.0 - _ctrl.value).clamp(0.0, 1.0),
          child: Text('Done Set', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38)),
        ),
      ),
    ]);
  }
}
