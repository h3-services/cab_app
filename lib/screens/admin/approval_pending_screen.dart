import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
class ApprovalPendingScreen extends StatefulWidget {
  const ApprovalPendingScreen({super.key});
  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}
class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _driverProfileData;
  Timer? _autoReloadTimer;
  /// Save all driver and vehicle data to SharedPreferences
  Future<void> _saveDriverDataToPrefs(
      SharedPreferences prefs, Map<String, dynamic> driverData) async {
    // Driver personal data
    if (driverData['name'] != null)
      await prefs.setString('name', driverData['name'].toString());
    if (driverData['email'] != null)
      await prefs.setString('email', driverData['email'].toString());
    if (driverData['phone_number'] != null)
      await prefs.setString(
          'phoneNumber', driverData['phone_number'].toString());
    if (driverData['primary_location'] != null)
      await prefs.setString(
          'primaryLocation', driverData['primary_location'].toString());
    if (driverData['licence_number'] != null)
      await prefs.setString(
          'licenseNumber', driverData['licence_number'].toString());
    if (driverData['aadhar_number'] != null)
      await prefs.setString(
          'aadhaarNumber', driverData['aadhar_number'].toString());
    if (driverData['licence_expiry'] != null)
      await prefs.setString(
          'licenceExpiry', driverData['licence_expiry'].toString());
    if (driverData['driver_id'] != null)
      await prefs.setString('driverId', driverData['driver_id'].toString());
    else if (driverData['id'] != null)
      await prefs.setString('driverId', driverData['id'].toString());
    // Vehicle data
    final vehicle = driverData['vehicle'];
    if (vehicle != null && vehicle is Map) {
      if (vehicle['vehicle_id'] != null)
        await prefs.setString('vehicleId', vehicle['vehicle_id'].toString());
      else if (vehicle['id'] != null)
        await prefs.setString('vehicleId', vehicle['id'].toString());
      if (vehicle['vehicle_type'] != null)
        await prefs.setString(
            'vehicleType', vehicle['vehicle_type'].toString());
      if (vehicle['vehicle_brand'] != null)
        await prefs.setString(
            'vehicleBrand', vehicle['vehicle_brand'].toString());
      else if (vehicle['brand'] != null)
        await prefs.setString('vehicleBrand', vehicle['brand'].toString());
      if (vehicle['vehicle_model'] != null)
        await prefs.setString(
            'vehicleModel', vehicle['vehicle_model'].toString());
      else if (vehicle['model'] != null)
        await prefs.setString('vehicleModel', vehicle['model'].toString());
      if (vehicle['vehicle_number'] != null)
        await prefs.setString(
            'vehicleNumber', vehicle['vehicle_number'].toString());
      if (vehicle['vehicle_color'] != null)
        await prefs.setString(
            'vehicleColor', vehicle['vehicle_color'].toString());
      else if (vehicle['color'] != null)
        await prefs.setString('vehicleColor', vehicle['color'].toString());
      if (vehicle['seating_capacity'] != null)
        await prefs.setString(
            'seatingCapacity', vehicle['seating_capacity'].toString());
      if (vehicle['rc_expiry_date'] != null)
        await prefs.setString(
            'rcExpiryDate', vehicle['rc_expiry_date'].toString());
      if (vehicle['fc_expiry_date'] != null)
        await prefs.setString(
            'fcExpiryDate', vehicle['fc_expiry_date'].toString());
    }
    }
  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? driverId = prefs.getString('driverId');
      if (driverId != null) {
        final driverData = await ApiService.getDriverDetails(driverId);
        final bool isApproved = driverData['is_approved'] == true;
        final String kycVerified =
            (driverData['kyc_verified'] ?? '').toString().toLowerCase();
        // If vehicle data not in driver response, fetch it separately
        if (driverData['vehicle'] == null ||
            (driverData['vehicle'] is Map &&
                (driverData['vehicle'] as Map).isEmpty)) {
          final String? vehicleId = prefs.getString('vehicleId');
          if (vehicleId != null && vehicleId.isNotEmpty) {
            final vehicleData = await ApiService.getVehicleByDriverId(driverId);
            if (vehicleData != null) {
              driverData['vehicle'] = vehicleData;
              }
          }
        }
        _driverProfileData = driverData;
        // Save all driver and vehicle data to SharedPreferences for persistence
        await _saveDriverDataToPrefs(prefs, driverData);
        if (kycVerified == 'rejected') {
          List<String> errorFields = [];
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
          // Directly navigate to fix issues instead of showing rejection screen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Application Rejected. Please fix the issues.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
            // Navigate directly to personal details to fix issues
            _navigateToFixIssues(errorFields);
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
          // Removed snackbar
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
  /// Navigate directly to personal details to fix rejected issues
  Future<void> _navigateToFixIssues(List<String> errorFields) async {
    // Stop auto-reload timer before navigating
    _autoReloadTimer?.cancel();
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
      'vehicleBrand': vVal('vehicle_brand', 'vehicleBrand') == ''
          ? vVal('brand', 'vehicleBrand')
          : vVal('vehicle_brand', 'vehicleBrand'),
      'vehicleModel': vVal('vehicle_model', 'vehicleModel') == ''
          ? vVal('model', 'vehicleModel')
          : vVal('vehicle_model', 'vehicleModel'),
      'vehicleNumber': vVal('vehicle_number', 'vehicleNumber'),
      'vehicleColor': vVal('vehicle_color', 'vehicleColor') == ''
          ? vVal('color', 'vehicleColor')
          : vVal('vehicle_color', 'vehicleColor'),
      'seatingCapacity': vVal('seating_capacity', 'seatingCapacity'),
      'rcExpiryDate': vVal('rc_expiry_date', 'rcExpiryDate'),
      'fcExpiryDate': vVal('fc_expiry_date', 'fcExpiryDate'),
      'errorFields': errorFields,
    };
    if (mounted) {
      // Navigate to personal-details to fix the rejected issues
      Navigator.pushReplacementNamed(context, '/personal-details',
          arguments: args);
    }
  }
  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Auto-reload every 2 seconds
    _autoReloadTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkStatus();
    });
    // Listen for foreground FCM messages to trigger status check
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;
      if (type == 'REGISTRATION_APPROVED' || type == 'REGISTRATION_REJECTED') {
        _checkStatus();
      }
    });
  }
  @override
  void dispose() {
    _autoReloadTimer?.cancel();
    super.dispose();
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: false,
        showMenuIcon: false,
        showProfileIcon: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
        ],
      ),
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
                      // Only show pending approval UI (rejection auto-navigates away)
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
                      const SizedBox(height: 20),
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
                        onPressed: _handleUpdateApplication,
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
  /// Navigate to Personal Details screen to review/update all AI-entered data
  Future<void> _handleUpdateApplication() async {
    _autoReloadTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    
    final String? driverId = prefs.getString('driverId');
    if (driverId != null && driverId.isNotEmpty) {
      try {
        final driver = await ApiService.getDriverDetails(driverId);
        
        // Fetch vehicle separately
        Map<String, dynamic> vehicle = {};
        try {
          final vehicleData = await ApiService.getVehicleByDriverId(driverId);
          if (vehicleData != null) {
            vehicle = vehicleData;
          }
        } catch (e) {
          vehicle = driver['vehicle'] ?? {};
        }
        
        await _saveDriverDataToPrefs(prefs, {...driver, 'vehicle': vehicle});
        
        final Map<String, dynamic> args = {
          'isEditing': true,
          'driverId': driver['driver_id']?.toString() ?? driver['id']?.toString() ?? '',
          'vehicleId': vehicle['vehicle_id']?.toString() ?? vehicle['id']?.toString() ?? '',
          'name': driver['name']?.toString() ?? '',
          'email': driver['email']?.toString() ?? '',
          'phoneNumber': driver['phone_number']?.toString() ?? '',
          'primaryLocation': driver['primary_location']?.toString() ?? '',
          'licenceNumber': driver['licence_number']?.toString() ?? '',
          'aadharNumber': driver['aadhar_number']?.toString() ?? '',
          'licenceExpiry': driver['licence_expiry']?.toString() ?? '',
          'vehicleType': vehicle['vehicle_type']?.toString() ?? '',
          'vehicleBrand': vehicle['vehicle_brand']?.toString() ?? vehicle['brand']?.toString() ?? '',
          'vehicleModel': vehicle['vehicle_model']?.toString() ?? vehicle['model']?.toString() ?? '',
          'vehicleNumber': vehicle['vehicle_number']?.toString() ?? '',
          'vehicleColor': vehicle['vehicle_color']?.toString() ?? vehicle['color']?.toString() ?? '',
          'seatingCapacity': vehicle['seating_capacity']?.toString() ?? '4',
          'rcExpiryDate': vehicle['rc_expiry_date']?.toString() ?? '',
          'fcExpiryDate': vehicle['fc_expiry_date']?.toString() ?? '',
          'errorFields': [],
        };
        
        if (mounted) {
          Navigator.pushNamed(context, '/personal-details', arguments: args);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pushNamed(context, '/personal-details', arguments: {
            'isEditing': true,
            'driverId': prefs.getString('driverId') ?? '',
            'vehicleId': prefs.getString('vehicleId') ?? '',
            'name': prefs.getString('name') ?? '',
            'email': prefs.getString('email') ?? '',
            'phoneNumber': prefs.getString('phoneNumber') ?? '',
            'primaryLocation': prefs.getString('primaryLocation') ?? '',
            'licenceNumber': prefs.getString('licenseNumber') ?? '',
            'aadharNumber': prefs.getString('aadhaarNumber') ?? '',
            'licenceExpiry': prefs.getString('licenceExpiry') ?? '',
            'vehicleType': prefs.getString('vehicleType') ?? '',
            'vehicleBrand': prefs.getString('vehicleBrand') ?? '',
            'vehicleModel': prefs.getString('vehicleModel') ?? '',
            'vehicleNumber': prefs.getString('vehicleNumber') ?? '',
            'vehicleColor': prefs.getString('vehicleColor') ?? '',
            'seatingCapacity': prefs.getString('seatingCapacity') ?? '4',
            'rcExpiryDate': prefs.getString('rcExpiryDate') ?? '',
            'fcExpiryDate': prefs.getString('fcExpiryDate') ?? '',
            'errorFields': [],
          });
        }
      }
    }
  }
}
