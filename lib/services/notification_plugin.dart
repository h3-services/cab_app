import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationPlugin {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Create notification channels
      const AndroidNotificationChannel locationChannel = AndroidNotificationChannel(
        'location_tracking',
        'Location Tracking',
        description: 'Background location tracking for driver safety',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );
      
      const AndroidNotificationChannel terminatedChannel = AndroidNotificationChannel(
        'terminated_location',
        'Terminated State Location',
        description: 'Location updates when app is closed',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.createNotificationChannel(locationChannel);
      await androidPlugin?.createNotificationChannel(terminatedChannel);

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

  static Future<void> showTerminatedLocationNotification({
    required double latitude,
    required double longitude,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'terminated_location',
        'Terminated State Location',
        channelDescription: 'Location updates when app is closed',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      await _notificationsPlugin.show(
        999,
        'Chola Cabs - App Terminated',
        'Location captured at $timeStr\nLat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
        platformChannelSpecifics,
      );
      
      print('[NotificationPlugin] Terminated state notification shown');
    } catch (e) {
      print('[NotificationPlugin] Terminated notification error: $e');
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
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
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
      
      debugPrint('[NotificationPlugin] Notification shown: $title');
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