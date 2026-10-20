import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ---------------------------------------------------------------------------
// Notification service: local session reminders + FCM token handling
// ---------------------------------------------------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // Stream of FCM tokens (for sending to your backend if desired)
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();
  Stream<String> get tokenStream => _tokenController.stream;

  bool _initialized = false;

  // ── Initialise (call once from main / AuthGate after sign-in) ─────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Initialise timezone data for scheduled notifications
    tz.initializeTimeZones();

    // Android channel
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS / macOS
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // FCM
    FirebaseMessaging.onMessage.listen(_onFcmMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onFcmOpened);
    FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

    final token = await _fcm.getToken();
    if (token != null) _tokenController.add(token);
    _fcm.onTokenRefresh.listen((newToken) => _tokenController.add(newToken));

    // Request permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  // ── Schedule a local reminder for a session ───────────────────────────────
  /// [secondsFromNow] — delay before the reminder fires.
  /// [title] / [body] — notification content.
  /// [id] — unique notification id (used to cancel / update).
  Future<void> scheduleSessionReminder({
    required int id,
    required int secondsFromNow,
    required String title,
    required String body,
  }) async {
    final scheduled = tz.TZDateTime.now(tz.local)
        .add(Duration(seconds: secondsFromNow));

    const android = AndroidNotificationDetails(
      'session_reminder',
      'Session Reminder',
      channelDescription: 'Reminders for upcoming focus sessions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _local.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: android, iOS: darwin),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancel a previously scheduled reminder by id.
  Future<void> cancelReminder(int id) async {
    await _local.cancel(id);
  }

  /// Cancel all reminders.
  Future<void> cancelAllReminders() async {
    await _local.cancelAll();
  }

  // ── Internal handlers ─────────────────────────────────────────────────────
  void _onFcmMessage(RemoteMessage message) {
    // Foreground FCM message — show a local notification so the user sees it.
    _showLocal(
      id: 0,
      title: message.notification?.title ?? 'Focus Flow',
      body: message.notification?.body ?? '',
    );
  }

  void _onFcmOpened(RemoteMessage message) {
    // User tapped the notification — routing handled by AuthGate / nav logic.
  }

  void _onNotificationTapped(NotificationResponse details) {
    // User tapped a local reminder — nothing extra needed for now.
  }

  Future<void> _showLocal({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'session_reminder',
      'Session Reminder',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );
    await _local.show(id, title, body,
        const NotificationDetails(android: android, iOS: darwin));
  }
}

// ---------------------------------------------------------------------------
// Background FCM handler (must be a top-level function)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Keep lightweight — no UI work here.
}

// ---------------------------------------------------------------------------
// Convenience getters / setters for reminder state (persisted locally)
// ---------------------------------------------------------------------------
class ReminderPrefs {
  static const String _key = 'session_reminder_enabled';
  static const String _keySeconds = 'session_reminder_seconds';

  static Future<bool> isEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_key, value);
  }

  static Future<int> getSeconds() async {
    final prefs = await _prefs;
    return prefs.getInt(_keySeconds) ?? 60;
  }

  static Future<void> setSeconds(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_keySeconds, value);
  }

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();
}
