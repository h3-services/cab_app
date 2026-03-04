import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'notification_service.dart';
import '../main.dart';
import 'notification_plugin.dart';
import 'api_service.dart';
import 'payment_service.dart';
import 'native_audio_service.dart';
// Global stream controller for wallet updates
final StreamController<bool> walletUpdateController = StreamController<bool>.broadcast();
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  try {
    print('[FCM-BG] Background handler called at ${DateTime.now()}');
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    print('[FCM-BG] Title: $title, Body: $body');
    
    await NotificationService.saveNotification(title, body);
    
    // Handle wallet transactions in background
    final type = message.data['type'] as String?;
    if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || type == 'WALLET_CREDIT' || 
        title.contains('Wallet Debited') || title.contains('Wallet Credited')) {
      print('[FCM-BG] Wallet transaction detected');
      await _handleWalletDeduction(message.data, body);
      
      // Also save to pending queue as backup
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_wallet_txns') ?? [];
      pending.add(jsonEncode({
        'data': message.data,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList('pending_wallet_txns', pending);
      print('[FCM-BG] Saved to pending queue');
    }
    
    print("[FCM-BG] Background notification saved, FCM will display with sound");
  } catch (e, stackTrace) {
    print('[FCM-BG] ERROR: $e');
    print('[FCM-BG] Stack: $stackTrace');
  }
}
Future<void> initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;
  
  // Request permissions
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  
  print('🔔 FCM Permission: ${settings.authorizationStatus}');
  
  // Get and print FCM token
  final token = await messaging.getToken();
  print('🔔 FCM Token: $token');
  
  // CRITICAL: Send token to backend immediately if driver is logged in
  if (token != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token_pending', token);
    
    final driverId = prefs.getString('driverId');
    if (driverId != null && driverId.isNotEmpty) {
      await _syncFcmToken(driverId, token);
    } else {
      print('⚠️ Driver not logged in yet, token will sync after login');
    }
  }
  
  // Listen for token refresh
  messaging.onTokenRefresh.listen((newToken) async {
    print('🔄 FCM Token refreshed: $newToken');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token_pending', newToken);
    
    final driverId = prefs.getString('driverId');
    if (driverId != null && driverId.isNotEmpty) {
      await _syncFcmToken(driverId, newToken);
    }
  });
  // Handle message when app is launched from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      _handleNotificationClick(message.data);
    }
  });
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Foreground - save and show notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final type = message.data['type'] as String?;
    await NotificationService.saveNotification(title, body);
    // Handle wallet deduction - check both type and title
    if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || type == 'WALLET_CREDIT' || 
        title.contains('Wallet Debited') || title.contains('Wallet Credited')) {
      await _handleWalletDeduction(message.data, body);
    }
    // Show notification in foreground (audio plays via AudioService + channel sound)
    await NotificationPlugin.showNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
    });
  // Background/Terminated - navigate when tapped
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationClick(message.data);
  });
}
void _handleNotificationClick(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
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
    }
}
Future<void> _handleWalletDeduction(Map<String, dynamic> data, String body) async {
  try {
    print('[Wallet] Processing wallet transaction...');
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId');
    if (driverId == null) {
      print('[Wallet] ERROR: Driver ID not found');
      return;
    }
    print('[Wallet] Driver ID: $driverId');
    
    // Determine if it's credit or debit
    bool isCredit = body.contains('credited') || body.contains('added') || body.contains('Credited');
    bool isDebit = body.contains('debited') || body.contains('deducted') || body.contains('Debited');
    String? amountStr;
    String? newBalance;
    // Extract amount - works for both credit and debit
    final amountRegex = RegExp(r'(?:debited by|credited with|added|deducted|Debited by|Credited with) [₹\$]?\s*(\d+\.?\d*)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch != null) {
      amountStr = amountMatch.group(1);
      print('[Wallet] Extracted amount: $amountStr');
    }
    // Extract new balance
    final balanceRegex = RegExp(r'balance is [₹\$]?\s*(\d+\.?\d*)', caseSensitive: false);
    final balanceMatch = balanceRegex.firstMatch(body);
    if (balanceMatch != null) {
      newBalance = balanceMatch.group(1);
      print('[Wallet] Extracted new balance: $newBalance');
    }
    if (amountStr != null && amountStr.isNotEmpty) {
      final now = DateTime.now();
      final transaction = {
        'title': isCredit ? 'Admin Credit' : 'Admin Deduction',
        'date': now.toString().split(' ')[0],
        'tripId': 'N/A',
        'transaction_id': data['transaction_id'] ?? '',
        'amount': '${isCredit ? "+" : "-"}₹$amountStr',
        'type': isCredit ? 'earning' : 'spending',
        'raw_date': now.toIso8601String(),
        'reason': isCredit ? 'Wallet Credited' : 'Wallet Debited',
      };
      final transactions = prefs.getStringList('admin_transactions_$driverId') ?? [];
      transactions.insert(0, jsonEncode(transaction));
      await prefs.setStringList('admin_transactions_$driverId', transactions);
      print('[Wallet] ✅ Transaction saved locally: ${transaction['title']} ${transaction['amount']}');
      
      // Save to backend for persistence across app reinstalls
      try {
        await PaymentService.createWalletTransaction(
          driverId: driverId,
          amount: double.parse(amountStr),
          transactionType: isCredit ? 'CREDIT' : 'DEBIT',
          description: isCredit ? 'Admin Credit' : 'Admin Deduction',
        );
        print('[Wallet] ✅ Transaction saved to backend');
      } catch (e) {
        print('[Wallet] ⚠️ Backend save failed (local saved): $e');
      }
      
      // Notify wallet screen to update
      walletUpdateController.add(true);
      // Update cached wallet balance
      if (newBalance != null) {
        final cachedData = prefs.getString('driver_data');
        if (cachedData != null) {
          final driverData = jsonDecode(cachedData);
          driverData['wallet_balance'] = newBalance;
          await prefs.setString('driver_data', jsonEncode(driverData));
          print('[Wallet] ✅ Wallet balance updated: $newBalance');
        }
      }
    } else {
      print('[Wallet] ERROR: Could not extract amount from message: $body');
    }
  } catch (e, stackTrace) {
    print('[Wallet] ERROR saving transaction: $e');
    print('[Wallet] Stack trace: $stackTrace');
  }
}
Future<void> _syncFcmToken(String driverId, String currentToken) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('fcm_token');
    
    if (currentToken != storedToken) {
      print('🔄 Syncing FCM token to backend...');
      await ApiService.addFcmToken(driverId, currentToken);
      await prefs.setString('fcm_token', currentToken);
      await prefs.remove('fcm_token_pending');
      print('✅ FCM token synced successfully');
    } else {
      print('ℹ️ FCM token already up to date');
    }
  } catch (e) {
    print('❌ FCM sync failed: $e');
    // Keep pending token for retry
  }
}

/// Call this after driver login to sync pending FCM token
Future<void> syncPendingFcmToken(String driverId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pendingToken = prefs.getString('fcm_token_pending');
    
    if (pendingToken != null && pendingToken.isNotEmpty) {
      print('🔄 Syncing pending FCM token after login...');
      await _syncFcmToken(driverId, pendingToken);
    } else {
      // Try to get current token
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await _syncFcmToken(driverId, token);
      }
    }
    
    // Process pending wallet transactions
    await _processPendingWalletTransactions();
  } catch (e) {
    print('❌ Failed to sync pending token: $e');
  }
}

/// Process any pending wallet transactions that were saved in background
Future<void> _processPendingWalletTransactions() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_wallet_txns') ?? [];
    
    if (pending.isEmpty) return;
    
    print('[Wallet] Processing ${pending.length} pending transactions');
    
    for (String txnStr in pending) {
      try {
        final txn = jsonDecode(txnStr);
        await _handleWalletDeduction(txn['data'], txn['body']);
      } catch (e) {
        print('[Wallet] Failed to process pending txn: $e');
      }
    }
    
    // Clear pending queue
    await prefs.remove('pending_wallet_txns');
    print('[Wallet] ✅ Processed all pending transactions');
  } catch (e) {
    print('[Wallet] ERROR processing pending: $e');
  }
}
