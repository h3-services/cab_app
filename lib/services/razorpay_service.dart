import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';

class RazorpayService {
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
    required String orderId,
    required int amount,
    required String key,
    required String name,
    required String description,
    required String contact,
    required String email,
  }) {
    try {
      final options = {
        'key': key,
        'order_id': orderId,
        'amount': amount,
        'name': name,
        'description': description,
        'prefill': {
          'contact': contact,
          'email': email,
        },
        'theme': {
          'color': '#3399cc'
        }
      };

      debugPrint('Razorpay options: $options');
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      rethrow;
    }
  }

  void dispose() {
    _razorpay.clear();
  }

  // Mock API calls for testing
  static Future<Map<String, dynamic>> createOrder() async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock response for testing
    return {
      'id': 'order_test_${DateTime.now().millisecondsSinceEpoch}',
      'amount': 50000, // ₹500 in paise
      'currency': 'INR',
    };
  }

  static Future<void> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    debugPrint('Verifying payment: $paymentId, $orderId, $signature');
    
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock verification success
    debugPrint('Payment verified successfully');
  }
}