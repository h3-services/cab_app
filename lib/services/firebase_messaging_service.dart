import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("[FCM] Background message: ${message.messageId}");
  _showLocalNotification(message);
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // Request notification permissions
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM] Foreground message: ${message.messageId}');
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  });
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Notifications from admin',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails details =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    details,
    payload: jsonEncode(message.data),
  );
}
