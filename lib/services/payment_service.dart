import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in';

  static Future<Map<String, dynamic>> createPayment({
    required String driverId,
    required double amount,
    required String paymentMethod,
    required String transactionType,
    String? tripId,
    String? transactionId,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    String status = 'SUCCESS',
  }) async {
    final url = Uri.parse('https://api.cholacabs.in/api/v1/payments/');

    final body = {
      "driver_id": driverId,
      "amount": (amount * 100).toInt(),
      "transaction_type": transactionType == 'ONLINE' ? 'CASH' : transactionType,
      "status": status,
      "transaction_id": transactionId ?? razorpayPaymentId ?? _generateTransactionId(),
      "razorpay_payment_id": razorpayPaymentId ?? '',
      "razorpay_order_id": razorpayOrderId ?? 'N/A',
      "razorpay_signature": razorpaySignature ?? 'N/A',
    };

    try {
      debugPrint('=== PAYMENT API DEBUG ===');
      debugPrint('POST Request URL: $url');
      debugPrint('Request Headers: ${jsonEncode({
            "Content-Type": "application/json"
          })}');
      debugPrint('Request Body: ${jsonEncode(body)}');
      debugPrint('========================');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('=== PAYMENT API RESPONSE ===');
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('============================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ PAYMENT STORED SUCCESSFULLY!');
        debugPrint('Payment ID: ${jsonDecode(response.body)['payment_id']}');
        debugPrint('Driver ID: $driverId');
        debugPrint('Amount: ₹${amount.toStringAsFixed(2)}');
        debugPrint('Transaction ID: ${jsonDecode(response.body)['transaction_id']}');
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ PAYMENT STORAGE FAILED!');
        throw Exception(
            'Failed to create payment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Wallet top-up payment
  static Future<Map<String, dynamic>> createWalletTopup({
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final driverId = await _getDriverId();
    if (driverId == null) throw Exception('Driver ID not found');

    return createPayment(
      driverId: driverId,
      amount: amount,
      paymentMethod: 'RAZORPAY',
      transactionType: 'ONLINE',
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      razorpaySignature: razorpaySignature,
    );
  }

  // Trip payment
  static Future<Map<String, dynamic>> createTripPayment({
    required String tripId,
    required double amount,
    required String paymentMethod,
    String? transactionId,
  }) async {
    final driverId = await _getDriverId();
    if (driverId == null) throw Exception('Driver ID not found');

    return createPayment(
      driverId: driverId,
      tripId: tripId,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionType: paymentMethod == 'CASH' ? 'CASH' : 'ONLINE',
      transactionId: transactionId,
    );
  }

  // Test dummy payment for API checking
  static Future<Map<String, dynamic>> createDummyPayment() async {
    final driverId = await _getDriverId();
    if (driverId == null) throw Exception('Driver ID not found');

    return createPayment(
      driverId: driverId,
      amount: 100.0, // ₹100 dummy amount
      paymentMethod: 'DUMMY',
      transactionType: 'ONLINE',
      transactionId: 'DUMMY_${DateTime.now().millisecondsSinceEpoch}',
      status: 'SUCCESS',
    );
  }

  // Test with hardcoded driver ID for debugging
  static Future<Map<String, dynamic>> createTestPayment({
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    return createPayment(
      driverId: '90fb08a3-019c-4036-95c3-bd8e72125b75', // Your driver ID
      amount: amount,
      paymentMethod: 'RAZORPAY',
      transactionType: 'ONLINE',
      razorpayPaymentId: razorpayPaymentId,
      razorpayOrderId: razorpayOrderId,
      razorpaySignature: razorpaySignature,
    );
  }

  static Future<String?> _getDriverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      debugPrint('Driver ID from SharedPreferences: $driverId');
      return driverId;
    } catch (e) {
      debugPrint('Error getting driver ID: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> createWalletTransaction({
    required String driverId,
    required double amount,
    required String transactionType,
    String? description,
    String? paymentId,
  }) async {
    final url = Uri.parse('https://api.cholacabs.in/api/v1/wallet-transactions/');

    final body = {
      "driver_id": driverId,
      "amount": amount,
      "transaction_type": transactionType,
      "description": description ?? 'Wallet transaction',
    };

    if (paymentId != null) body["payment_id"] = paymentId;

    try {
      debugPrint('=== WALLET TRANSACTION API ===');
      debugPrint('POST Request URL: $url');
      debugPrint('Request Body: ${jsonEncode(body)}');
      debugPrint('==============================');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint('=== WALLET TRANSACTION RESPONSE ===');
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('===================================');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to create wallet transaction: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Wallet Transaction Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getWalletTransactions(
      String driverId) async {
    final url =
        Uri.parse('$baseUrl/api/v1/wallet-transactions/?driver_id=$driverId');

    try {
      final response =
          await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final List<dynamic> transactions = jsonDecode(response.body);
        return transactions.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to get wallet transactions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Get Wallet Transactions Error: $e');
      return [];
    }
  }

  static String _generateTransactionId() {
    return 'TXN${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<List<Map<String, dynamic>>> getAllPayments() async {
    final url = Uri.parse('https://api.cholacabs.in/api/v1/payments/');

    try {
      debugPrint('=== GET PAYMENTS API ===');
      debugPrint('GET Request URL: $url');
      debugPrint('========================');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      debugPrint('=== GET PAYMENTS RESPONSE ===');
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('=============================');

      if (response.statusCode == 200) {
        final List<dynamic> payments = jsonDecode(response.body);
        return payments.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get payments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('GET Payments Error: $e');
      throw Exception('Network error: $e');
    }
  }
}
