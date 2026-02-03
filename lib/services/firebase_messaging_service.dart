import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'notification_service.dart';
import '../main.dart';
import 'notification_plugin.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("[FCM] Background message: ${message.messageId}");
  await NotificationService.saveNotification(
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    message.data,
  );
  // We can't navigate from background isolate, but we can show notification
  _showLocalNotification(message);
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Handle message when app is launched from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('[FCM] App launched from terminated state');
      _handleNotificationClick(message.data);
    }
  });

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Foreground - save and show, don't navigate automatically
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM] Foreground message: ${message.messageId}');
    if (message.notification != null) {
      NotificationService.saveNotification(
        message.notification!.title ?? 'Notification',
        message.notification!.body ?? '',
        message.data,
      );
      _showLocalNotification(message);
    }
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

Future<void> _showLocalNotification(RemoteMessage message) async {
  await NotificationPlugin.showNotification(
    id: message.hashCode,
    title: message.notification?.title ?? 'Notification',
    body: message.notification?.body ?? '',
    payload: jsonEncode(message.data),
  );
}
