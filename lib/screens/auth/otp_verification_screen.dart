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
      
      final response = await ApiService.checkPhoneExists(widget.phoneNumber);
      
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
            MaterialPageRoute(builder: (context) => const DeviceBlockedScreen()),
          );
          return;
        }
        
        if (registeredDeviceId == null || registeredDeviceId.isEmpty || registeredDeviceId == 'unknown') {
          await ApiService.updateDriverDeviceId(driverId, currentDeviceId);
        }
        
        await _checkAndUpdateFcmToken(driverId, driverData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', widget.phoneNumber);
        await prefs.setString('driverId', driverId);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('isKycSubmitted', true);
        
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        if (!mounted) return;
        Navigator.pushNamed(context, '/registration', arguments: widget.phoneNumber);
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid OTP'),
          content: const Text('The OTP you entered is incorrect. Please try again.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.appGradientStart, AppColors.appGradientEnd],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Enter OTP',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to +91${widget.phoneNumber}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey[300],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ),
              ],
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
