import 'package:flutter/material.dart';
import 'dart:math' as math;

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({Key? key}) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        leading: const Icon(Icons.signal_cellular_4_bar, color: Colors.white, size: 16),
        title: Row(
          children: [
            const Icon(Icons.wifi, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            const Icon(Icons.battery_full, color: Colors.white, size: 16),
            const Spacer(),
            const Text(
              '2:41',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, color: Colors.white, size: 16),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE0E0E0),
              Color(0xFF9E9E9E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App title
                const Text(
                  'Driver app',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Logo section
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Circular logo
                        Container(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Mountain icon in center
                              Container(
                                width: 60,
                                height: 40,
                                child: CustomPaint(
                                  painter: MountainPainter(),
                                ),
                              ),
                              // Circular text
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CircularTextPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        // TAXI SERVICES text
                        const Text(
                          'TAXI SERVICES',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Travel with us text
                        const Text(
                          'Travel with us',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB8860B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // OTP Verification section
                const Text(
                  'OTP Verification',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Enter email and phone number to\nsend one time Password',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Phone number input
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91',
                      hintStyle: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Description text
                const Text(
                  'Fast, secure verification for a smooth journey.\nEnter your number to receive an OTP.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle continue action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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
}

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Draw mountain silhouette
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.65, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CircularTextPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    const textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Color(0xFF8B4513),
    );

    // Draw "CHOLA CABS" in circular pattern
    _drawTextOnCircle(canvas, 'CHOLA CABS', center, radius, textStyle, -1.5);
  }

  void _drawTextOnCircle(Canvas canvas, String text, Offset center, double radius, TextStyle style, double startAngle) {
    final angleStep = 6.28 / text.length; // 2π divided by text length
    
    for (int i = 0; i < text.length; i++) {
      final angle = startAngle + (i * angleStep);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + 1.57); // π/2 to rotate text upright
      
      final textPainter = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}