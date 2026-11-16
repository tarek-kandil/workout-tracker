import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shell_providers.dart';
import 'home/home_screen.dart';
import 'records/personal_records_screen.dart';
import 'settings/settings_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _prevIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    PersonalRecordsScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    (Icons.bolt_outlined, Icons.bolt_rounded, 'Today'),
    (Icons.show_chart_rounded, Icons.show_chart_rounded, 'Progress'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Hub'),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(shellIndexProvider);
    final goingForward = selectedIndex >= _prevIndex;

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(shellIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          transitionBuilder: (child, animation) => _PageFlipTransition(
            animation: animation,
            goingForward: goingForward,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey(selectedIndex),
            child: _screens[selectedIndex],
          ),
        ),
        bottomNavigationBar: _FloatingNavBar(
          selectedIndex: selectedIndex,
          navItems: _navItems,
          onTap: (index) {
            setState(() => _prevIndex = selectedIndex);
            ref.read(shellIndexProvider.notifier).state = index;
          },
        ),

      ),
    );
  }
}

// ─── Page flip transition ─────────────────────────────────────────────────────

class _PageFlipTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final bool goingForward;

  const _PageFlipTransition({
    required this.animation,
    required this.child,
    required this.goingForward,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, ch) {
        final t = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ).value;
        final angle = (1 - t) * (goingForward ? 0.35 : -0.35);
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0010)
          ..rotateY(angle);
        return Transform(
          transform: matrix,
          alignment: goingForward ? Alignment.centerRight : Alignment.centerLeft,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: ch),
        );
      },
      child: child,
    );
  }
}

// ─── Floating liquid-glass nav bar ────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, IconData, String)> navItems;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.navItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, max(bottomPad, 12) + 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 48,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final accent = Theme.of(context).colorScheme.primary;
                  final dimColor = Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.50);
                  final itemWidth = constraints.maxWidth / navItems.length;

                  return Stack(
                    children: [
                      // ── Smooth sliding soft-tinted pill (no layout thrashing) ─
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: selectedIndex * itemWidth,
                        width: itemWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                      // ── Fixed 3-column icons + micro-labels ───────────────
                      Row(
                        children: [
                          for (int i = 0; i < navItems.length; i++)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => onTap(i),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      selectedIndex == i
                                          ? navItems[i].$2
                                          : navItems[i].$1,
                                      size: 20,
                                      color: selectedIndex == i
                                          ? accent
                                          : dimColor,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      navItems[i].$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: selectedIndex == i
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: selectedIndex == i
                                            ? Colors.white
                                            : dimColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

