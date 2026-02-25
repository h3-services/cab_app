import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'notification_service.dart';
import '../main.dart';
import 'notification_plugin.dart';
import 'audio_service.dart';

// Global stream controller for wallet updates
final StreamController<bool> walletUpdateController = StreamController<bool>.broadcast();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("[FCM] Background/Terminated message: ${message.messageId}");
  
  try {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    
    await NotificationService.saveNotification(title, body);
    
    // Handle wallet transactions in background
    final type = message.data['type'] as String?;
    if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || type == 'WALLET_CREDIT' || 
        title.contains('Wallet Debited') || title.contains('Wallet Credited')) {
      await _handleWalletDeduction(message.data, body);
    }
    
    // Play audio ONCE in background/terminated state
    try {
      await AudioService.playNotificationSound();
      // Stop after 3 seconds to ensure it doesn't loop
      Future.delayed(const Duration(seconds: 3), () {
        AudioService.stopSound();
      });
      print("[FCM] Background audio played");
    } catch (e) {
      print("[FCM] Background audio error: $e");
    }
    
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
    
    // Play audio ONCE before showing notification
    try {
      await AudioService.playNotificationSound();
      // Stop after 3 seconds to ensure it doesn't loop
      Future.delayed(const Duration(seconds: 3), () {
        AudioService.stopSound();
      });
      print('[FCM] Foreground audio played');
    } catch (e) {
      print('[FCM] Foreground audio error: $e');
    }
    
    // Show notification in foreground
    await NotificationPlugin.showNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
    
    print('[FCM] Foreground notification shown');
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
    final driverId = prefs.getString('driverId');
    
    if (driverId == null) {
      print('[FCM] No driverId found, skipping wallet transaction');
      return;
    }
    
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
      
      final transactions = prefs.getStringList('admin_transactions_$driverId') ?? [];
      transactions.insert(0, jsonEncode(transaction));
      await prefs.setStringList('admin_transactions_$driverId', transactions);
      print('[FCM] Admin transaction saved for driver $driverId: ${isCredit ? "+" : "-"}₹$amountStr');
      
      // Notify wallet screen to update
      walletUpdateController.add(true);
      
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
