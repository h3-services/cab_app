import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'notification_service.dart';

import 'notification_plugin.dart';

late BuildContext _appContext;

void setAppContext(BuildContext context) {
  _appContext = context;
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("[FCM] Background message: ${message.messageId}");
  await NotificationService.saveNotification(
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? '',
    message.data,
  );
  _showLocalNotification(message);
}

Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Foreground - save and show, don't navigate
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
    _navigateToNotifications();
  });
}

void _navigateToNotifications() {
  try {
    Navigator.of(_appContext).pushNamed('/notifications');
  } catch (e) {
    print('[FCM] Navigation error: $e');
  }
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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
