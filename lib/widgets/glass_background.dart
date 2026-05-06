import 'package:flutter/material.dart';

/// Renders nothing — Option B uses a pure solid scaffold background.
/// Kept as a named widget so existing screen imports compile unchanged.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
