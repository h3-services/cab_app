import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:volume_controller/volume_controller.dart';
import 'location_audio_service.dart';

class NotificationPlugin {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Initialize audio service
      await LocationAudioService.initialize();
      
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
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      const AndroidNotificationChannel tripChannel = AndroidNotificationChannel(
        'trip_notifications_v3',
        'Trip Notifications',
        description: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
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

  static Future<void> showLocationCapturedNotification({
    required double latitude,
    required double longitude,
    required String source,
  }) async {
    try {
      // Play audio directly at max volume
      await LocationAudioService.playLocationSound();
      
      // Set volume to maximum for notification
      try {
        VolumeController().setVolume(1.0, showSystemUI: false);
        VolumeController().maxVolume();
      } catch (e) {
        debugPrint('[NotificationPlugin] Volume control error: $e');
      }

      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      // Use unique ID based on timestamp
      final notificationId = 1000 + (now.millisecondsSinceEpoch % 1000);
      
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'terminated_location_v2',
        'Location Updates',
        channelDescription: 'Location tracking notifications',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
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
      debugPrint('[NotificationPlugin] ❌ Location notification error: $e');
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
      // Don't show notification if title is empty or just "Notification"
      if (title.isEmpty || title == 'Notification' || body.isEmpty) {
        debugPrint('[NotificationPlugin] Skipping empty/default notification');
        return;
      }
      
      // Set volume to maximum for alarm stream
      try {
        VolumeController().setVolume(1.0, showSystemUI: false);
        VolumeController().maxVolume();
      } catch (e) {
        debugPrint('[NotificationPlugin] Volume control error: $e');
      }
      
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'trip_notifications_v3',
        'Trip Notifications',
        channelDescription: 'Notifications for new trips and trip updates',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        enableLights: true,
        ongoing: false,
        autoCancel: true,
        showWhen: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        ticker: title,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
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