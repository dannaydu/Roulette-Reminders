import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum TodoNotificationScheduleResult {
  scheduled,
  scheduledInexact,
  permissionDenied,
  unsupported,
  pastDue,
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) {
      return;
    }

    tz_data.initializeTimeZones();
    await _setLocalTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
        appName: 'Todo',
        appUserModelId: 'com.example.todo',
        guid: 'a0aef2d0-d8f8-4d33-8fa0-6f8e967f3c7c',
      ),
    );

    await _notifications.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  Future<TodoNotificationScheduleResult> scheduleTodoDueNotification({
    required String todoId,
    required String todoText,
    required DateTime dueAt,
  }) async {
    if (kIsWeb) {
      return TodoNotificationScheduleResult.unsupported;
    }

    await initialize();
    await cancelTodoDueNotification(todoId);

    if (!dueAt.isAfter(DateTime.now())) {
      return TodoNotificationScheduleResult.pastDue;
    }

    final hasPermission = await requestNotificationPermissions();
    if (!hasPermission) {
      return TodoNotificationScheduleResult.permissionDenied;
    }

    var scheduleMode = await _androidScheduleMode();
    var result = scheduleMode == AndroidScheduleMode.exactAllowWhileIdle
        ? TodoNotificationScheduleResult.scheduled
        : TodoNotificationScheduleResult.scheduledInexact;

    try {
      await _schedule(
        todoId: todoId,
        todoText: todoText,
        dueAt: dueAt,
        scheduleMode: scheduleMode,
      );
      return result;
    } on PlatformException {
      if (scheduleMode != AndroidScheduleMode.exactAllowWhileIdle) {
        rethrow;
      }

      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      result = TodoNotificationScheduleResult.scheduledInexact;
      await _schedule(
        todoId: todoId,
        todoText: todoText,
        dueAt: dueAt,
        scheduleMode: scheduleMode,
      );
      return result;
    }
  }

  Future<void> cancelTodoDueNotification(String todoId) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await _notifications.cancel(id: _notificationIdForTodo(todoId));
  }

  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) {
      return false;
    }

    await initialize();
    var hasPermission = true;

    final androidPermission = await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidPermission != null) {
      hasPermission = hasPermission && androidPermission;
    }

    final iosPermission = await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (iosPermission != null) {
      hasPermission = hasPermission && iosPermission;
    }

    final macOSPermission = await _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (macOSPermission != null) {
      hasPermission = hasPermission && macOSPermission;
    }

    return hasPermission;
  }

  Future<void> _schedule({
    required String todoId,
    required String todoText,
    required DateTime dueAt,
    required AndroidScheduleMode scheduleMode,
  }) {
    return _notifications.zonedSchedule(
      id: _notificationIdForTodo(todoId),
      title: 'Todo due',
      body: todoText.isEmpty ? 'A todo is due now.' : todoText,
      scheduledDate: tz.TZDateTime.from(dueAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_due_reminders',
          'Todo due reminders',
          channelDescription: 'Reminder notifications for todo due dates.',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      payload: todoId,
    );
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final canScheduleExact = await androidPlugin
        .canScheduleExactNotifications();
    if (canScheduleExact != false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final exactAlarmPermission = await androidPlugin
        .requestExactAlarmsPermission();
    return exactAlarmPermission == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _setLocalTimeZone() async {
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }

  int _notificationIdForTodo(String todoId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in todoId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
