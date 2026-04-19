import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shell_providers.dart';
import 'home/home_screen.dart';
import 'records/personal_records_screen.dart';
import 'settings/settings_screen.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    PersonalRecordsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(shellIndexProvider);

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(shellIndexProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        body: _screens[selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              ref.read(shellIndexProvider.notifier).state = index,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Records',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
