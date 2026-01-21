import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      // Reset states
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
          // Parse errors
          List<String> errorFields = [];
          if (driverData['errors'] != null &&
              driverData['errors']['details'] != null) {
            final Map<String, dynamic> details =
                driverData['errors']['details'];
            details.forEach((code, errorData) {
              int codeInt = int.tryParse(code) ?? 0;
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
              } else if (codeInt == 1011) {
                errorFields.add('Front View');
                errorFields.add('Back View');
                errorFields.add('Left Side View');
                errorFields.add('Right Side View');
              } else if (codeInt == 2000) {
                errorFields.add('Name');
              } else if (codeInt == 2001) {
                errorFields.add('Phone Number');
              } else if (codeInt == 2002) {
                errorFields.add('Email');
              } else if (codeInt == 2003) {
                errorFields.add('Personal Details');
              } else if (codeInt == 3001) {
                errorFields.add('Vehicle Number');
              }
            });
          }

          if (mounted) {
            // Construct args for KycUploadScreen
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
              // Vehicle details fallback to prefs
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

    // Prepare data map for KycUploadScreen
    final Map<String, dynamic> args = {
      'isEditing': true,
      'driverId': prefs.getString('driverId'),
      'vehicleId':
          prefs.getString('vehicleId'), // Important for vehicle updates
      // Pass other fields from prefs if available to avoid empty fields in update
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

      'errorFields': _errorFields, // Pass the errors!
    };

    if (mounted) {
      Navigator.pushNamed(context, '/kyc_upload', arguments: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
          showBackButton: false, showMenuIcon: false, showProfileIcon: true),
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
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'CHOLA CABS\nTAXI SERVICES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Title
                const Text(
                  'Approval Pending',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),

                // Approval Icon
                Container(
                  width: 200,
                  height: 200,
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
                const SizedBox(height: 40),

                // Message
                // Message
                if (_isRejected) ...[
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
                ] else
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

                // Refresh Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _checkStatus,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh, color: Colors.white),
                  label: Text(_isLoading ? 'Checking...' : 'Check Status',
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/personal-details',
                        arguments: {'isEditing': true});
                  },
                  child: const Text(
                    'Update Application',
                    style: TextStyle(
                      color: Colors.black87,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
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
