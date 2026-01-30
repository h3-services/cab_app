import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/device_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final bool _isLoading = false;
  String? phoneNumber;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    phoneNumber = ModalRoute.of(context)!.settings.arguments as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Back Arrow
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),
                // Chola Cabs Logo
                const Center(
                  child: AppLogo(),
                ),
                const SizedBox(height: 60),
                // Verification Code Title
                const Text(
                  'Verification Code',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                const Text(
                  'We have sent the verification\ncode to your email address',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),
                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return OtpInputField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Resend OTP
                Row(
                  children: [
                    const Text(
                      "Didn't receive OTP ? ",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Handle resend OTP
                      },
                      child: const Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Continue Button
                GradientButton(
                  text: 'Continue',
                  onPressed: _isLoading
                      ? null
                      : () async {
                          String otp = _controllers
                              .map((controller) => controller.text)
                              .join();
                          if (otp.length == 4 && phoneNumber != null) {
                            // 1. PREPARE IDENTIFIERS FOR TERMINAL
                            final combinedDeviceId =
                                await DeviceService.getDeviceId();
                            String? fcmToken;
                            try {
                              fcmToken =
                                  await FirebaseMessaging.instance.getToken();
                            } catch (e) {
                              debugPrint("Notice: FCM Token issue: $e");
                            }

                            // 2. SHOW IN TERMINAL (Requirement)
                            debugPrint(
                                "\n##########################################");
                            debugPrint("IDENTIFIERS READY FOR REGISTRATION:");
                            debugPrint(
                                "DEVICE ID (Hardware): $combinedDeviceId");
                            debugPrint("FCM TOKEN: ${fcmToken ?? 'NULL'}");
                            debugPrint(
                                "##########################################\n");

                            // Save identifiers locally to be used in KYC submission
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('phoneNumber', phoneNumber!);
                            await prefs.setString('fcmToken', fcmToken ?? '');
                            await prefs.setString('deviceId', combinedDeviceId);

                            // Navigate to Personal Details Flow
                            Navigator.pushReplacementNamed(
                                context, '/personal-details',
                                arguments: phoneNumber);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Please enter complete OTP')),
                            );
                          }
                        },
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
