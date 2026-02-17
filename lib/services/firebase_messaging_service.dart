import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final type = message.data['type'] as String?;
    
    await NotificationService.saveNotification(title, body);
    
    // Handle wallet deduction - check both type and title
    if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || type == 'WALLET_CREDIT' || 
        title.contains('Wallet Debited') || title.contains('Wallet Credited')) {
      await _handleWalletDeduction(message.data, body);
    }
    
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

Future<void> _handleWalletDeduction(Map<String, dynamic> data, String body) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Determine if it's credit or debit
    bool isCredit = body.contains('credited') || body.contains('added');
    bool isDebit = body.contains('debited') || body.contains('deducted');
    
    String? amountStr;
    String? newBalance;
    
    // Extract amount - works for both credit and debit
    final amountRegex = RegExp(r'(?:debited by|credited with|added|deducted) [₹\$]?\s*(\d+\.?\d*)');
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch != null) {
      amountStr = amountMatch.group(1);
    }
    
    // Extract new balance
    final balanceRegex = RegExp(r'balance is [₹\$]?\s*(\d+\.?\d*)');
    final balanceMatch = balanceRegex.firstMatch(body);
    if (balanceMatch != null) {
      newBalance = balanceMatch.group(1);
    }
    
    print('[FCM] Type: ${isCredit ? "Credit" : "Debit"}, Amount: $amountStr, Balance: $newBalance');
    
    if (amountStr != null && amountStr.isNotEmpty) {
      final now = DateTime.now();
      final transaction = {
        'title': isCredit ? 'Admin Credit' : 'Admin Deduction',
        'date': now.toString().split(' ')[0],
        'tripId': 'N/A',
        'transaction_id': '',
        'amount': '${isCredit ? "+" : "-"}₹$amountStr',
        'type': isCredit ? 'earning' : 'spending',
        'raw_date': now.toIso8601String(),
        'reason': isCredit ? 'Wallet Credited' : 'Wallet Debited',
      };
      
      final transactions = prefs.getStringList('admin_transactions') ?? [];
      transactions.insert(0, jsonEncode(transaction));
      await prefs.setStringList('admin_transactions', transactions);
      print('[FCM] Admin transaction saved: ${isCredit ? "+" : "-"}₹$amountStr');
      
      // Update cached wallet balance
      if (newBalance != null) {
        final cachedData = prefs.getString('driver_data');
        if (cachedData != null) {
          final driverData = jsonDecode(cachedData);
          driverData['wallet_balance'] = newBalance;
          await prefs.setString('driver_data', jsonEncode(driverData));
          print('[FCM] Cached balance updated to: ₹$newBalance');
        }
      }
    }
  } catch (e) {
    print('[FCM] Error handling wallet transaction: $e');
  }
}
