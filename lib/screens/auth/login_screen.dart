import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/firebase_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:async';
import '../admin/device_blocked_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    return 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final padding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final availableHeight =
        screenHeight - padding.top - padding.bottom - viewInsets.bottom;
    final logoSize = screenWidth * 0.5;
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
                                'OTP Verification',
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
                                'Enter email and phone number to\nsend one time Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            SizedBox(height: availableHeight * 0.03),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Phone Number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: const Text(
                                          '+91',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          keyboardType: TextInputType.phone,
                                          maxLength: 10,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 14,
                                            ),
                                            hintText: '9876543210',
                                            hintStyle: TextStyle(
                                              color: Colors.black38,
                                            ),
                                            counterText: '',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: availableHeight * 0.02),
                            const Text(
                              'Fast, secure verification for a smooth journey.\nEnter your number to receive an OTP.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
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
                              onPressed: _isLoading ? null : () async {
                                if (_phoneController.text.length == 10) {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  try {
                                    final phoneNumber = '+91${_phoneController.text}';
                                    
                                    await FirebaseAuthService.sendOTP(
                                      phoneNumber: phoneNumber,
                                      onCodeSent: (verificationId) {
                                        if (!mounted) return;
                                        setState(() {
                                          _isLoading = false;
                                        });
                                        Navigator.pushNamed(
                                          context,
                                          '/verification',
                                          arguments: _phoneController.text,
                                        );
                                      },
                                      onError: (error) {
                                        if (!mounted) return;
                                        setState(() {
                                          _isLoading = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      },
                                      onAutoVerify: (credential) async {
                                        // Auto-verification (Android)
                                        await _handleSuccessfulAuth(_phoneController.text);
                                      },
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a valid 10-digit phone number',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
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

  Future<void> _checkAndUpdateFcmToken(String driverId, Map<String, dynamic> driverData) async {
    try {
      final currentFcmToken = await FirebaseMessaging.instance.getToken();
      final storedFcmToken = driverData['fcm_token']?.toString();
      
      if (currentFcmToken != null && currentFcmToken != storedFcmToken) {
        await ApiService.addFcmToken(driverId, currentFcmToken);
        debugPrint('FCM token updated for driver $driverId');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  Future<void> _handleSuccessfulAuth(String phoneNumber) async {
    try {
      final response = await ApiService.checkPhoneExists(phoneNumber);
      
      if (response['exists'] == true) {
        final currentDeviceId = await _getDeviceId();
        final driverId = response['driver_id'].toString();
        
        final driverData = await ApiService.getDriverDetails(driverId);
        final registeredDeviceId = driverData['device_id']?.toString();
        
        if (registeredDeviceId != null && 
            registeredDeviceId.isNotEmpty && 
            registeredDeviceId != 'unknown' &&
            registeredDeviceId != currentDeviceId) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const DeviceBlockedScreen(),
            ),
          );
          return;
        }
        
        if (registeredDeviceId == null || registeredDeviceId.isEmpty || registeredDeviceId == 'unknown') {
          await ApiService.updateDriverDeviceId(driverId, currentDeviceId);
        }
        
        await _checkAndUpdateFcmToken(driverId, driverData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', phoneNumber);
        await prefs.setString('driverId', driverId);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isKycSubmitted', true);
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        if (!mounted) return;
        Navigator.pushNamed(context, '/registration', arguments: phoneNumber);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
