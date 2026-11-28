import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workout_tracker/database/app_database.dart';
import 'package:workout_tracker/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool canExact = true;
  bool notificationsEnabled = true;

  setUpAll(() {
    tz.initializeTimeZones();
  });

  setUp(() {
    calls.clear();
    canExact = true;
    notificationsEnabled = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'createNotificationChannel':
        case 'zonedSchedule':
        case 'cancel':
        case 'show':
          return null;
        case 'requestNotificationsPermission':
          return notificationsEnabled;
        case 'areNotificationsEnabled':
          return notificationsEnabled;
        case 'canScheduleExactNotifications':
          return canExact;
        case 'requestExactAlarmsPermission':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('resolveLocalLocationFor prefers regional DST-aware zone over raw offset fallback', () {
    final loc = NotificationService.resolveLocalLocationFor(DateTime.now());
    expect(loc.name, isNotEmpty);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    expect(
      loc.timeZone(nowMs).offset,
      DateTime.now().timeZoneOffset.inMilliseconds,
    );
  });

  test('scheduleRecurringReminder & rescheduleAllSavedReminders register valid ic_stat_notify payloads and cancel paused/archived items', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final creatineId = await db.dailyTasksDao.insertTask(
      DailyTasksCompanion.insert(
        name: 'Creatine',
        dose: const Value('5g'),
        timing: const Value('Morning'),
        reminderHour: const Value(8),
        reminderMinute: const Value(30),
        reminderDays: const Value(0x7F),
      ),
    );
    final pausedId = await db.dailyTasksDao.insertTask(
      DailyTasksCompanion.insert(
        name: 'Magnesium',
        isEnabled: const Value(false),
        reminderHour: const Value(21),
        reminderMinute: const Value(0),
      ),
    );
    final flashId = await db.programsDao.insertWodTemplate(
      WodTemplatesCompanion.insert(
        phaseId: const Value(null),
        wodNumber: 0,
        name: '10-Min Core',
        reminderHour: const Value(18),
        reminderMinute: const Value(15),
        reminderDays: const Value(0x05), // Mon & Wed (weekday 1 & 3)
      ),
    );

    final tasks = await db.dailyTasksDao.getAllTasks();
    final flashWorkouts = await db.programsDao.getFlashWorkouts();

    await NotificationService.rescheduleAllSavedReminders(
      tasks: tasks,
      flashWorkouts: flashWorkouts,
    );

    final scheduledCalls =
        calls.where((c) => c.method == 'zonedSchedule').toList();
    // 1 daily alarm for Creatine + 2 weekly alarms (Mon & Wed) for 10-Min Core = 3
    expect(scheduledCalls, hasLength(3));

    final creatineArgs = Map<String, dynamic>.from(
      scheduledCalls.first.arguments as Map,
    );
    expect(creatineArgs['id'], creatineId);
    expect(creatineArgs['title'], 'Creatine');
    expect(creatineArgs['body'], '5g · Morning');
    final platformSpec =
        Map<String, dynamic>.from(creatineArgs['platformSpecifics'] as Map);
    expect(platformSpec['icon'], 'ic_stat_notify');
    expect(platformSpec['channelId'], 'supplement_and_workout_reminders');

    final flashScheduledIds = scheduledCalls
        .skip(1)
        .map((c) => (c.arguments as Map)['id'] as int)
        .toList();
    final expectedBase = NotificationService.flashWorkoutReminderId(flashId);
    expect(flashScheduledIds, equals([expectedBase * 10 + 1, expectedBase * 10 + 3]));

    // Paused Magnesium was cancelled and never scheduled
    expect(
      scheduledCalls.any((c) => (c.arguments as Map)['id'] == pausedId),
      isFalse,
    );
    expect(
      calls.any((c) =>
          c.method == 'cancel' && (c.arguments as Map)['id'] == pausedId),
      isTrue,
    );
  });
}
