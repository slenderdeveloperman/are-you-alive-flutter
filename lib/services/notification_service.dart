import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/existence_record.dart';
import '../repositories/notification_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 1;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _refreshTimeZone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    try {
      var granted = true;

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        granted =
            await androidPlugin.requestNotificationsPermission() ?? false;
      }

      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        granted =
            await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return granted;
    } catch (e) {
      debugPrint('Failed to request notification permission: $e');
      return false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Opening the app must not mutate the filing timestamp. The next filing
    // action is the only thing allowed to move the 39-hour deadline.
  }

  /// Schedule the 30-hour local reminder relative to the canonical filing
  /// timestamp. This method never resets the filing timestamp itself.
  Future<bool> scheduleInactivityNotification({DateTime? from}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    DateTime? checkIn = from;
    final stored = prefs.getInt('lastActiveTimestamp');
    checkIn ??=
        stored == null ? null : DateTime.fromMillisecondsSinceEpoch(stored);
    if (checkIn == null) return false;

    final granted = await requestPermission();
    if (!granted) {
      await prefs.setBool('notificationsEnabled', false);
      return false;
    }
    await prefs.setBool('notificationsEnabled', true);

    var body =
        'No filing received for 30 hours. Continued existence requires confirmation.';
    try {
      body = await NotificationRepository().nextThirtyHourMessage();
    } catch (e) {
      debugPrint('Failed to load notification message: $e');
    }

    try {
      await _notifications.cancel(_notificationId);
      final scheduledTime = tz.TZDateTime.from(
        checkIn.add(ExistenceRecord.reminderAt),
        tz.local,
      );

      if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
        return false;
      }

      await _notifications.zonedSchedule(
        _notificationId,
        'F.C.C.D.B. / EXISTENCE REGISTER',
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_channel',
            'Existence register reminders',
            channelDescription: 'Reminders before your filing window lapses',
            importance: Importance.high,
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      return false;
    }
  }

  Future<void> _refreshTimeZone() async {
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));
    } catch (e) {
      debugPrint('Failed to get device timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> reconcileFromStoredFiling() async {
    await init();
    // A user may cross timezones while the process stays alive. Refresh the
    // zone before rebuilding the reminder so the displayed/local fire time
    // follows the device rather than the zone captured at process launch.
    await _refreshTimeZone();
    await scheduleInactivityNotification();
  }

  Future<void> cancelNotification() async {
    await _notifications.cancel(_notificationId);
  }
}
