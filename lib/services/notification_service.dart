import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _androidSmallIcon = 'ic_stat_notify';

  // Supplement & Flash Workout reminders channel (v2 ensures sound/vibration
  // and heads-up Importance.max on upgraded installs — Android channels are
  // immutable once created).
  static const _channelId = 'supplement_and_workout_reminders';
  static const _channelName = 'Reminders';
  static const _channelDesc =
      'Scheduled reminders for your supplements and flash workouts';

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.reminder,
    icon: _androidSmallIcon,
  );

  // Live workout status notification
  static const _workoutChannelId = 'workout_session';
  static const _workoutChannelName = 'Active Workout';
  static const _workoutNotifId = 2001;

  // Weigh-in reminders channel
  static const _weighInChannelId = 'weigh_in_reminders_v2';
  static const _weighInChannelName = 'Weigh-in Reminders';
  static const _weighInChannelDesc =
      'Reminders to log a new body weight for your weight goal plan';
  static const weighInReminderId = 3001;

  static const _weighInAndroidDetails = AndroidNotificationDetails(
    _weighInChannelId,
    _weighInChannelName,
    channelDescription: _weighInChannelDesc,
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.reminder,
    icon: _androidSmallIcon,
  );

  static const _darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
  );

  static const _defaultDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _darwinDetails,
    macOS: _darwinDetails,
  );

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(resolveLocalLocationFor(DateTime.now()));

    const android = AndroidInitializationSettings(_androidSmallIcon);
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _initialized = true;

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _weighInChannelId,
          _weighInChannelName,
          description: _weighInChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _workoutChannelId,
          _workoutChannelName,
          description: 'Live workout progress',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidImpl.requestNotificationsPermission();
    }
  }

  /// Ensures OS-level notification (and, if needed, exact-alarm) permissions
  /// are requested when the user actively enables or saves a reminder.
  /// Returns `true` if notifications are enabled (or unknown), `false` if the
  /// user has explicitly blocked notifications in OS settings.
  static Future<bool> ensurePermissions({bool requestExactIfNeeded = true}) async {
    try {
      if (!_initialized) {
        await init();
      }
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        var enabled = await androidImpl.areNotificationsEnabled();
        if (enabled == false) {
          enabled = await androidImpl.requestNotificationsPermission();
        }
        if (requestExactIfNeeded) {
          final canExact =
              await androidImpl.canScheduleExactNotifications() ?? false;
          if (!canExact) {
            await androidImpl.requestExactAlarmsPermission();
          }
        }
        return enabled ?? true;
      }

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('NotificationService.ensurePermissions failed: $e');
      return true;
    }
  }

  /// Resolves the best-matching IANA [tz.Location] for [sample] using both UTC
  /// offset and timezone abbreviation (e.g. `'CET'`/`'CEST'` → `'Europe/...'`
  /// rather than falling back to a non-DST zone like `'Africa/Algiers'`).
  @visibleForTesting
  static tz.Location resolveLocalLocationFor(DateTime sample) {
    final offsetMs = sample.timeZoneOffset.inMilliseconds;
    final sampleMs = sample.millisecondsSinceEpoch;
    final tzName = sample.timeZoneName;

    // 1. Direct IANA name match (if platform exposes e.g. 'Europe/Berlin')
    final direct = tz.timeZoneDatabase.locations[tzName];
    if (direct != null) return direct;

    const preferredPrefixes = [
      'Europe/',
      'America/',
      'Asia/',
      'Australia/',
      'Pacific/',
      'Africa/',
    ];

    tz.Location? preferredAbbrevMatch;
    tz.Location? anyAbbrevMatch;
    tz.Location? offsetFallback;

    for (final loc in tz.timeZoneDatabase.locations.values) {
      final zone = loc.timeZone(sampleMs);
      if (zone.offset != offsetMs) continue;
      offsetFallback ??= loc;

      if (zone.abbreviation == tzName || loc.name.contains(tzName)) {
        anyAbbrevMatch ??= loc;
        if (preferredAbbrevMatch == null &&
            preferredPrefixes.any((p) => loc.name.startsWith(p))) {
          preferredAbbrevMatch = loc;
          break;
        }
      }
    }

    return preferredAbbrevMatch ?? anyAbbrevMatch ?? offsetFallback ?? tz.UTC;
  }

  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    final canExact = await androidImpl.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Returns null on success, or an error string on failure.
  static Future<String?> scheduleDailyReminder({
    required int id,
    required String title,
    required int hour,
    required int minute,
    String body = 'Daily reminder',
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      // Refresh local timezone in case the user traveled since app launch.
      tz.setLocalLocation(resolveLocalLocationFor(DateTime.now()));
      final scheduled = _nextInstanceOfTime(hour, minute);
      final mode = await _resolveAndroidScheduleMode();
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _defaultDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return null; // success
    } catch (e) {
      debugPrint('NotificationService.scheduleDailyReminder($id) failed: $e');
      return e.toString();
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('NotificationService.cancelReminder failed: $e');
    }
  }

  static const _flashReminderBaseId = 10000;
  static const _weekdayStride = 10;

  static int flashWorkoutReminderId(int wodId) => _flashReminderBaseId + wodId;

  /// Formats a weekday bitmask (bit 0 = Mon … bit 6 = Sun) + time as a human label.
  static String formatReminderSchedule(int? daysMask, int hour, int minute) {
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final mask = (daysMask == null || daysMask == 0) ? 0x7F : (daysMask & 0x7F);
    if (mask == 0x7F) return 'Daily at $timeStr';
    if (mask == 0x1F) return 'Weekdays at $timeStr';
    if (mask == 0x60) return 'Weekends at $timeStr';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final parts = <String>[];
    for (int i = 0; i < 7; i++) {
      if ((mask & (1 << i)) != 0) parts.add(names[i]);
    }
    return '${parts.join(', ')} at $timeStr';
  }

  /// Builds a concise subtitle for a supplement reminder notification.
  static String formatSupplementReminderBody({String? dose, String? timing}) {
    final parts = <String>[
      if (dose != null && dose.trim().isNotEmpty) dose.trim(),
      if (timing != null && timing.trim().isNotEmpty) timing.trim(),
    ];
    return parts.isEmpty ? 'Time to take your supplement' : parts.join(' · ');
  }

  /// Schedules a daily or selected-weekdays reminder for [baseId].
  /// [daysMask] bit 0 = Monday (weekday 1) … bit 6 = Sunday (weekday 7).
  /// When [daysMask] is null, 0, or 0x7F (all 7 days), schedules a single daily alarm.
  static Future<String?> scheduleRecurringReminder({
    required int baseId,
    required String title,
    required int hour,
    required int minute,
    int? daysMask,
    String? body,
  }) async {
    await cancelRecurringReminder(baseId);
    final mask = (daysMask == null || daysMask == 0) ? 0x7F : (daysMask & 0x7F);
    if (mask == 0x7F) {
      return scheduleDailyReminder(
        id: baseId,
        title: title,
        hour: hour,
        minute: minute,
        body: body ?? 'Daily reminder',
      );
    }
    try {
      if (!_initialized) {
        await init();
      }
      tz.setLocalLocation(resolveLocalLocationFor(DateTime.now()));
      final mode = await _resolveAndroidScheduleMode();
      for (int i = 0; i < 7; i++) {
        if ((mask & (1 << i)) == 0) continue;
        final weekday = i + 1; // 1 = Monday … 7 = Sunday
        final scheduled = _nextInstanceOfWeekdayAndTime(weekday, hour, minute);
        await _plugin.zonedSchedule(
          baseId * _weekdayStride + weekday,
          title,
          body ?? 'Scheduled reminder',
          scheduled,
          _defaultDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return null;
    } catch (e) {
      debugPrint(
        'NotificationService.scheduleRecurringReminder($baseId) failed: $e',
      );
      return e.toString();
    }
  }

  static Future<void> cancelRecurringReminder(int baseId) async {
    try {
      await _plugin.cancel(baseId);
      for (int weekday = 1; weekday <= 7; weekday++) {
        await _plugin.cancel(baseId * _weekdayStride + weekday);
      }
    } catch (e) {
      debugPrint('NotificationService.cancelRecurringReminder failed: $e');
    }
  }

  static Future<String?> scheduleFlashWorkoutReminder({
    required int wodId,
    required String title,
    required int hour,
    required int minute,
    int? daysMask,
  }) =>
      scheduleRecurringReminder(
        baseId: flashWorkoutReminderId(wodId),
        title: title,
        hour: hour,
        minute: minute,
        daysMask: daysMask,
        body: 'Flash workout reminder',
      );

  static Future<void> cancelFlashWorkoutReminder(int wodId) =>
      cancelRecurringReminder(flashWorkoutReminderId(wodId));

  /// Re-registers all active supplement and flash workout reminders stored in
  /// SQLite. Called automatically on app startup so reminders survive APK
  /// updates, timezone shifts, or cleared plugin caches without requiring the
  /// user to open and re-save each item manually.
  static Future<void> rescheduleAllSavedReminders({
    required List<DailyTask> tasks,
    required List<WodTemplate> flashWorkouts,
  }) async {
    for (final task in tasks) {
      if (!task.isEnabled ||
          task.reminderHour == null ||
          task.reminderMinute == null) {
        await cancelRecurringReminder(task.id);
        continue;
      }
      await scheduleRecurringReminder(
        baseId: task.id,
        title: task.name,
        hour: task.reminderHour!,
        minute: task.reminderMinute!,
        daysMask: task.reminderDays,
        body: formatSupplementReminderBody(
          dose: task.dose,
          timing: task.timing,
        ),
      );
    }

    for (final wod in flashWorkouts) {
      if (wod.isArchived ||
          wod.reminderHour == null ||
          wod.reminderMinute == null) {
        await cancelFlashWorkoutReminder(wod.id);
        continue;
      }
      await scheduleFlashWorkoutReminder(
        wodId: wod.id,
        title: wod.name,
        hour: wod.reminderHour!,
        minute: wod.reminderMinute!,
        daysMask: wod.reminderDays,
      );
    }
  }

  /// Schedules the next weigh-in reminder as a rolling **one-shot**
  /// notification (not a repeating schedule) anchored at
  /// `anchorDate + intervalDays`.
  static Future<String?> scheduleNextWeighInReminder({
    required DateTime anchorDate,
    required int intervalDays,
    String title = 'Time for a quick weigh-in',
    String body = "Log today's weight to keep your plan accurate.",
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      tz.setLocalLocation(resolveLocalLocationFor(DateTime.now()));
      final due = anchorDate.add(Duration(days: intervalDays));
      final now = DateTime.now();
      // Overdue — nudge soon (1 hour) rather than scheduling in the past.
      final fireAt = due.isAfter(now) ? due : now.add(const Duration(hours: 1));
      final mode = await _resolveAndroidScheduleMode();

      await _plugin.zonedSchedule(
        weighInReminderId,
        title,
        body,
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: _weighInAndroidDetails,
          iOS: _darwinDetails,
          macOS: _darwinDetails,
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Never throws — cancelling a reminder is a best-effort no-op cleanup step.
  static Future<void> cancelWeighInReminder() async {
    try {
      await _plugin.cancel(weighInReminderId);
    } catch (e) {
      debugPrint('NotificationService.cancelWeighInReminder failed: $e');
    }
  }

  /// Shows (or updates) a persistent workout-status notification.
  /// [chronoMs] — epoch-ms from which the chronometer counts.
  /// [chronoCountDown] — true = count down to [chronoMs], false = count up from it.
  static Future<void> showWorkoutStatus({
    required String title,
    required String body,
    int? chronoMs,
    bool chronoCountDown = false,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      _workoutNotifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _workoutChannelId,
          _workoutChannelName,
          channelDescription: 'Live workout progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          playSound: false,
          enableVibration: false,
          icon: _androidSmallIcon,
          when: chronoMs,
          usesChronometer: chronoMs != null,
          chronometerCountDown: chronoCountDown,
          showWhen: chronoMs != null,
        ),
      ),
    );
  }

  static Future<void> cancelWorkoutStatus() =>
      _plugin.cancel(_workoutNotifId);

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayAndTime(
      int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
