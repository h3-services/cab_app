import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class RazorpayService {
  static const String _razorpayKey = 'rzp_test_1DP5mmOlF5G5ag';
  
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

  static Future<bool> savePaymentDetails({
    required double amount,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      await ApiService.createPayment(
        driverId: 'DRIVER_001',
        amount: amount,
        paymentMethod: 'RAZORPAY',
        transactionType: 'WALLET_TOPUP',
        razorpayPaymentId: razorpayPaymentId,
        razorpayOrderId: razorpayOrderId,
        razorpaySignature: razorpaySignature,
      );
      return true;
    } catch (e) {
      debugPrint('Error saving payment: $e');
      return false;
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}