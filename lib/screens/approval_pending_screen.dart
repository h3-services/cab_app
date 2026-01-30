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
  Map<String, dynamic>? _driverProfileData;
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

        _driverProfileData = driverData;

        if (kycVerified == 'rejected') {
          List<String> errorFields = [];
          List<String> errorMessages = [];
          setState(() => _isRejected = true);

          final errors = driverData['errors'];
          if (errors != null) {
            Map<String, dynamic>? details;

            if (errors is Map) {
              if (errors['details'] != null && errors['details'] is Map) {
                details = errors['details'];
              } else {
                details = Map<String, dynamic>.from(errors);
                details
                    .remove('details'); // Clean up if it was a nested structure
              }
            }

            if (details != null) {
              details.forEach((code, errorData) {
                int codeInt = int.tryParse(code.toString()) ?? 0;
                if (codeInt > 0) {
                  errorMessages.add(ErrorCodes.getMessage(codeInt));

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
                  } else if (codeInt == 1011 ||
                      codeInt == 1013 ||
                      codeInt == 1014 ||
                      codeInt == 1015 ||
                      codeInt == 1016) {
                    errorFields.addAll([
                      'Front View',
                      'Back View',
                      'Left Side View',
                      'Right Side View',
                      'Inside View'
                    ]);
                  } else if (codeInt == 2002) {
                    errorFields.add('Email');
                  } else if (codeInt == 2003) {
                    errorFields.add('Name');
                  } else if (codeInt == 2004) {
                    errorFields.add('License Number');
                  } else if (codeInt == 2005) {
                    errorFields.add('Aadhaar Number');
                  } else if (codeInt == 2006) {
                    errorFields.add('Primary Location');
                  } else if (codeInt == 2008) {
                    errorFields.add('Driving License Expiry Date');
                  } else if (codeInt == 3001) {
                    errorFields.add('Vehicle Number');
                  } else if (codeInt == 3002) {
                    errorFields.add('Vehicle Type');
                  } else if (codeInt == 3003) {
                    errorFields.add('Vehicle model');
                  } else if (codeInt == 3004) {
                    errorFields.add('Vehicle Make');
                  } else if (codeInt == 3005) {
                    errorFields.add('Vehicle Color');
                  } else if (codeInt == 3006) {
                    errorFields.add('Seating Capacity');
                  } else if (codeInt == 3007) {
                    errorFields.add('RC Expiry Date');
                  } else if (codeInt == 3008) {
                    errorFields.add('FC Expiry Date');
                  }
                }
              });
            }
          }

          if (mounted) {
            debugPrint("Rejection Errors Found: ${errorMessages.length}");
            setState(() {
              _errorFields = errorFields;
              _errorMessages = errorMessages;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Application Rejected. Please fix errors.'),
                backgroundColor: Colors.red,
              ),
            );
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
          if (!mounted) return;
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

    // Use fresh API data if available, otherwise fall back to Prefs
    final driver = _driverProfileData ?? {};
    final vehicle = driver['vehicle'] ?? {};

    // Helper to get value from either source
    String val(String key, String prefKey) {
      return (driver[key] ?? driver[prefKey] ?? prefs.getString(prefKey))
              ?.toString() ??
          '';
    }

    // Vehicle helper
    String vVal(String key, String prefKey) {
      if (vehicle is Map) {
        return (vehicle[key] ?? vehicle[prefKey] ?? prefs.getString(prefKey))
                ?.toString() ??
            '';
      }
      return (prefs.getString(prefKey))?.toString() ?? '';
    }

    final Map<String, dynamic> args = {
      'isEditing': true,
      'driverId': val('driver_id', 'driverId'),
      'vehicleId': vVal('vehicle_id', 'vehicleId'),
      'name': val('name', 'name'),
      'email': val('email', 'email'),
      'phoneNumber': val('phone_number', 'phoneNumber'),
      'primaryLocation': val('primary_location', 'primaryLocation'),
      'licenceNumber': val('licence_number', 'licenseNumber'),
      'aadharNumber': val('aadhaar_number', 'aadhaarNumber'),
      'licenceExpiry': val('licence_expiry_date', 'licenceExpiry'),

      // Vehicle details
      'vehicleType': vVal('vehicle_type', 'vehicleType'),
      'vehicleBrand': vVal('brand', 'vehicleBrand'),
      'vehicleModel': vVal('model', 'vehicleModel'),
      'vehicleNumber': vVal('vehicle_number', 'vehicleNumber'),
      'vehicleColor': vVal('color', 'vehicleColor'),
      'seatingCapacity': vVal('seating_capacity', 'seatingCapacity'),
      'rcExpiryDate': vVal('rc_expiry_date', 'rcExpiryDate'),
      'fcExpiryDate': vVal('fc_expiry_date', 'fcExpiryDate'),

      'errorFields': _errorFields,
    };

    if (mounted) {
      Navigator.pushNamed(context, '/kyc_upload', arguments: args);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkStatus();
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
        width: double.infinity,
        height: double.infinity,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48.0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/chola_cabs_logo.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 30),
                      if (_isRejected) ...[
                        const Icon(
                          Icons.cancel_outlined,
                          size: 70,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!_isRejected) ...[
                        const Text(
                          'Approval Pending',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 180,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Image.asset(
                            'assets/images/approved.png',
                            width: 180,
                            height: 140,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_isRejected) ...[
                        const Text(
                          'Application Rejected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Please fix the following issues to proceed:',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: _errorMessages
                                .map((msg) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.red, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              msg,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12),
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
                                horizontal: 30, vertical: 10),
                          ),
                          child: const Text('Fix Issues Now'),
                        ),
                        const SizedBox(height: 10),
                      ] else
                        const Text(
                          'Your documents have been submitted successfully.\nThey are currently under review by the admin.\nYou will be notified once your account is approved.\nPlease wait while the verification is completed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/personal-details',
                              arguments: {
                                'isEditing': true,
                                'errorFields': _errorFields,
                              });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                        ),
                        child: const Text('Update Application'),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
