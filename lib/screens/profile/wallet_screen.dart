import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';
import '../../widgets/widgets.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/common/app_drawer.dart';
import '../trip/trip_start_screen.dart';
import '../../services/firebase_messaging_service.dart';

import '../../widgets/dialogs/payment_success_dialog.dart';
import '../../services/razorpay_service.dart';
import '../../services/payment_service.dart';
import '../../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool isLoading = false;
  double walletBalance = 0.0;
  int completedTripsCount = 0;
  List<Map<String, dynamic>> transactions = [];
  String _transactionFilter = 'All'; // Filter state for transactions
  late RazorpayService _razorpayService;
  double _currentPaymentAmount = 0.0;
  StreamSubscription<RemoteMessage>? _fcmSubscription;
  StreamSubscription<bool>? _walletUpdateSubscription;
  bool _isSelectionMode = false;
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadWalletData();
    _setupFCMListener();
    _setupWalletUpdateListener();
  }

  void _setupWalletUpdateListener() {
    _walletUpdateSubscription = walletUpdateController.stream.listen((_) {
      if (mounted) {
        _loadWalletData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalletData();
    });
  }

  void _setupFCMListener() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((message) async {
      final type = message.data['type'];
      final title = message.notification?.title ?? '';
      debugPrint('[Wallet] FCM message received: $type, title: $title');
      
      if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || type == 'WALLET_CREDIT' || 
          title.contains('Wallet Debited') || title.contains('Wallet Credited')) {
        await _loadWalletData();
      }
    });
  }

  void _initRazorpay() {
    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _fcmSubscription?.cancel();
    _walletUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _safeGetAllPayments() async {
    try {
      return await PaymentService.getAllPayments();
    } catch (e) {
      debugPrint('Payments API failed (404 expected): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _safeGetWalletTransactions(String driverId) async {
    try {
      return await PaymentService.getWalletTransactions(driverId);
    } catch (e) {
      debugPrint('Wallet transactions API failed: $e');
      return [];
    }
  }

  Future<void> _loadWalletData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');

      if (driverId != null) {
        final cachedDriverData = prefs.getString('driver_data');
        if (cachedDriverData != null) {
          final data = json.decode(cachedDriverData);
          setState(() {
            walletBalance =
                (num.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0)
                    .toDouble();
          });
        }

        final results = await Future.wait([
          _safeGetAllPayments(),
          ApiService.getAllTrips(),
          _safeGetWalletTransactions(driverId),
        ]);

        final List payments = results[0];
        final List allTrips = results[1];
        final List walletTxns = results[2];

        debugPrint('Payments count: ${payments.length}');
        debugPrint('Trips count: ${allTrips.length}');
        debugPrint('Wallet Txns count: ${walletTxns.length}');
        debugPrint('Wallet Txns: $walletTxns');

        List<Map<String, dynamic>> transactionHistory = [];
        Set<String> processedTxnIds = {};
        int completedCount = 0;

        // Process Payments (Top-ups)
        for (var payment in payments) {
          final paymentDriverId = payment['driver_id']?.toString();
          if (paymentDriverId == driverId) {
            final amount =
                (num.tryParse(payment['amount']?.toString() ?? '0') ?? 0) /
                    100.0;
            final type = payment['transaction_type'] ?? '';

            if (type == 'ONLINE') {
              transactionHistory.add({
                'title': 'Wallet Top-up',
                'date': payment['payment_date']?.toString().split('T')[0] ??
                    DateTime.now().toString().split(' ')[0],
                'tripId': 'N/A',
                'transaction_id': payment['transaction_id'] ?? '',
                'amount': '+₹${amount.toStringAsFixed(2)}',
                'type': 'earning',
                'raw_date': payment['payment_date'] ?? '',
              });
              if (payment['transaction_id'] != null) {
                processedTxnIds.add(payment['transaction_id'].toString());
              }
            }
          }
        }

        // Process Trips - Only create service fee transactions
        for (var trip in allTrips) {
          if (trip is Map<String, dynamic>) {
            final tripDriverId = (trip['assigned_driver_id'] ??
                    trip['driver_id'] ??
                    trip['driver']?['driver_id'])
                ?.toString();
            final tripStatus = (trip['trip_status'] ?? trip['status'] ?? '')
                .toString()
                .toUpperCase();

            bool isMyTrip = false;
            if (driverId != null && tripDriverId != null) {
              isMyTrip = tripDriverId.trim().toLowerCase() ==
                  driverId.trim().toLowerCase();
            }

            bool isCompleted = tripStatus == 'COMPLETED' ||
                tripStatus == 'CLOSED' ||
                (trip['is_completed'] == true);

            if (isMyTrip && isCompleted) {
              completedCount++;
              final fare = (num.tryParse(trip['fare']?.toString() ??
                          trip['total_fare']?.toString() ??
                          trip['total_amount']?.toString() ??
                          trip['amount']?.toString() ??
                          trip['total_cost']?.toString() ??
                          '0') ??
                      0)
                  .toDouble();

              if (fare > 0) {
                final date = trip['completed_at'] ??
                    trip['created_at'] ??
                    DateTime.now().toIso8601String();
                final displayDate = date.toString().split('T')[0];
                final tripIdVisible = (trip['trip_id'] ?? 'TRIP').toString();
                final serviceFee = fare * 0.10;

                transactionHistory.add({
                  'title': 'Service Fee (10%)',
                  'date': displayDate,
                  'tripId': tripIdVisible,
                  'transaction_id': '',
                  'amount': '-₹${serviceFee.toStringAsFixed(2)}',
                  'type': 'spending',
                  'raw_date': date,
                  'trip': trip,
                });
              }
            }
          }
        }

        // Load local transactions from SharedPreferences (includes admin deductions)
        final localTxns = prefs.getStringList('local_transactions') ?? [];
        for (String txnStr in localTxns) {
          try {
            final txn = json.decode(txnStr) as Map<String, dynamic>;
            transactionHistory.add(txn);
          } catch (e) {
            debugPrint('Error parsing local transaction: $e');
          }
        }

        // Load admin transactions from SharedPreferences
        final adminTxns = prefs.getStringList('admin_transactions') ?? [];
        debugPrint('Loading ${adminTxns.length} admin transactions');
        for (String txnStr in adminTxns) {
          try {
            final txn = json.decode(txnStr) as Map<String, dynamic>;
            transactionHistory.add(txn);
            debugPrint('Added admin txn: ${txn['title']} - ${txn['amount']}');
          } catch (e) {
            debugPrint('Error parsing admin transaction: $e');
          }
        }
        
        // Balance already fetched above for comparison
        final currentApiBalance = (num.tryParse((await ApiService.getDriverDetails(driverId))['wallet_balance']?.toString() ?? '0') ?? 0).toDouble();
        await prefs.setDouble('last_known_balance', currentApiBalance);

        // Sort by date descending
        transactionHistory.sort((a, b) {
          final dateA = a['raw_date'].toString();
          final dateB = b['raw_date'].toString();
          return dateB.compareTo(dateA);
        });

        // Balance already fetched above
        final newBalance = currentApiBalance;
        final driverData = await ApiService.getDriverDetails(driverId);
        await prefs.setString('driver_data', jsonEncode(driverData));

        setState(() {
          completedTripsCount = completedCount;
          transactions = transactionHistory;
          walletBalance = newBalance;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
      setState(() => isLoading = false);
    }
  }

  void _showPaymentDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF565656), Color.fromARGB(255, 243, 236, 236)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(width: 80, height: 80),
              const SizedBox(height: 16),
              const Text(
                'Add Money to Wallet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: const InputDecoration(
                   
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          Navigator.pop(context);
                          _showInvalidAmountDialog();
                        } else {
                          Navigator.pop(context);
                          _currentPaymentAmount = amount;
                          _razorpayService.openCheckout(
                            amount: amount,
                            name: 'Chola Cabs',
                            description: 'Wallet Top-up',
                            contact: '9999999999',
                            email: 'user@example.com',
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF66BB6A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Proceed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');

      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver ID not found. Please login again.');
      }

      final amount = _currentPaymentAmount;
      bool paymentRecordCreated = false;

      // Try to create payment record, but don't fail if API doesn't exist
      try {
        await PaymentService.createPayment(
          driverId: driverId,
          amount: amount,
          paymentMethod: 'RAZORPAY',
          transactionType: 'ONLINE',
          razorpayPaymentId: response.paymentId!,
          razorpayOrderId: response.orderId ?? '',
          razorpaySignature: response.signature ?? '',
        );
        debugPrint('Payment record created successfully');
        paymentRecordCreated = true;
      } catch (paymentApiError) {
        debugPrint('Payment API failed (continuing anyway): $paymentApiError');
        // Continue with wallet update even if payment API fails
      }

      // Update wallet balance directly
      final currentData = await ApiService.getDriverDetails(driverId);
      final currentBalance =
          (num.tryParse(currentData['wallet_balance']?.toString() ?? '0') ?? 0)
              .toDouble();
      final newBalance = currentBalance + amount;

      await ApiService.updateWalletBalance(driverId, newBalance);

      setState(() => walletBalance = newBalance);
      currentData['wallet_balance'] = newBalance;
      await prefs.setString('driver_data', jsonEncode(currentData));

      // If payment API failed, add transaction locally to ensure it shows in history
      if (!paymentRecordCreated) {
        final now = DateTime.now();
        final localTransaction = {
          'title': 'Wallet Top-up',
          'date': now.toString().split(' ')[0],
          'tripId': 'N/A',
          'transaction_id': response.paymentId ?? '',
          'amount': '+₹${amount.toStringAsFixed(2)}',
          'type': 'earning',
          'raw_date': now.toIso8601String(),
        };
        
        // Save to SharedPreferences for persistence
        final prefs = await SharedPreferences.getInstance();
        final existingTxns = prefs.getStringList('local_transactions') ?? [];
        existingTxns.insert(0, jsonEncode(localTransaction));
        await prefs.setStringList('local_transactions', existingTxns);
        
        setState(() {
          transactions.insert(0, localTransaction);
        });
      }

      if (mounted) {
        final now = DateTime.now();
        final paymentTime =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}, ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => PaymentSuccessDialog(
            amount: '₹${amount.toStringAsFixed(2)}',
            paymentTime: paymentTime,
            paymentMethod: 'Razorpay',
          ),
        );
      }

      _loadWalletData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showPaymentFailedDialog(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet: ${response.walletName}'),
      ),
    );
  }

  void _showInvalidAmountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Invalid Amount',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enter a valid amount greater than zero to add money to your wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentFailedDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPaymentDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/chola_cabs_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter Transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter transactions by type',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  _buildTransactionFilterOption('All', 'All'),
                  const SizedBox(height: 12),
                  _buildTransactionFilterOption('Wallet Top-up', 'Top-up'),
                  const SizedBox(height: 12),
                  _buildTransactionFilterOption('Service Fee (10%)', 'Service Fee'),
                  const SizedBox(height: 12),
                  _buildTransactionFilterOption('Admin Credit', 'Admin Credit'),
                  const SizedBox(height: 12),
                  _buildTransactionFilterOption('Admin Deduction', 'Admin Deduction'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionFilterOption(String title, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _transactionFilter = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _transactionFilter == value ? const Color(0xFF66BB6A).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _transactionFilter == value ? const Color(0xFF66BB6A) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _transactionFilter == value ? const Color(0xFF66BB6A) : Colors.grey.shade400,
                  width: 2,
                ),
                color: _transactionFilter == value ? const Color(0xFF66BB6A) : Colors.transparent,
              ),
              child: _transactionFilter == value
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _transactionFilter == value ? const Color(0xFF66BB6A) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
// ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
            context, '/dashboard', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE0E0E0),
        appBar: const CustomAppBar(),
        endDrawer: const AppDrawer(),
        body: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE0E0E0),
                      Color(0xFFBDBDBD),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF66BB6A), Color(0xFF388E3C)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Balance',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '₹${walletBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: walletBalance < 0
                                        ? const Color(0xFFFF5252)
                                        : Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Opacity(
                              opacity: 0.6,
                              child: AppLogo(width: 80, height: 80),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.local_taxi,
                                    color: Colors.orange, size: 28),
                                const SizedBox(width: 12),
                                Text(
                                  'Trips Completed',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  completedTripsCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: isLoading ? null : _showPaymentDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isLoading
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  if (isLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.black),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.add,
                                        color: Colors.green, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    isLoading ? 'Processing...' : 'Add Money',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                          Row(
                            children: [
                              if (transactions.isNotEmpty && !_isSelectionMode)
                                GestureDetector(
                                  onTap: () => setState(() => _isSelectionMode = true),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.delete, color: Colors.white, size: 20),
                                  ),
                                ),
                              if (_isSelectionMode) ...[
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSelectionMode = false;
                                      _selectedIndices.clear();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _selectedIndices.isEmpty ? null : _deleteSelectedTransactions,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: _selectedIndices.isEmpty
                                          ? null
                                          : const LinearGradient(
                                              colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                                            ),
                                      color: _selectedIndices.isEmpty ? Colors.grey.shade300 : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Delete (${_selectedIndices.length})',
                                      style: TextStyle(
                                        color: _selectedIndices.isEmpty ? Colors.grey : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showTransactionFilterDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF424242),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _transactionFilter,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (transactions.isEmpty && !isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else if (isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        ...transactions.asMap().entries.where((entry) {
                          final transaction = entry.value;
                          if (walletBalance < 0) return false;
                          if (_transactionFilter == 'All') return true;
                          if (_transactionFilter == 'Top-up') return transaction['title'] == 'Wallet Top-up';
                          if (_transactionFilter == 'Service Fee') return transaction['title'] == 'Service Fee (10%)';
                          if (_transactionFilter == 'Admin Credit') return transaction['title'] == 'Admin Credit';
                          if (_transactionFilter == 'Admin Deduction') return transaction['title'] == 'Admin Deduction';
                          return false;
                        }).map((entry) {
                          final index = entry.key;
                          final transaction = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTransactionItem(
                              transaction['title'],
                              transaction['date'],
                              transaction['tripId'],
                              transaction['amount'],
                              transaction['type'],
                              transaction['trip'],
                              index,
                            ),
                          );
                        }),
                      if (walletBalance < 0) ..._buildCompletedTrips(),
                    ],
                  ),
                ),
              ),
            ),
            BottomNavigation(currentRoute: '/wallet'),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      String title, String date, String tripId, String amount, String type, Map<String, dynamic>? trip, int index) {
    bool isEarning = type == 'earning';
    String subtitle = tripId != 'N/A' ? 'Trip ID: $tripId' : '';
    bool isServiceFee = title == 'Service Fee (10%)';
    bool isSelected = _selectedIndices.contains(index);

    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              setState(() {
                if (isSelected) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            }
          : (isServiceFee && trip != null ? () => _navigateToTripCompleted(trip) : null),
      child: Dismissible(
        key: Key('transaction_$index'),
        direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF5350), Color(0xFFC62828)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.white, size: 32),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Transaction'),
              content: const Text('Are you sure you want to delete this transaction?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) => _deleteTransaction(index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: Row(
            children: [
              if (_isSelectionMode)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Colors.blue : Colors.grey, width: 2),
                    color: isSelected ? Colors.blue : Colors.transparent,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEarning ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEarning ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date ${_formatTime(date)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isEarning ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(int index) async {
    final transaction = transactions[index];
    final title = transaction['title'];
    
    setState(() {
      transactions.removeAt(index);
    });
    
    final prefs = await SharedPreferences.getInstance();
    
    if (title == 'Admin Credit' || title == 'Admin Deduction') {
      final adminTxns = prefs.getStringList('admin_transactions') ?? [];
      adminTxns.removeWhere((txn) => jsonDecode(txn)['raw_date'] == transaction['raw_date']);
      await prefs.setStringList('admin_transactions', adminTxns);
    } else if (title == 'Wallet Top-up') {
      final localTxns = prefs.getStringList('local_transactions') ?? [];
      localTxns.removeWhere((txn) => jsonDecode(txn)['raw_date'] == transaction['raw_date']);
      await prefs.setStringList('local_transactions', localTxns);
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Transactions'),
        content: const Text('Are you sure you want to delete all transaction history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllTransactions();
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedTransactions() async {
    if (_selectedIndices.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transactions'),
        content: Text('Are you sure you want to delete ${_selectedIndices.length} transaction(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final indicesToDelete = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));

    for (int index in indicesToDelete) {
      final transaction = transactions[index];
      final title = transaction['title'];

      if (title == 'Admin Credit' || title == 'Admin Deduction') {
        final adminTxns = prefs.getStringList('admin_transactions') ?? [];
        adminTxns.removeWhere((txn) => jsonDecode(txn)['raw_date'] == transaction['raw_date']);
        await prefs.setStringList('admin_transactions', adminTxns);
      } else if (title == 'Wallet Top-up') {
        final localTxns = prefs.getStringList('local_transactions') ?? [];
        localTxns.removeWhere((txn) => jsonDecode(txn)['raw_date'] == transaction['raw_date']);
        await prefs.setStringList('local_transactions', localTxns);
      }
    }

    setState(() {
      for (int index in indicesToDelete) {
        transactions.removeAt(index);
      }
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _clearAllTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_transactions');
    await prefs.remove('local_transactions');
    
    setState(() {
      transactions.removeWhere((t) => 
        t['title'] == 'Admin Credit' || 
        t['title'] == 'Admin Deduction' || 
        t['title'] == 'Wallet Top-up'
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All transactions cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(String date) {
    try {
      final dateTime = DateTime.parse(date);
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return '';
    }
  }

  void _navigateToTripCompleted(Map<String, dynamic> trip) {
    final startingKm = (trip['odo_start'] ?? trip['starting_km'] ?? '0').toString();
    final endingKm = (trip['odo_end'] ?? trip['ending_km'] ?? '0').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ReadOnlyTripSummary(
          tripData: {
            'pickup': trip['pickup_address'] ?? trip['pickup_location'] ?? '',
            'drop': trip['drop_address'] ?? trip['drop_location'] ?? '',
            'type': trip['trip_type'] ?? '',
            'vehicle_type': trip['vehicle_type'] ?? '',
            'customer': trip['customer_name'] ?? '',
            'phone': trip['customer_phone'] ?? trip['phone'] ?? '',
            'request_id': trip['request_id'],
            'trip_id': trip['trip_id'],
          },
          startingKm: startingKm,
          endingKm: endingKm,
          tripDetails: trip,
        ),
      ),
    );
  }

  List<Widget> _buildCompletedTrips() {
    final completedTrips = transactions.where((t) => t['title'] == 'Service Fee (10%)').toList();
    if (completedTrips.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No completed trips',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      ];
    }
    return completedTrips.map((trip) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildTransactionItem(
        trip['title'],
        trip['date'],
        trip['tripId'],
        trip['amount'],
        trip['type'],
        trip['trip'],
        completedTrips.indexOf(trip),
      ),
    )).toList();
  }
}

class _ReadOnlyTripSummary extends StatelessWidget {
  final Map<String, dynamic> tripData;
  final String startingKm;
  final String endingKm;
  final Map<String, dynamic>? tripDetails;

  const _ReadOnlyTripSummary({
    required this.tripData,
    required this.startingKm,
    required this.endingKm,
    this.tripDetails,
  });

  @override
  Widget build(BuildContext context) {
    final startKm = num.tryParse(startingKm) ?? 0;
    final endKm = num.tryParse(endingKm) ?? 0;
    final dist = (endKm - startKm).abs();

    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Trip Summary',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow('Distance Traveled', '${tripDetails?['distance_km'] ?? dist} km'),
                        _buildSummaryRow('Tariff Type', tripDetails?['vehicle_type'] ?? tripData['vehicle_type'] ?? 'N/A'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total Actual Fare(Inclusive of Taxes)', '₹ ${(tripDetails?['fare'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Waiting Charges(Rs)', '₹ ${(tripDetails?['waiting_charges'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Inter State Permit(Rs)', '₹ ${(tripDetails?['inter_state_permit_charges'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Driver Allowance(Rs)', '₹ ${(tripDetails?['driver_allowance'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Luggage Cost(Rs)', '₹ ${(tripDetails?['luggage_cost'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Pet Cost(Rs)', '₹ ${(tripDetails?['pet_cost'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Toll charge(Rs)', '₹ ${(tripDetails?['toll_charges'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Night Allowance(Rs)', '₹ ${(tripDetails?['night_allowance'] ?? 0).toStringAsFixed(2)}'),
                        const SizedBox(height: 12),
                        const Divider(thickness: 1, color: Colors.grey),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Cost(Rs)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '₹ ${(tripDetails?['total_amount'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F884F), Color(0xFF2B4E2B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
