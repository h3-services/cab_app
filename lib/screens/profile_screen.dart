import 'package:flutter/material.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/app_drawer.dart';
import '../widgets/bottom_navigation.dart';
import '../constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'document_view_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Personal Details
  String _name = 'Loading...';
  String _phoneNumber = '';
  String _email = '';
  String _primaryLocation = '';
  String _licenseNumber = '';
  String _aadhaarNumber = '';
  String? _profilePhotoPath;
  String? _profilePhotoUrl;

  // Vehicle Details
  String _vehicleType = '';
  String _vehicleBrand = '';
  String _vehicleModel = '';
  String _vehicleNumber = '';
  String _vehicleColor = '';
  String _seatingCapacity = '';

  bool _isApprovedDriver = true; // Default to true, but checked in initState

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? driverId = prefs.getString('driverId');
      if (driverId != null) {
        final driverData = await ApiService.getDriverDetails(driverId);
        final bool isApproved = driverData['is_approved'] == true;
        final String kycVerified =
            (driverData['kyc_verified'] ?? '').toString().toLowerCase();

        if (mounted) {
          setState(() {
            _isApprovedDriver = (isApproved &&
                (kycVerified == 'verified' || kycVerified == 'approved'));
          });
        }
      }
    } catch (e) {
      if (e.toString().contains('404') && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      if (mounted) setState(() => _isApprovedDriver = false);
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId');
    
    // Load cached data first
    setState(() {
      _name = prefs.getString('name') ?? 'Driver';
      _phoneNumber = prefs.getString('phoneNumber') ?? '';
      _email = prefs.getString('email') ?? '';
      _primaryLocation = prefs.getString('primaryLocation') ?? '';
      _licenseNumber = prefs.getString('licenseNumber') ?? '';
      _aadhaarNumber = prefs.getString('aadhaarNumber') ?? '';
      _profilePhotoPath = prefs.getString('profile_photo_path');
      _profilePhotoUrl = prefs.getString('profile_photo_url');
    });
    
    // Fetch fresh data from API if driver ID exists
    if (driverId != null) {
      try {
        final driverData = await ApiService.getDriverDetails(driverId);
        
        // Update personal details
        setState(() {
          _name = driverData['name'] ?? 'Driver';
          _phoneNumber = driverData['phone_number'] ?? '';
          _email = driverData['email'] ?? '';
          _primaryLocation = driverData['primary_location'] ?? '';
          _licenseNumber = driverData['licence_number'] ?? '';
          _aadhaarNumber = driverData['aadhar_number'] ?? '';
          _profilePhotoUrl = driverData['photo_url'];
        });
        
        // Get vehicle details from cached data
        final vehicleData = await ApiService.getVehicleByDriverId(driverId);
        
        // Update vehicle details from cached data
        if (vehicleData != null) {
          setState(() {
            _vehicleType = vehicleData['vehicle_type'] ?? '';
            _vehicleBrand = vehicleData['vehicle_brand'] ?? '';
            _vehicleModel = vehicleData['vehicle_model'] ?? '';
            _vehicleNumber = vehicleData['vehicle_number'] ?? '';
            _vehicleColor = vehicleData['vehicle_color'] ?? '';
            _seatingCapacity = (vehicleData['seating_capacity'] ?? '').toString();
          });
          
          // Store vehicle details in SharedPreferences
          await prefs.setString('vehicleType', _vehicleType);
          await prefs.setString('vehicleBrand', _vehicleBrand);
          await prefs.setString('vehicleModel', _vehicleModel);
          await prefs.setString('vehicleNumber', _vehicleNumber);
          await prefs.setString('vehicleColor', _vehicleColor);
          await prefs.setString('seatingCapacity', _seatingCapacity);
        }
        
        // Store updated personal details
        await prefs.setString('name', _name);
        await prefs.setString('phoneNumber', _phoneNumber);
        await prefs.setString('email', _email);
        await prefs.setString('primaryLocation', _primaryLocation);
        await prefs.setString('licenseNumber', _licenseNumber);
        await prefs.setString('aadhaarNumber', _aadhaarNumber);
        if (_profilePhotoUrl != null) {
          await prefs.setString('profile_photo_url', _profilePhotoUrl!);
        }
      } catch (e) {
        debugPrint('Error fetching driver details: $e');
        // Continue with cached data if API fails
      }
    } else {
      // Load from SharedPreferences if no driver ID
      setState(() {
        _vehicleType = prefs.getString('vehicleType') ?? '';
        _vehicleBrand = prefs.getString('vehicleBrand') ?? '';
        _vehicleModel = prefs.getString('vehicleModel') ?? '';
        _vehicleNumber = prefs.getString('vehicleNumber') ?? '';
        _vehicleColor = prefs.getString('vehicleColor') ?? '';
        _seatingCapacity = prefs.getString('seatingCapacity') ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
            context, '/dashboard', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.appGradientEnd,
        appBar: CustomAppBar(
          showBackButton: true,
          showProfileIcon: false,
          showMenuIcon: false,
          onBack: () => Navigator.pushNamedAndRemoveUntil(
              context, '/dashboard', (route) => false),
        ),
        endDrawer: const AppDrawer(),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    // Curved background
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(150),
                          bottomRight: Radius.circular(150),
                        ),
                      ),
                    ),
                    // Profile content
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 100,
                      child: Column(
                        children: [
                          // Profile image
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: _profilePhotoUrl != null
                                    ? NetworkImage(_profilePhotoUrl!)
                                    : (_profilePhotoPath != null
                                        ? FileImage(File(_profilePhotoPath!))
                                            as ImageProvider
                                        : null),
                                child: (_profilePhotoUrl == null &&
                                        _profilePhotoPath == null)
                                    ? const Icon(Icons.person,
                                        size: 60, color: Colors.grey)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 20, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _primaryLocation.isNotEmpty
                                ? _primaryLocation
                                : 'No Location',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Personal Details Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Mobile Number', _phoneNumber),
                    _buildDetailRow('Email', _email, isLink: true),
                    _buildDetailRow('Aadhaar Number', _aadhaarNumber),
                    _buildDetailRow('Driving License', _licenseNumber),
                  ],
                ),
              ),

              // Vehicle Details and KYC Status Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Details
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vehicle Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Text(
                                  _vehicleType.isNotEmpty
                                      ? _vehicleType
                                      : 'Type',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                Text(
                                  '$_seatingCapacity Seats',
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _vehicleNumber.isNotEmpty
                                  ? _vehicleNumber
                                  : 'NO NUMBER',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildVehicleDetailRow('Make', _vehicleBrand),
                            _buildVehicleDetailRow('Model', _vehicleModel),
                            _buildVehicleDetailRow('Color', _vehicleColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // KYC Status
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KYC Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildKYCItem(
                                'License', 'Verified', Icons.credit_card),
                            const SizedBox(height: 16),
                            _buildKYCItem(
                                'Aadhaar Card', 'Verified', Icons.credit_card),
                            const SizedBox(height: 16),
                            _buildKYCItem('Vehicle Photos', 'Verified',
                                Icons.directions_car),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // View Document Button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.black87, Colors.black54],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DocumentViewScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'View Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        bottomNavigationBar: _isApprovedDriver
            ? const BottomNavigation(currentRoute: '/profile')
            : null,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isLink ? Colors.blue : Colors.black,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKYCItem(String title, String status, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.check_circle, size: 10, color: Colors.green),
          ],
        ),
      ],
    );
  }
}
