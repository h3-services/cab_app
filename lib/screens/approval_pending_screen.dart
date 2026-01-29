import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/api_service.dart';
import '../constants/error_codes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ApprovalPendingScreen extends StatefulWidget {
  const ApprovalPendingScreen({super.key});

  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  bool _isLoading = false;
  bool _isRejected = false;
  List<String> _errorMessages = [];
  List<String> _errorFields = [];
  Timer? _autoReloadTimer;

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _isRejected = false;
      _errorMessages = [];
      _errorFields = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? driverId = prefs.getString('driverId');

      if (driverId != null) {
        final driverData = await ApiService.getDriverDetails(driverId);
        final bool isApproved = driverData['is_approved'] == true;
        final String kycVerified =
            (driverData['kyc_verified'] ?? '').toString().toLowerCase();

        debugPrint(
            "Status Check: isApproved=$isApproved, kycStatus=$kycVerified");

        if (kycVerified == 'rejected') {
          List<String> errorFields = [];
          if (driverData['errors'] != null &&
              driverData['errors']['details'] != null) {
            final Map<String, dynamic> details =
                driverData['errors']['details'];
            details.forEach((code, errorData) {
              int codeInt = int.tryParse(code) ?? 0;
              _errorMessages.add(ErrorCodes.getMessage(codeInt));

              if (codeInt >= 1001 && codeInt <= 1003) {
                errorFields.add('Driving License');
              } else if (codeInt >= 1004 && codeInt <= 1005) {
                errorFields.add('Aadhaar Card');
              } else if (codeInt == 1006) {
                errorFields.add('Profile Picture');
              } else if (codeInt >= 1007 && codeInt <= 1008) {
                errorFields.add('RC Book');
              } else if (codeInt >= 1009 && codeInt <= 1010) {
                errorFields.add('FC Certificate');
              } else if (codeInt == 1011 || codeInt == 1013 || codeInt == 1014 || codeInt == 1015) {
                errorFields.addAll(['Front View', 'Back View', 'Left Side View', 'Right Side View']);
              } else if (codeInt >= 2001 && codeInt <= 2008) {
                errorFields.add('Personal Details');
              } else if (codeInt >= 3001 && codeInt <= 3008) {
                errorFields.add('Vehicle Details');
              }
            });
          }

          if (mounted) {
            final Map<String, dynamic> args = {
              'isEditing': true,
              'driverId': driverId,
              'vehicleId': prefs.getString('vehicleId'),
              'name': driverData['name'],
              'email': driverData['email'],
              'phoneNumber': driverData['phone_number'],
              'primaryLocation': driverData['primary_location'],
              'licenceNumber': driverData['licence_number'],
              'aadharNumber': driverData['aadhar_number'],
              'licenceExpiry': driverData['licence_expiry'],
              'vehicleType': prefs.getString('vehicleType'),
              'vehicleBrand': prefs.getString('vehicleBrand'),
              'vehicleModel': prefs.getString('vehicleModel'),
              'vehicleNumber': prefs.getString('vehicleNumber'),
              'vehicleColor': prefs.getString('vehicleColor'),
              'seatingCapacity': prefs.getString('seatingCapacity'),
              'rcExpiryDate': prefs.getString('rcExpiryDate'),
              'fcExpiryDate': prefs.getString('fcExpiryDate'),
              'errorFields': errorFields,
            };

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Application Rejected. Please fix errors.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.pushReplacementNamed(context, '/kyc_upload',
                arguments: args);
          }
          return;
        } else if (isApproved &&
            (kycVerified == 'verified' || kycVerified == 'approved')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Account Approved!'),
                  backgroundColor: Colors.green),
            );
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Still Pending Approval...')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('404')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          Navigator.pushNamedAndRemoveUntil(
              context, '/login', (route) => false);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleFixErrors() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> args = {
      'isEditing': true,
      'driverId': prefs.getString('driverId'),
      'vehicleId': prefs.getString('vehicleId'),
      'name': prefs.getString('name'),
      'email': prefs.getString('email'),
      'phoneNumber': prefs.getString('phoneNumber'),
      'primaryLocation': prefs.getString('primaryLocation'),
      'licenceNumber': prefs.getString('licenseNumber'),
      'aadharNumber': prefs.getString('aadhaarNumber'),
      'licenceExpiry': prefs.getString('licenceExpiry'),
      'vehicleType': prefs.getString('vehicleType'),
      'vehicleBrand': prefs.getString('vehicleBrand'),
      'vehicleModel': prefs.getString('vehicleModel'),
      'vehicleNumber': prefs.getString('vehicleNumber'),
      'vehicleColor': prefs.getString('vehicleColor'),
      'seatingCapacity': prefs.getString('seatingCapacity'),
      'rcExpiryDate': prefs.getString('rcExpiryDate'),
      'fcExpiryDate': prefs.getString('fcExpiryDate'),
      'errorFields': _errorFields,
    };

    if (mounted) {
      Navigator.pushNamed(context, '/kyc_upload', arguments: args);
    }
  }

  @override
  void initState() {
    super.initState();
    _startAutoReload();
  }

  @override
  void dispose() {
    _autoReloadTimer?.cancel();
    super.dispose();
  }

  void _startAutoReload() {
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) {
        _checkStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
          showBackButton: false, showMenuIcon: false, showProfileIcon: false),
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/chola_cabs_logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),
                const Text(
                  'Approval Pending',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Image.asset(
                    'assets/images/approved.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isRejected) ...{
                  const Text(
                    'Application Rejected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Please fix the following issues to proceed:',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: _errorMessages
                          .map((msg) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        msg,
                                        style: const TextStyle(
                                            color: Colors.red, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleFixErrors,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                    ),
                    child: const Text('Fix Issues Now'),
                  ),
                  const SizedBox(height: 10),
                } else
                  const Text(
                    'Your documents have been submitted successfully.\nThey are currently under review by the admin.\nYou will be notified once your account is approved.\nPlease wait while the verification is completed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/personal-details',
                        arguments: {'isEditing': true});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                  ),
                  child: const Text('Update Application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
