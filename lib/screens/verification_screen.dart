import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import '../widgets/widgets.dart';
import '../services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  String? phoneNumber;

  void _showDeviceLockedDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Device Locked'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

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
                  onPressed: _isLoading ? null : () async {
                    String otp = _controllers.map((controller) => controller.text).join();
                    if (otp.length == 4 && phoneNumber != null) {
                      setState(() {
                        _isLoading = true;
                      });
                      
                      try {
                        // First check device compatibility
                        Map<String, dynamic> deviceResult = await AuthService.checkDeviceCompatibility(phoneNumber!);
                        
                        if (!deviceResult['success']) {
                          setState(() {
                            _isLoading = false;
                          });
                          _showDeviceLockedDialog(context, deviceResult['message']);
                          return;
                        }
                        
                        // If device is compatible, proceed with OTP verification
                        Map<String, dynamic> result = await AuthService.verifyOTPAndProceed(
                          phoneNumber!,
                          otp,
                        );
                        
                        setState(() {
                          _isLoading = false;
                        });
                        
                        if (result['success']) {
                          if (result['action'] == 'login') {
                            Navigator.pushReplacementNamed(context, '/dashboard');
                          } else if (result['action'] == 'register') {
                            Navigator.pushNamed(
                              context, 
                              '/personal_details',
                              arguments: phoneNumber,
                            );
                          }
                        } else {
                          if (result['action'] == 'blocked') {
                            _showDeviceLockedDialog(context, result['message']);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message']),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
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
                        const SnackBar(content: Text('Please enter complete OTP')),
                      );
                    }
                  },
                ),
                SizedBox(height:90),
                ],
              ),
            ),
          ),
        ),
      )
    );
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