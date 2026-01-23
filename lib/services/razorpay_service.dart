import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RazorpayService {
  static const String _razorpayKey = 'rzp_test_1DP5mmOlF5G5ag';
  static String get _baseUrl => dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api/v1';
  
  late Razorpay _razorpay;

  RazorpayService({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    required Function(ExternalWalletResponse) onWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, onWallet);
  }

  void openCheckout({
    required double amount,
    required String name,
    required String description,
    required String contact,
    required String email,
  }) {
    try {
      final options = {
        'key': _razorpayKey,
        'amount': (amount * 100).toInt(),
        'name': name,
        'description': description,
        'currency': 'INR',
        'prefill': {
          'contact': contact,
          'email': email,
        },
        'theme': {
          'color': '#66BB6A'
        }
      };

      debugPrint('Opening Razorpay with options: $options');
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
      rethrow;
    }
  }

  static Future<String?> _getDriverId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverData = prefs.getString('driver_data');
      if (driverData != null) {
        final data = jsonDecode(driverData);
        return data['id']?.toString() ?? data['driver_id']?.toString();
      }
    } catch (e) {
      debugPrint('Error getting driver ID: $e');
    }
    return null;
  }

  static Future<bool> savePaymentDetails({
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final driverId = await _getDriverId();
      if (driverId == null) {
        debugPrint('Driver ID not found');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/payments/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'driver_id': driverId,
          'amount': (amount * 100).toInt(),
          'transaction_type': 'RAZORPAY',
          'status': 'SUCCESS',
          'transaction_id': razorpayPaymentId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        }),
      );

      debugPrint('Payment save response: ${response.statusCode}');
      debugPrint('Payment save body: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error saving payment: $e');
      return false;
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}