import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationPlugin {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Create notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'location_tracking',
        'Location Tracking',
        description: 'Background location tracking for driver safety',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Initialize plugin
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      debugPrint('[NotificationPlugin] Initialized successfully');
    } catch (e) {
      debugPrint('[NotificationPlugin] Initialization error: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'location_tracking',
        'Location Tracking',
        channelDescription: 'Background location tracking for driver safety',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationPlugin] Show notification error: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('[NotificationPlugin] Cancel notification error: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationPlugin] Cancel all notifications error: $e');
    }
  }
}