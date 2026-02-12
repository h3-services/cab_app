import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

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
        'terminated_location_v2',
        'Terminated State Location',
        description: 'Location updates when app is closed',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
      );

      const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
        'trip_notifications_v2',
        'Trip Notifications',
        description: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        vibrationPattern: null,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.createNotificationChannel(locationChannel);
      await androidPlugin?.createNotificationChannel(terminatedChannel);
      await androidPlugin?.createNotificationChannel(tripChannel);

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
        'terminated_location_v2',
        'Terminated State Location',
        channelDescription: 'Location updates when app is closed',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        ticker: 'Location captured in background',
        visibility: NotificationVisibility.public,
        fullScreenIntent: false,
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Use unique ID based on timestamp to avoid overwriting
      final notificationId = 999 + (now.millisecondsSinceEpoch % 1000);
      
      await _notificationsPlugin.show(
        notificationId,
        '📍 Chola Cabs - Location Update',
        'App closed - Location captured at $timeStr\nLat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
        platformChannelSpecifics,
      );
      
      print('[NotificationPlugin] ✅ Terminated state notification shown with ID: $notificationId');
    } catch (e) {
      print('[NotificationPlugin] ❌ Terminated notification error: $e');
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
        'trip_notifications_v2',
        'Trip Notifications',
        channelDescription: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        ticker: 'New notification',
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
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

  // Test notification to verify notifications are working
  static Future<void> showTestNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'terminated_location_v2',
        'Test Notification',
        channelDescription: 'Test notification to verify functionality',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _notificationsPlugin.show(
        888,
        '🔔 Test Notification',
        'This is a test notification to verify notifications are working',
        platformChannelSpecifics,
      );
      
      print('[NotificationPlugin] ✅ Test notification shown');
    } catch (e) {
      print('[NotificationPlugin] ❌ Test notification error: $e');
    }
  }
}