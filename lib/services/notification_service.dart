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
