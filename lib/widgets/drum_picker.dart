import 'package:flutter/material.dart';

class DrumPicker extends StatefulWidget {
  const DrumPicker({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.accentColor,
    required this.backgroundColor,
    this.itemExtent = 48,
    this.height = 160,
    this.looping = false,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color accentColor;
  final Color backgroundColor;
  final double itemExtent;
  final double height;
  final bool looping;

  @override
  State<DrumPicker> createState() => _DrumPickerState();
}

class _DrumPickerState extends State<DrumPicker> {
  late FixedExtentScrollController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _controller = FixedExtentScrollController(initialItem: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(DrumPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.items.length;
    final currentEffective = (widget.looping && n > 0)
        ? ((_currentIndex % n) + n) % n
        : _currentIndex;
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        widget.selectedIndex != currentEffective) {
      _currentIndex = widget.selectedIndex;
      _controller.animateToItem(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadeHeight = (widget.height - widget.itemExtent) / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        ),
        child: Stack(
          children: [
            ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemExtent,
              physics: const FixedExtentScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              perspective: 0.003,
              diameterRatio: 2.5,
              onSelectedItemChanged: (index) {
                final n = widget.items.length;
                if (n == 0) return;
                final effectiveIndex =
                    widget.looping ? ((index % n) + n) % n : index;
                setState(() => _currentIndex = index);
                widget.onChanged(effectiveIndex);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.looping ? null : widget.items.length,
                builder: (context, index) {
                  final n = widget.items.length;
                  if (n == 0) return const SizedBox.shrink();
                  if (!widget.looping && (index < 0 || index >= n)) {
                    return null;
                  }
                  final itemIndex =
                      widget.looping ? ((index % n) + n) % n : index;
                  final distance = (index - _currentIndex).abs();
                  final TextStyle style;
                  if (distance == 0) {
                    style = TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: widget.accentColor,
                    );
                  } else if (distance == 1) {
                    style = TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: widget.accentColor.withValues(alpha: 0.42),
                    );
                  } else {
                    style = TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.18),
                    );
                  }
                  return Center(
                    child: Text(widget.items[itemIndex], style: style),
                  );
                },
              ),
            ),
            IgnorePointer(
              child: Center(
                child: Container(
                  height: widget.itemExtent,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: widget.accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: fadeHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.backgroundColor,
                        widget.backgroundColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: fadeHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.backgroundColor.withValues(alpha: 0),
                        widget.backgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
