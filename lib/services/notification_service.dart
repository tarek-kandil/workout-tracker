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

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Returns null on success, or an error string on failure.
  static Future<String?> scheduleDailyReminder({
    required int id,
    required String title,
    required int hour,
    required int minute,
  }) async {
    try {
      final scheduled = _nextInstanceOfTime(hour, minute);
      await _plugin.zonedSchedule(
        id,
        title,
        'Daily reminder',
        scheduled,
        const NotificationDetails(android: _androidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }

  /// Fires an immediate notification — use to verify the pipeline works.
  static Future<String?> sendTestNotification(String title) async {
    try {
      await _plugin.show(
        99999,
        title,
        'Test notification — if you see this, notifications are working.',
        const NotificationDetails(android: _androidDetails),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> cancelReminder(int id) => _plugin.cancel(id);

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
      final due = anchorDate.add(Duration(days: intervalDays));
      final now = DateTime.now();
      // Overdue — nudge soon (1 hour) rather than scheduling in the past.
      final fireAt = due.isAfter(now) ? due : now.add(const Duration(hours: 1));

      await _plugin.zonedSchedule(
        weighInReminderId,
        title,
        body,
        tz.TZDateTime.from(fireAt.toUtc(), tz.UTC),
        const NotificationDetails(android: _weighInAndroidDetails),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
    final now = DateTime.now();

    // DateTime(y,m,d,h,min) creates a LOCAL datetime.
    // .toUtc() converts it correctly to UTC — no manual offset arithmetic needed.
    var local = DateTime(now.year, now.month, now.day, hour, minute);
    if (!local.isAfter(now)) {
      local = local.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(local.toUtc(), tz.UTC);
  }
}
