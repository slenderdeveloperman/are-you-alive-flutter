import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _notificationId = 1;
  static const Duration _inactivityDuration = Duration(hours: 39);

  Future<void> init() async {
    // Initialize timezone
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    // Request iOS permissions
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Reschedule notification when user taps it
    scheduleInactivityNotification();
  }

  Future<void> scheduleInactivityNotification() async {
    // Cancel any existing notification
    await _notifications.cancel(_notificationId);

    // Schedule new notification
    final scheduledTime = tz.TZDateTime.now(tz.local).add(_inactivityDuration);

    await _notifications.zonedSchedule(
      _notificationId,
      'ARE YOU ALIVE?',
      "We haven't heard from you in a while. Just checking in...",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inactivity_channel',
          'Inactivity Notifications',
          channelDescription: 'Notifications when you have not opened the app',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Save timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastActiveTimestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> cancelNotification() async {
    await _notifications.cancel(_notificationId);
  }
}
