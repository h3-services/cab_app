import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/widgets.dart';
import '../widgets/bottom_navigation.dart';
import '../services/razorpay_service.dart';
import '../services/payment_service.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool isLoading = false;
  double walletBalance = 0.0;
  List<Map<String, dynamic>> transactions = [];
  late RazorpayService _razorpayService;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _loadWalletData();
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

  Future<void> _loadWalletData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');

      if (driverId != null) {
        // 1. Get balance from cache instantly if available
        final cachedDriverData = prefs.getString('driver_data');
        if (cachedDriverData != null) {
          final data = json.decode(cachedDriverData);
          setState(() {
            walletBalance =
                (num.tryParse(data['wallet_balance']?.toString() ?? '0') ?? 0)
                    .toDouble();
          });
        }

        // 2. Fetch latest data in parallel
        final results = await Future.wait([
          PaymentService.getAllPayments(),
          ApiService.getAllTrips(),
          PaymentService.getWalletTransactions(driverId),
        ]);

        final List payments = results[0];
        final List allTrips = results[1];
        final List walletTxns = results[2];

        List<Map<String, dynamic>> transactionHistory = [];
        Set<String> processedTxnIds = {};

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

        // Process Trips (Earnings and Fees)
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

            // More permissive status check to catch variations
            bool isCompleted = tripStatus == 'COMPLETED' ||
                tripStatus == 'CLOSED' ||
                (trip['is_completed'] == true);

            if (isMyTrip && isCompleted) {
              // Strictly prioritize 'fare' as per user input
              final fare = (num.tryParse(trip['fare']?.toString() ??
                          trip['total_fare']?.toString() ??
                          trip['total_amount']?.toString() ??
                          trip['amount']?.toString() ??
                          trip['total_cost']?.toString() ??
                          '0') ??
                      0)
                  .toDouble();

              final date = trip['completed_at'] ??
                  trip['created_at'] ??
                  DateTime.now().toIso8601String();
              final displayDate = date.toString().split('T')[0];
              final tripIdVisible = (trip['trip_id'] ?? 'TRIP').toString();

              if (fare > 0) {
                // Trip Gross Earning
                transactionHistory.add({
                  'title': 'Total Trip Cost',
                  'date': displayDate,
                  'tripId': tripIdVisible,
                  'transaction_id': '',
                  'amount': '+₹${fare.toStringAsFixed(2)}',
                  'type': 'earning',
                  'raw_date': date,
                });

                // Find matching wallet transaction to show ACTUAL service fee (as per user's request)
                final matchingTxn = walletTxns.firstWhere(
                  (txn) => (txn['trip_id']?.toString() == tripIdVisible ||
                      (txn['description']?.toString().contains(tripIdVisible) ??
                          false)),
                  orElse: () => null,
                );

                double feeAmount = 0;
                String txnId = '';
                String txnDate = date;

                if (matchingTxn != null) {
                  // User's idea: Calculate based on balance change if available
                  final before = (num.tryParse(
                              matchingTxn['balance_before']?.toString() ??
                                  '0') ??
                          0)
                      .toDouble();
                  final after = (num.tryParse(
                              matchingTxn['balance_after']?.toString() ??
                                  '0') ??
                          0)
                      .toDouble();

                  if (before != 0 || after != 0) {
                    feeAmount = (before - after).abs();
                  } else {
                    feeAmount = (num.tryParse(
                                matchingTxn['amount']?.toString() ?? '0') ??
                            0)
                        .toDouble()
                        .abs();
                  }

                  txnId = matchingTxn['transaction_id']?.toString() ?? '';
                  txnDate = matchingTxn['created_at'] ?? date;

                  if (matchingTxn['transaction_id'] != null) {
                    processedTxnIds
                        .add(matchingTxn['transaction_id'].toString());
                  }
                } else {
                  // Fallback to 2% if server transaction record isn't found yet
                  feeAmount = fare * 0.02;
                }

                if (feeAmount > 0) {
                  transactionHistory.add({
                    'title': 'Service Fee (2%)',
                    'date': displayDate,
                    'tripId': tripIdVisible,
                    'transaction_id': txnId,
                    'amount': '-₹${feeAmount.toStringAsFixed(2)}',
                    'type': 'spending',
                    'raw_date': txnDate,
                  });
                }
              }
            }
          }
        }

        // Process actual Wallet Transaction records from backend
        for (var txn in walletTxns) {
          final txnId = txn['transaction_id']?.toString();
          if (txnId != null && processedTxnIds.contains(txnId)) continue;

          final amount =
              (num.tryParse(txn['amount']?.toString() ?? '0') ?? 0).toDouble();
          final title = txn['description'] ?? 'Wallet Transaction';
          final date = txn['created_at'] ?? DateTime.now().toIso8601String();
          final displayDate = date.toString().split('T')[0];

          if (!title.contains('Service Fee') || amount != 0) {
            transactionHistory.add({
              'title': title,
              'date': displayDate,
              'tripId': txn['trip_id']?.toString() ?? 'N/A',
              'transaction_id': txn['transaction_id'] ?? '',
              'amount': amount < 0
                  ? '-₹${amount.abs().toStringAsFixed(2)}'
                  : '+₹${amount.toStringAsFixed(2)}',
              'type': amount < 0 ? 'spending' : 'earning',
              'raw_date': date,
            });
          }
        }

        // Sort by date descending
        transactionHistory.sort((a, b) {
          final dateA = a['raw_date'].toString();
          final dateB = b['raw_date'].toString();
          return dateB.compareTo(dateA);
        });

        setState(() {
          transactions = transactionHistory;
        });

        // 3. Update live balance from API
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
    _razorpayService.openCheckout(
      amount: 500.0,
      name: 'Chola Cabs',
      description: 'Wallet Top-up',
      contact: '9999999999',
      email: 'user@example.com',
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isLoading = true);

    debugPrint('=== RAZORPAY PAYMENT SUCCESS ===');
    debugPrint('Payment ID: ${response.paymentId}');
    debugPrint('Order ID: ${response.orderId}');
    debugPrint('Signature: ${response.signature}');
    debugPrint('Amount: ₹500.00');
    debugPrint('================================');

    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');

      if (driverId == null || driverId.isEmpty) {
        throw Exception('Driver ID not found. Please login again.');
      }

      debugPrint('=== DRIVER INFO ===');
      debugPrint('Driver ID: $driverId');
      debugPrint('==================');

      final apiResponse = await PaymentService.createPayment(
        driverId: driverId,
        amount: 500.0,
        paymentMethod: 'RAZORPAY',
        transactionType: 'ONLINE',
        razorpayPaymentId: response.paymentId!,
        razorpayOrderId: response.orderId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      debugPrint('=== API RESPONSE SUCCESS ===');
      debugPrint('API Response: $apiResponse');
      debugPrint('============================');

      // 4. Get CURRENT data from API first to be absolutely sure of the balance BEFORE updating
      final currentData = await ApiService.getDriverDetails(driverId);
      final currentBalance =
          (num.tryParse(currentData['wallet_balance']?.toString() ?? '0') ?? 0)
              .toDouble();

      final newTotalBalance = currentBalance + 500.0;
      debugPrint(
          'Adding ₹500 to current balance: $currentBalance. New Total: $newTotalBalance');

      // 4. Update the wallet_balance using the dedicated PATCH call
      await ApiService.updateWalletBalance(driverId, newTotalBalance);

      // 5. Update local cache and state IMMEDIATELY so the user sees the change
      setState(() {
        walletBalance = newTotalBalance;
      });

      // Update the cached json string
      currentData['wallet_balance'] = newTotalBalance;
      await prefs.setString('driver_data', jsonEncode(currentData));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment successful! New balance: ₹${newTotalBalance.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh transaction history
      _loadWalletData();
    } catch (e) {
      debugPrint('=== API ERROR ===');
      debugPrint('Error: $e');
      debugPrint('=================');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment API error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
            context, '/dashboard', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE0E0E0),
        appBar: const CustomAppBar(),
        endDrawer: _buildDrawer(context),
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
                      // Balance Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF66BB6A),
                              const Color(0xFF388E3C)
                            ], // Standard Green
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
                      // Stats Row
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
                                const Text(
                                  '15',
                                  style: TextStyle(
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
                                  horizontal: 20, vertical: 12),
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
                                        color: Colors.black, size: 24),
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
                      // Transaction History Header
                      const Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Transaction List
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
                      else
                        ...transactions.map((transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTransactionItem(
                                transaction['title'],
                                transaction['date'],
                                transaction['tripId'] != 'N/A'
                                    ? 'Trip ID: ${transaction['tripId']}'
                                    : 'Transaction ID: ${transaction['transaction_id']}',
                                transaction['amount'],
                                transaction['type'],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Navigation
            const BottomNavigation(currentRoute: '/wallet'),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      String title, String date, String tripId, String amount, String type) {
    bool isEarning = type == 'earning';
    return Container(
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
              isEarning ? Icons.directions_car : Icons.remove_circle,
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
                const SizedBox(height: 2),
                Text(
                  tripId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
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
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chola_cabs_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade400,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tom Holland',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDrawerMenuItem(context, Icons.person_outline, 'Profile',
                      'View and edit your personal details'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      'App preferences, notifications, and privacy'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.help_outline, 'Help',
                      'Get help and contact the admin for support'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.logout, 'Sign out',
                      'Log out of your account safely',
                      isSignOut: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
      BuildContext context, IconData icon, String title, String subtitle,
      {bool isSignOut = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (title == 'Profile') {
            Navigator.pushNamed(context, '/profile');
          } else if (title == 'Sign out') {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignOut ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : Colors.grey.shade700,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSignOut ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
