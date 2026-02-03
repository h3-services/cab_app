import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/common/custom_app_bar.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

class DocumentViewScreen extends StatefulWidget {
  const DocumentViewScreen({super.key});

  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  Map<String, String> _personalDetails = {};
  Map<String, String> _vehicleDetails = {};
  Map<String, String> _documentPaths = {};

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId');
    
    // Load cached data first
    setState(() {
      _personalDetails = {
        'Name': prefs.getString('name') ?? 'Not provided',
        'Phone Number': prefs.getString('phoneNumber') ?? 'Not provided',
        'Email': prefs.getString('email') ?? 'Not provided',
        'Primary Location': prefs.getString('primaryLocation') ?? 'Not provided',
        'License Number': prefs.getString('licenseNumber') ?? 'Not provided',
        'Aadhaar Number': prefs.getString('aadhaarNumber') ?? 'Not provided',
      };

      _vehicleDetails = {
        'Vehicle Type': prefs.getString('vehicleType') ?? 'Not provided',
        'Vehicle Brand': prefs.getString('vehicleBrand') ?? 'Not provided',
        'Vehicle Model': prefs.getString('vehicleModel') ?? 'Not provided',
        'Vehicle Number': prefs.getString('vehicleNumber') ?? 'Not provided',
        'Vehicle Color': prefs.getString('vehicleColor') ?? 'Not provided',
        'Seating Capacity': prefs.getString('seatingCapacity') ?? 'Not provided',
      };

      _documentPaths = {
        'Profile Photo': prefs.getString('profile_photo_path') ?? '',
        'Vehicle Photo': prefs.getString('vehicle_photo_path') ?? '',
      };
    });
    
    // Fetch fresh data from API if driver ID exists
    if (driverId != null) {
      try {
        final driverData = await ApiService.getDriverDetails(driverId);
        
        // Update personal details from API
        setState(() {
          _personalDetails = {
            'Name': driverData['name'] ?? 'Not provided',
            'Phone Number': driverData['phone_number'] ?? 'Not provided',
            'Email': driverData['email'] ?? 'Not provided',
            'Primary Location': driverData['primary_location'] ?? 'Not provided',
            'License Number': driverData['licence_number'] ?? 'Not provided',
            'Aadhaar Number': driverData['aadhar_number'] ?? 'Not provided',
            'License Expiry': driverData['licence_expiry'] ?? 'Not provided',
            'KYC Status': driverData['kyc_verified'] ?? 'Not verified',
            'Approval Status': (driverData['is_approved'] == true) ? 'Approved' : 'Pending',
          };
        });
        
        // Update vehicle details from cached data
        final vehicleData = await ApiService.getVehicleByDriverId(driverId);
        if (vehicleData != null) {
          setState(() {
            _vehicleDetails = {
              'Vehicle Type': vehicleData['vehicle_type'] ?? 'Not provided',
              'Vehicle Brand': vehicleData['vehicle_brand'] ?? 'Not provided',
              'Vehicle Model': vehicleData['vehicle_model'] ?? 'Not provided',
              'Vehicle Number': vehicleData['vehicle_number'] ?? 'Not provided',
              'Vehicle Color': vehicleData['vehicle_color'] ?? 'Not provided',
              'Seating Capacity': (vehicleData['seating_capacity'] ?? 'Not provided').toString(),
              'RC Expiry': vehicleData['rc_expiry_date'] ?? 'Not provided',
              'FC Expiry': vehicleData['fc_expiry_date'] ?? 'Not provided',
            };
          });
        }
        
        // Update document URLs from cached vehicle data
        Map<String, String> apiDocuments = {
          'Profile Photo': driverData['photo_url'] ?? '',
          'License Document': driverData['licence_url'] ?? '',
          'Aadhaar Document': driverData['aadhar_url'] ?? '',
        };
        
        if (vehicleData != null) {
          apiDocuments.addAll({
            'Vehicle Photo': vehicleData['vehicle_front_url'] ?? '',
            'RC Document': vehicleData['rc_book_url'] ?? '',
            'FC Document': vehicleData['fc_certificate_url'] ?? '',
            'Vehicle Back': vehicleData['vehicle_back_url'] ?? '',
            'Vehicle Left': vehicleData['vehicle_left_url'] ?? '',
            'Vehicle Right': vehicleData['vehicle_right_url'] ?? '',
            'Vehicle Inside': vehicleData['vehicle_inside_url'] ?? '',
          });
        }
        
        // Merge with local paths, prioritizing API URLs
        setState(() {
          _documentPaths = {
            ..._documentPaths,
            ...apiDocuments,
          };
        });
        
      } catch (e) {
        debugPrint('Error fetching driver details: $e');
        // Continue with cached data if API fails
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appGradientEnd,
      appBar: CustomAppBar(
        title: 'Document View',
        showBackButton: true,
        showProfileIcon: false,
        showMenuIcon: false,
        onBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Personal Details', _personalDetails),
            const SizedBox(height: 20),
            _buildSection('Vehicle Details', _vehicleDetails),
            const SizedBox(height: 20),
            _buildDocumentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Map<String, String> details) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...details.entries.map((entry) => _buildDetailRow(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSection() {
    return Container(
      width: double.infinity,
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
            'KYC Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _documentPaths.length,
            itemBuilder: (context, index) {
              final entry = _documentPaths.entries.elementAt(index);
              return _buildDocumentCard(entry.key, entry.value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String title, String imagePath) {
    final bool hasImage = imagePath.isNotEmpty;
    final bool isNetworkImage = imagePath.startsWith('http');
    
    return GestureDetector(
      onTap: hasImage ? () => _showFullScreenImage(imagePath, title) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: hasImage
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: isNetworkImage
                          ? Image.network(
                              imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            )
                          : Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                    )
                  : const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey,
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasImage ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasImage ? 'Uploaded' : 'Not uploaded',
                    style: TextStyle(
                      fontSize: 10,
                      color: hasImage ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imagePath, String title) {
    final bool isNetworkImage = imagePath.startsWith('http');
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: isNetworkImage
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text(
                            'Error loading image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                      )
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text(
                            'Error loading image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}