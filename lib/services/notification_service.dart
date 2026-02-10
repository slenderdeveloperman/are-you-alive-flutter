import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../repositories/notification_repository.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 1;
  static const Duration _inactivityDuration = Duration(hours: 30);

  Future<void> init() async {
    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Get the device's actual timezone dynamically (works worldwide)
    try {
      final deviceTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      debugPrint('Failed to get device timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request Android permissions
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // Request iOS permissions
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Reschedule notification when user taps it
    scheduleInactivityNotification();
  }

  Future<void> scheduleInactivityNotification() async {
    // Save timestamp FIRST - countdown should work even if notifications fail
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'lastActiveTimestamp',
      DateTime.now().millisecondsSinceEpoch,
    );

    var body = 'Open now to read your eulogy';
    try {
      body = await NotificationRepository().nextThirtyHourMessage();
    } catch (e) {
      debugPrint('Failed to load shuffled notification message: $e');
    }

    // Try to schedule notification (may fail due to permissions)
    try {
      // Cancel any existing notification
      await _notifications.cancel(_notificationId);

      // Schedule new notification
      final scheduledTime = tz.TZDateTime.now(
        tz.local,
      ).add(_inactivityDuration);

      await _notifications.zonedSchedule(
        _notificationId,
        'ARE YOU ALIVE?',
        body,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_channel',
            'Inactivity Notifications',
            channelDescription:
                'Notifications when you have not opened the app',
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
    } catch (e) {
      // Notification scheduling failed (permissions, etc.)
      // The countdown timer will still work since we saved the timestamp above
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelNotification() async {
    await _notifications.cancel(_notificationId);
  }
}
