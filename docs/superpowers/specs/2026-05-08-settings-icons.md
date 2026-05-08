# Settings Screen — Icon Replacement

## Goal
Replace all emoji in the settings screen with Material icon widgets using the filled-rounded style, matching the fitness app aesthetic.

## Changes

Single file: `lib/screens/settings/settings_screen.dart`

### `_NavItem` model
- Rename field `emoji: String` → `icon: IconData`
- Update all four call sites

### Icon mapping
| Tile | Old | New |
|---|---|---|
| Programs | `'🏋️'` | `Icons.fitness_center` |
| Daily Tasks | `'✅'` | `Icons.task_alt` |
| History | `'📋'` | `Icons.history` |
| Exercises | `'📚'` | `Icons.menu_book` |
| Dark Mode | `'🌙'` | `Icons.dark_mode` |
| Danger / Clear | `'🗑️'` | `Icons.delete` |

### Tile rendering (`_NavGrid`)
Replace:
```dart
child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
```
With:
```dart
child: Icon(item.icon, size: 20, color: item.color),
```

### Appearance tile (`_AppearanceTile`)
Replace:
```dart
child: Text('🌙', style: TextStyle(fontSize: 17)),
```
With:
```dart
child: Icon(Icons.dark_mode, size: 20, color: const Color(0xFF6366F1)),
```

### Danger card (`_DangerCard`)
Replace:
```dart
child: Text('🗑️', style: TextStyle(fontSize: 18)),
```
With:
```dart
child: const Icon(Icons.delete, size: 20, color: Color(0xFFFF453A)),
```

## Out of Scope
- Changing icon choices (locked in above)
- Any other screen
- Any layout or color changes
