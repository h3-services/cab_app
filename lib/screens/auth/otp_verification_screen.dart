import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../admin/device_blocked_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].addListener(() {
        setState(() {});
      });
    }
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return 'unknown';
  }

  Future<void> _checkAndUpdateFcmToken(String driverId, Map<String, dynamic> driverData) async {
    try {
      final currentFcmToken = await FirebaseMessaging.instance.getToken();
      final storedFcmToken = driverData['fcm_token']?.toString();
      
      if (currentFcmToken != null && currentFcmToken != storedFcmToken) {
        await ApiService.addFcmToken(driverId, currentFcmToken);
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter complete OTP'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.verifyOtp(widget.phoneNumber, otp);
      
      if (!mounted) return;
      Navigator.pushNamed(context, '/registration', arguments: widget.phoneNumber);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline, color: Colors.red, size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invalid OTP',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The OTP you entered is incorrect.\nPlease try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.buttonGradientStart,
                              AppColors.buttonGradientEnd,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            navigator.pop();
                            try {
                              await ApiService.sendOtp(widget.phoneNumber);
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('OTP resent successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              for (var controller in _otpControllers) {
                                controller.clear();
                              }
                              _focusNodes[0].requestFocus();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to resend OTP: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(color: Colors.white, fontSize: 16),
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final availableHeight = screenHeight - padding.top - padding.bottom - viewInsets.bottom;
    final logoSize = screenWidth * 0.6;
    final horizontalPadding = screenWidth * 0.08;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.appGradientStart,
              AppColors.appGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: availableHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 12.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/chola_cabs_logo.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: logoSize,
                                  height: logoSize,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                );
                              },
                            ),
                            SizedBox(height: availableHeight * 0.04),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Verification Code',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.02),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'We have sent the verification\ncode to your phone number',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.04),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return Container(
                                  width: screenWidth * 0.12,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey, width: 1.5),
                                  ),
                                  child: RawKeyboardListener(
                                    focusNode: FocusNode(),
                                    onKey: (RawKeyEvent event) {
                                      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                                        if (_otpControllers[index].text.isEmpty && index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                          _otpControllers[index - 1].clear();
                                        }
                                      }
                                    },
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty && index < 5) {
                                          _focusNodes[index + 1].requestFocus();
                                        } else if (value.isEmpty && index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                        }
                                      },
                                      onTap: () {
                                        _otpControllers[index].selection = TextSelection.fromPosition(
                                          TextPosition(offset: _otpControllers[index].text.length),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                            SizedBox(height: availableHeight * 0.03),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Didn't receive OTP? ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    try {
                                      await ApiService.sendOtp(widget.phoneNumber);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('OTP resent successfully'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      for (var controller in _otpControllers) {
                                        controller.clear();
                                      }
                                      _focusNodes[0].requestFocus();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to resend OTP: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.bluePrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 80.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.buttonGradientStart,
                                  AppColors.buttonGradientEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
