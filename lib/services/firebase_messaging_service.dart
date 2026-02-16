import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'notification_service.dart';
import '../main.dart';
import 'notification_plugin.dart';
import 'audio_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("[FCM] Background/Terminated message: ${message.messageId}");
  
  try {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    
    await NotificationService.saveNotification(title, body);
    
    // Only show notification if Firebase didn't already show it (data-only messages)
    if (message.notification == null) {
      await NotificationPlugin.showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: jsonEncode(message.data),
      );
      print("[FCM] Background notification shown (data-only)");
    } else {
      print("[FCM] Background notification saved (Firebase auto-shown)");
    }
  } catch (e) {
    print("[FCM] Background handler error: $e");
  }
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Get and print FCM token
  final token = await messaging.getToken();
  print('[FCM] Device Token: $token');

  // Handle message when app is launched from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('[FCM] App launched from terminated state');
      _handleNotificationClick(message.data);
    }
  });

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Foreground - save, show notification, and play audio
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('[FCM] Foreground message: ${message.messageId}');
    print('[FCM] Notification: ${message.notification?.title}');
    
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    
    await NotificationService.saveNotification(title, body);
    
    // Show notification in foreground
    await NotificationPlugin.showNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
    
    // Play audio
    AudioService.playNotificationSound();
    
    print('[FCM] Foreground notification shown and audio playing');
  });

  // Background/Terminated - navigate when tapped
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('[FCM] Notification tapped: ${message.messageId}');
    _handleNotificationClick(message.data);
  });
}

void _handleNotificationClick(Map<String, dynamic> data) {
  print('[FCM] Handling notification click with data: $data');
  final type = data['type'] as String?;
  final navigator = navigatorKey.currentState;

  if (navigator == null) {
    print('[FCM] Navigator key is null, cannot navigate');
    return;
  }

  try {
    switch (type) {
      case 'TRIP_ASSIGNED':
        // Navigate to Trip Process (Active Trip)
        // Ensure we pass necessary data if the screen expects it
        // Or navigate to dashboard which handles active state check
        navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
        break;

      case 'REGISTRATION_REJECTED':
        // Navigate to Approval Pending (which handles rejection state)
        navigator.pushNamedAndRemoveUntil(
            '/approval-pending', (route) => false);
        break;

      case 'REGISTRATION_APPROVED':
        // Navigate to Dashboard when approved
        navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
        break;

      case 'TRIP_CREATED': // New Trip Available
      case 'TRIP_UNASSIGNED': // Trip was removed
      case 'TRIP_REJECTED': // Assigned to someone else
        // All these should land on Dashboard so driver can see list or status
        navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
        break;

      default:
        // Default to Notifications Screen
        navigator.pushNamed('/notifications');
        break;
    }
  } catch (e) {
    print('[FCM] Navigation error: $e');
  }
}
