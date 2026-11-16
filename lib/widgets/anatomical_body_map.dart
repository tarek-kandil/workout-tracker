import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/weekly_muscle_volume.dart';
import 'anatomical_body_map_data.dart';

/// Parses an SVG path string containing `M`, `C`, and `Z` commands into a [ui.Path].
ui.Path parseAnatomicalSvgPath(String d) {
  final path = ui.Path();
  final tokens = RegExp(r'[MCZ]|[-+]?\d*\.?\d+').allMatches(d);
  String cmd = '';
  final nums = <double>[];

  void flush() {
    if (cmd == 'M' && nums.length >= 2) {
      path.moveTo(nums[0], nums[1]);
    } else if (cmd == 'C') {
      for (int i = 0; i + 5 < nums.length; i += 6) {
        path.cubicTo(
          nums[i],
          nums[i + 1],
          nums[i + 2],
          nums[i + 3],
          nums[i + 4],
          nums[i + 5],
        );
      }
    }
    nums.clear();
  }

  for (final m in tokens) {
    final t = m.group(0)!;
    if (t == 'M' || t == 'C') {
      flush();
      cmd = t;
    } else if (t == 'Z') {
      flush();
      path.close();
      cmd = '';
    } else {
      final v = double.tryParse(t);
      if (v != null) nums.add(v);
    }
  }
  flush();
  return path;
}

class _ParsedMuscleShape {
  final String id;
  final String muscle;
  final ui.Path path;
  const _ParsedMuscleShape({
    required this.id,
    required this.muscle,
    required this.path,
  });
}

class _CachedAnatomicalGeometry {
  static final ui.Path frontOutline =
      parseAnatomicalSvgPath(kAnatomicalFrontOutline);
  static final ui.Path backOutline =
      parseAnatomicalSvgPath(kAnatomicalBackOutline);

  static final List<_ParsedMuscleShape> frontMuscles = [
    for (final r in kAnatomicalFrontMuscles)
      _ParsedMuscleShape(
        id: r.id,
        muscle: r.muscle,
        path: parseAnatomicalSvgPath(r.d),
      ),
  ];

  static final List<_ParsedMuscleShape> backMuscles = [
    for (final r in kAnatomicalBackMuscles)
      _ParsedMuscleShape(
        id: r.id,
        muscle: r.muscle,
        path: parseAnatomicalSvgPath(r.d),
      ),
  ];
}

class AnatomicalBodyMap extends StatefulWidget {
  final List<WeeklyMuscleVolume> report;
  final String? selectedMuscle;
  final ValueChanged<String>? onMuscleSelected;

  const AnatomicalBodyMap({
    super.key,
    required this.report,
    this.selectedMuscle,
    this.onMuscleSelected,
  });

  @override
  State<AnatomicalBodyMap> createState() => _AnatomicalBodyMapState();
}

class _AnatomicalBodyMapState extends State<AnatomicalBodyMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  String? _internalSelected;

  String? get _activeSelection => widget.selectedMuscle ?? _internalSelected;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleSelect(String muscle) {
    setState(() => _internalSelected = muscle);
    widget.onMuscleSelected?.call(muscle);
  }

  @override
  Widget build(BuildContext context) {
    final byMuscle = {for (final r in widget.report) r.muscle: r};
    final selectedRow =
        _activeSelection != null ? byMuscle[_activeSelection] : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [Color(0xFF1B2036), Color(0xFF0E101B)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ANATOMICAL VOLUME MAP',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: Colors.white54,
                  ),
                ),
              ),
              _LegendDot(
                  color: const Color(0xFF10B981), label: 'Optimal'),
              const SizedBox(width: 8),
              _LegendDot(
                  color: const Color(0xFFF59E0B), label: 'Under'),
              const SizedBox(width: 8),
              _LegendDot(color: const Color(0xFFEF4444), label: 'Over'),
              const SizedBox(width: 8),
              _LegendDot(
                  color: const Color(0xFF475569), label: '0 sets'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: selectedRow != null
                ? Row(
                    children: [
                      Text(
                        selectedRow.muscle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_fmtSets(selectedRow.effectiveSets)} sets/rotation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _colorForRow(selectedRow),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'MEV ${selectedRow.landmark.mev.toInt()} · MRV ${selectedRow.landmark.mrv.toInt()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Tap any muscle belly to inspect planned sets vs MEV/MRV',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 290,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Row(
                  children: [
                    Expanded(
                      child: _FigurePane(
                        label: 'FRONT',
                        outline: _CachedAnatomicalGeometry.frontOutline,
                        muscles: _CachedAnatomicalGeometry.frontMuscles,
                        byMuscle: byMuscle,
                        selectedMuscle: _activeSelection,
                        pulseValue: _pulseCtrl.value,
                        onMuscleTap: _handleSelect,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FigurePane(
                        label: 'BACK',
                        outline: _CachedAnatomicalGeometry.backOutline,
                        muscles: _CachedAnatomicalGeometry.backMuscles,
                        byMuscle: byMuscle,
                        selectedMuscle: _activeSelection,
                        pulseValue: _pulseCtrl.value,
                        onMuscleTap: _handleSelect,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtSets(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static Color _colorForRow(WeeklyMuscleVolume row) {
    if (row.effectiveSets <= 0) return const Color(0xFF64748B);
    return switch (row.status) {
      MuscleVolumeStatus.optimal => const Color(0xFF34D399),
      MuscleVolumeStatus.undertrained => const Color(0xFFFBBF24),
      MuscleVolumeStatus.overtrained => const Color(0xFFF87171),
    };
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _FigurePane extends StatelessWidget {
  final String label;
  final ui.Path outline;
  final List<_ParsedMuscleShape> muscles;
  final Map<String, WeeklyMuscleVolume> byMuscle;
  final String? selectedMuscle;
  final double pulseValue;
  final ValueChanged<String> onMuscleTap;

  const _FigurePane({
    required this.label,
    required this.outline,
    required this.muscles,
    required this.byMuscle,
    required this.selectedMuscle,
    required this.pulseValue,
    required this.onMuscleTap,
  });

  // Model A coordinate bounding box: x in [170, 854] (width 684), y in [55, 1485] (height 1430)
  static const double _minX = 170;
  static const double _minY = 55;
  static const double _srcW = 684;
  static const double _srcH = 1430;

  Offset _toSourceCoords(Offset local, Size size) {
    final scale = (size.width / _srcW < size.height / _srcH)
        ? size.width / _srcW
        : size.height / _srcH;
    final dx = (size.width - _srcW * scale) / 2;
    final dy = (size.height - _srcH * scale) / 2;
    return Offset(
      (local.dx - dx) / scale + _minX,
      (local.dy - dy) / scale + _minY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final pt = _toSourceCoords(details.localPosition, size);
                  for (final m in muscles.reversed) {
                    if (m.path.contains(pt)) {
                      onMuscleTap(m.muscle);
                      break;
                    }
                  }
                },
                child: CustomPaint(
                  size: size,
                  painter: _BodyFigurePainter(
                    outline: outline,
                    muscles: muscles,
                    byMuscle: byMuscle,
                    selectedMuscle: selectedMuscle,
                    pulseValue: pulseValue,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BodyFigurePainter extends CustomPainter {
  final ui.Path outline;
  final List<_ParsedMuscleShape> muscles;
  final Map<String, WeeklyMuscleVolume> byMuscle;
  final String? selectedMuscle;
  final double pulseValue;

  const _BodyFigurePainter({
    required this.outline,
    required this.muscles,
    required this.byMuscle,
    required this.selectedMuscle,
    required this.pulseValue,
  });

  static const double _minX = 170;
  static const double _minY = 55;
  static const double _srcW = 684;
  static const double _srcH = 1430;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / _srcW < size.height / _srcH)
        ? size.width / _srcW
        : size.height / _srcH;
    final dx = (size.width - _srcW * scale) / 2;
    final dy = (size.height - _srcH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);
    canvas.translate(-_minX, -_minY);

    // 1. Body base silhouette
    final baseFill = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF181C2E);
    final baseStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF475569);

    canvas.drawPath(outline, baseFill);
    canvas.drawPath(outline, baseStroke);

    // 2. Individual anatomical muscle bellies
    final muscleBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;

    for (final m in muscles) {
      final row = byMuscle[m.muscle];
      final isSelected = selectedMuscle == m.muscle;

      Color fillColor;
      Color strokeColor;
      double alpha;

      if (row == null || row.effectiveSets <= 0) {
        fillColor = const Color(0xFF334155);
        strokeColor = const Color(0xFF1E293B);
        alpha = isSelected ? 0.85 : 0.55;
      } else {
        switch (row.status) {
          case MuscleVolumeStatus.optimal:
            fillColor = const Color(0xFF10B981);
            strokeColor = const Color(0xFF064E3B);
            alpha = 0.78 + 0.14 * pulseValue;
          case MuscleVolumeStatus.undertrained:
            fillColor = const Color(0xFFF59E0B);
            strokeColor = const Color(0xFF451A03);
            alpha = 0.78;
          case MuscleVolumeStatus.overtrained:
            fillColor = const Color(0xFFEF4444);
            strokeColor = const Color(0xFF450A0A);
            alpha = 0.82 + 0.14 * pulseValue;
        }
      }

      if (isSelected) {
        alpha = 1.0;
        strokeColor = Colors.white;
      }

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = fillColor.withValues(alpha: alpha);

      canvas.drawPath(m.path, fillPaint);
      muscleBorder
        ..color = strokeColor
        ..strokeWidth = isSelected ? 6.0 : 3.5;
      canvas.drawPath(m.path, muscleBorder);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyFigurePainter oldDelegate) =>
      oldDelegate.byMuscle != byMuscle ||
      oldDelegate.selectedMuscle != selectedMuscle ||
      oldDelegate.pulseValue != pulseValue;
}
