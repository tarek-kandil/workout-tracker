import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared tab index — any widget can switch tabs by writing to this provider.
/// ShellScreen watches it instead of keeping its own _selectedIndex state.
final shellIndexProvider = StateProvider<int>((ref) => 0);
