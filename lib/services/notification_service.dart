import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Daily task reminders channel
  static const _channelId = 'daily_tasks';
  static const _channelName = 'Daily Tasks';
  static const _channelDesc = 'Reminders for your daily health tasks';

  static const _androidDetails = AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  // Live workout status notification
  static const _workoutChannelId = 'workout_session';
  static const _workoutChannelName = 'Active Workout';
  static const _workoutNotifId = 2001;

  // Weigh-in reminders channel
  static const _weighInChannelId = 'weigh_in_reminders';
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
    icon: '@mipmap/ic_launcher',
  );

  static const _darwinDetails = DarwinNotificationDetails();
  static const _defaultDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _darwinDetails,
    macOS: _darwinDetails,
  );

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
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
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _weighInChannelId,
          _weighInChannelName,
          description: _weighInChannelDesc,
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          _workoutChannelId,
          _workoutChannelName,
          description: 'Live workout progress',
          importance: Importance.low,
        ),
      );
      await androidImpl.requestNotificationsPermission();
      final canExact = await androidImpl.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        await androidImpl.requestExactAlarmsPermission();
      }
    }
  }

  static tz.Location _resolveLocalLocation() {
    final now = DateTime.now();
    final offsetMs = now.timeZoneOffset.inMilliseconds;
    final nowMs = now.millisecondsSinceEpoch;
    tz.Location? fallback;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.timeZone(nowMs).offset == offsetMs) {
        fallback ??= loc;
        if (loc.name.contains(now.timeZoneName)) {
          return loc;
        }
      }
    }
    return fallback ?? tz.UTC;
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
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
      final scheduled = _nextInstanceOfTime(hour, minute);
      final mode = await _resolveAndroidScheduleMode();
      await _plugin.zonedSchedule(
        id,
        title,
        'Daily reminder',
        scheduled,
        _defaultDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return null; // success
    } catch (e) {
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

  /// Schedules a daily or selected-weekdays reminder for [baseId].
  /// [daysMask] bit 0 = Monday (weekday 1) … bit 6 = Sunday (weekday 7).
  /// When [daysMask] is null, 0, or 0x7F (all 7 days), schedules a single daily alarm.
  static Future<String?> scheduleRecurringReminder({
    required int baseId,
    required String title,
    required int hour,
    required int minute,
    int? daysMask,
  }) async {
    await cancelRecurringReminder(baseId);
    final mask = (daysMask == null || daysMask == 0) ? 0x7F : (daysMask & 0x7F);
    if (mask == 0x7F) {
      return scheduleDailyReminder(
        id: baseId,
        title: title,
        hour: hour,
        minute: minute,
      );
    }
    try {
      if (!_initialized) {
        await init();
      }
      final mode = await _resolveAndroidScheduleMode();
      for (int i = 0; i < 7; i++) {
        if ((mask & (1 << i)) == 0) continue;
        final weekday = i + 1; // 1 = Monday … 7 = Sunday
        final scheduled = _nextInstanceOfWeekdayAndTime(weekday, hour, minute);
        await _plugin.zonedSchedule(
          baseId * _weekdayStride + weekday,
          title,
          'Scheduled reminder',
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
      );

  static Future<void> cancelFlashWorkoutReminder(int wodId) =>
      cancelRecurringReminder(flashWorkoutReminderId(wodId));

  /// Schedules the next weigh-in reminder as a rolling **one-shot**
  /// notification (not a repeating schedule) anchored at
  /// `anchorDate + intervalDays`. Call this again after every weigh-in log
  /// or plan save/edit to roll the reminder forward — this file never
  /// re-derives the anchor itself.
  ///
  /// If the computed due date has already passed (the user is overdue),
  /// the reminder is scheduled a short time from now instead of in the
  /// past, so the user still gets nudged soon.
  ///
  /// Uses [AndroidScheduleMode.inexactAllowWhileIdle] — Android's exact-alarm
  /// APIs require special permission grants and battery-optimization
  /// exemptions we don't request for a "log your weight" nudge, so delivery
  /// may drift by up to ~15 minutes (acceptable for a daily/weekly cadence
  /// reminder like this one).
  static Future<String?> scheduleNextWeighInReminder({
    required DateTime anchorDate,
    required int intervalDays,
    String title = 'Time for a quick weigh-in',
    String body =
        "Log today's weight to keep your plan accurate.",
  }) async {
    try {
      if (!_initialized) {
        await init();
      }
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

  /// Never throws — cancelling a reminder is a best-effort no-op cleanup
  /// step (e.g. when a plan is deleted or reminders are disabled), and it
  /// is on the app-startup critical path via
  /// `WeightGoalActions.rescheduleReminder()`. Platform plugin channels can
  /// throw in edge cases (e.g. before the engine finishes attaching
  /// plugins), so swallow and log rather than letting startup hang.
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
          icon: '@mipmap/ic_launcher',
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
