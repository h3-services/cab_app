import 'package:flutter/material.dart';
import 'dart:async';

import 'dart:async';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Wait for 3 seconds for branding
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final String? driverId = prefs.getString('driverId');
    final bool isKycSubmitted = prefs.getBool('isKycSubmitted') ?? false;

    if (driverId != null && driverId.isNotEmpty) {
      if (isKycSubmitted) {
        try {
          // Check Status from API
          final driverData = await ApiService.getDriverDetails(driverId);
          final bool isApproved = driverData['is_approved'] ?? false;
          final String kycVerified = driverData['kyc_verified'] ?? 'pending';

          if (isApproved && kycVerified == 'verified') {
            if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            if (mounted)
              Navigator.pushReplacementNamed(context, '/approval-pending');
          }
        } catch (e) {
          debugPrint('Status Check Failed: $e');
          // Fallback: If network fails, what to do?
          // If strict: Approval Pending.
          // If relaxed: Dashboard (Offline Mode).
          // User requested strict "don't show main screen if not approved".
          // So pending is safer fallback for "unknown" status?
          // But offline usage requires Dashboard.
          // I will loop to ApprovalPending for now as it's safer for "not approved" logic.
          if (mounted)
            Navigator.pushReplacementNamed(context, '/approval-pending');
        }
      } else {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    } else {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
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
            colors: [
              Color(0xFFE8E8E8),
              Color(0xFF808080),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chola Cabs Logo
              Image.asset(
                'assets/images/chola_cabs_logo.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
