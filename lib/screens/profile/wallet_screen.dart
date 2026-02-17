import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import '../../widgets/widgets.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/common/app_drawer.dart';
import '../trip/trip_start_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadWalletData();
    _setupFCMListener();
  }

  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((message) async {
      final type = message.data['type'];
      final title = message.notification?.title ?? '';
      debugPrint('[Wallet] FCM message received: $type, title: $title');
      debugPrint('[Wallet] FCM data: ${message.data}');
      
      if (type == 'WALLET_DEDUCTION' || type == 'WALLET_UPDATE' || title.contains('Wallet Debited')) {
        // Update wallet balance immediately from API
        final prefs = await SharedPreferences.getInstance();
        final driverId = prefs.getString('driverId');
        if (driverId != null) {
          try {
            final driverData = await ApiService.getDriverDetails(driverId);
            await prefs.setString('driver_data', jsonEncode(driverData));
            if (mounted) {
              setState(() {
                walletBalance = (num.tryParse(driverData['wallet_balance']?.toString() ?? '0') ?? 0).toDouble();
              });
            }
            debugPrint('[Wallet] Balance updated: $walletBalance');
          } catch (e) {
            debugPrint('[Wallet] Error updating balance: $e');
          }
        }
        // Reload full wallet data to get transactions
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
        for (String txnStr in adminTxns) {
          try {
            final txn = json.decode(txnStr) as Map<String, dynamic>;
            transactionHistory.add(txn);
          } catch (e) {
            debugPrint('Error parsing admin transaction: $e');
          }
        }

        // Sort by date descending
        transactionHistory.sort((a, b) {
          final dateA = a['raw_date'].toString();
          final dateB = b['raw_date'].toString();
          return dateB.compareTo(dateA);
        });

        setState(() {
          completedTripsCount = completedCount;
          transactions = transactionHistory;
        });

        // Update live balance from API
        final driverData = await ApiService.getDriverDetails(driverId);
        await prefs.setString('driver_data', jsonEncode(driverData));
        setState(() {
          walletBalance =
              (num.tryParse(driverData['wallet_balance']?.toString() ?? '0') ??
                      0)
                  .toDouble();
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
                        if (amount != null && amount > 0) {
                          Navigator.pop(context);
                          _currentPaymentAmount = amount;
                          _razorpayService.openCheckout(
                            amount: amount,
                            name: 'Chola Cabs',
                            description: 'Wallet Top-up',
                            contact: '9999999999',
                            email: 'user@example.com',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                              backgroundColor: Colors.red,
                            ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet: ${response.walletName}'),
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
                        ...transactions.where((transaction) {
                          if (walletBalance < 0) return false;
                          if (_transactionFilter == 'All') return true;
                          if (_transactionFilter == 'Top-up') return transaction['title'] == 'Wallet Top-up';
                          if (_transactionFilter == 'Service Fee') return transaction['title'] == 'Service Fee (10%)';
                          if (_transactionFilter == 'Admin Credit') return transaction['title'] == 'Admin Credit';
                          if (_transactionFilter == 'Admin Deduction') return transaction['title'] == 'Admin Deduction';
                          return false;
                        }).map((transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTransactionItem(
                                transaction['title'],
                                transaction['date'],
                                transaction['tripId'],
                                transaction['amount'],
                                transaction['type'],
                                transaction['trip'],
                              ),
                            )),
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
      String title, String date, String tripId, String amount, String type, [Map<String, dynamic>? trip]) {
    bool isEarning = type == 'earning';
    String subtitle = tripId != 'N/A' ? 'Trip ID: $tripId' : '';
    bool isServiceFee = title == 'Service Fee (10%)';

    return GestureDetector(
      onTap: isServiceFee && trip != null ? () => _navigateToTripCompleted(trip) : null,
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isEarning ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
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
                  date,
                  style: TextStyle(
                    fontSize: 14,
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
              color:
                  isEarning ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _navigateToTripCompleted(Map<String, dynamic> trip) {
    final startingKm = trip['odometer_start']?.toString() ?? '0';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripCompletedScreen(
          tripData: {
            'pickup': trip['pickup_location'] ?? '',
            'drop': trip['drop_location'] ?? '',
            'type': trip['trip_type'] ?? '',
            'vehicle_type': trip['vehicle_type'] ?? '',
            'customer': trip['customer_name'] ?? '',
            'phone': trip['customer_phone'] ?? '',
            'request_id': trip['request_id'],
            'trip_id': trip['trip_id'],
          },
          startingKm: startingKm,
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
      ),
    )).toList();
  }
}
