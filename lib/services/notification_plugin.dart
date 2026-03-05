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
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chola_cabs'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );
      const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
        'trip_notifications_v3',
        'Trip Notifications',
        description: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chola_cabs'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
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
          },
      );
      } catch (e) {
      }
  }
  static Future<void> showLocationCapturedNotification({
    required double latitude,
    required double longitude,
    required String source,
  }) async {
    try {
      // Audio is handled by notification channel configuration
      
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final notificationId = 1000 + (now.millisecondsSinceEpoch % 1000);
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'terminated_location_v2',
        'Location Updates',
        channelDescription: 'Location tracking notifications',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('chola_cabs'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
      );
      final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      await _notificationsPlugin.show(
        notificationId,
        '📍 Location Captured - $source',
        'Time: $timeStr | Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
        platformDetails,
      );
      debugPrint('[NotificationPlugin] ✅ Location notification shown (ID: $notificationId, Source: $source)');
    } catch (e) {
      }
  }
  // Backward compatibility
  static Future<void> showTerminatedLocationNotification({
    required double latitude,
    required double longitude,
  }) async {
    await showLocationCapturedNotification(
      latitude: latitude,
      longitude: longitude,
      source: 'Background',
    );
  }
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (title.isEmpty || title == 'Notification' || body.isEmpty) {
        return;
      }
      
      // Audio is handled by notification channel configuration
      
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'trip_notifications_v3',
        'Trip Notifications',
        channelDescription: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('chola_cabs'),
        enableVibration: true,
        enableLights: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        ticker: title,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      );
      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      } catch (e) {
      }
  }
  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      }
  }
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      }
  }
  // Test notification to verify notifications are working
  static Future<void> showTestNotification() async {
    try {
      // Audio is handled by notification channel configuration
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'terminated_location_v2',
        'Test Notification',
        channelDescription: 'Test notification to verify functionality',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('chola_cabs'),
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
      } catch (e) {
      }
  }
}
