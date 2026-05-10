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
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color accentColor;
  final Color backgroundColor;
  final double itemExtent;
  final double height;

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
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
      _controller.animateToItem(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
              physics: const BouncingScrollPhysics(
                parent: FixedExtentScrollPhysics(),
              ),
              perspective: 0.003,
              diameterRatio: 2.5,
              onSelectedItemChanged: (index) {
                setState(() => _currentIndex = index);
                widget.onChanged(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, index) {
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
                    child: Text(widget.items[index], style: style),
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
