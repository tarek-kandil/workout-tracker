import 'package:flutter/material.dart';

/// Text with a subtle gradient fill using BlendMode.srcIn.
/// srcIn clips the gradient to the text's alpha channel — no background
/// interaction, so contrast is always predictable and readable.
class VibrantText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color> gradientColors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final TextAlign? textAlign;

  const VibrantText(
    this.text, {
    super.key,
    required this.style,
    // Default: off-white — high contrast on any dark glass surface
    this.gradientColors = const [Color(0xF2F8FAFC), Color(0xCCF8FAFC)],
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn, // gradient fills the text glyph shape only
      shaderCallback: (bounds) => LinearGradient(
        begin: begin,
        end: end,
        colors: gradientColors,
      ).createShader(bounds),
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
        textAlign: textAlign,
      ),
    );
  }
}
