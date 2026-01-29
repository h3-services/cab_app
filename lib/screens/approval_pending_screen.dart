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

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRejected = false;
  List<String> _errorMessages = [];
  List<String> _errorFields = [];
  Timer? _autoReloadTimer;
  bool _isChecking = false;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _animationsInitialized = false;

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;

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
                details.remove('details');
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
          _autoReloadTimer?.cancel();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/dashboard');
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
      _isChecking = false;
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
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _fadeController.forward();
    _scaleController.forward();
    _animationsInitialized = true;
    _checkStatus();
    _startAutoReload();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
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
            if (!_animationsInitialized) {
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
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
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: _errorMessages
                                    .map((msg) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              final prefs = await SharedPreferences.getInstance();
                              final driverId = prefs.getString('driverId');
                              if (driverId != null) {
                                try {
                                  final driverData =
                                      await ApiService.getDriverDetails(driverId);
                                  final vehicleData =
                                      await ApiService.getVehicleByDriver(driverId);
                                  Navigator.pushNamed(context, '/personal_details',
                                      arguments: {
                                        'isEditing': true,
                                        'errorFields': _errorFields,
                                        'driverId': driverId,
                                        'vehicleId': vehicleData['id'],
                                        'name': driverData['name'],
                                        'email': driverData['email'],
                                        'phoneNumber': driverData['phone_number'],
                                        'primaryLocation':
                                            driverData['primary_location'],
                                        'licenceNumber':
                                            driverData['licence_number'],
                                        'aadharNumber':
                                            driverData['aadhar_number'],
                                        'licenceExpiry':
                                            driverData['licence_expiry'],
                                        'vehicleType': vehicleData['vehicle_type'],
                                        'vehicleBrand':
                                            vehicleData['vehicle_brand'],
                                        'vehicleModel':
                                            vehicleData['vehicle_model'],
                                        'vehicleNumber':
                                            vehicleData['vehicle_number'],
                                        'vehicleColor':
                                            vehicleData['vehicle_color'],
                                        'seatingCapacity':
                                            vehicleData['seating_capacity']
                                                ?.toString(),
                                        'rcExpiryDate':
                                            vehicleData['rc_expiry_date'],
                                        'fcExpiryDate':
                                            vehicleData['fc_expiry_date'],
                                      });
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error loading data: $e')),
                                  );
                                }
                              }
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
