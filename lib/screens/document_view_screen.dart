import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/common/custom_app_bar.dart';
import '../constants/app_colors.dart';

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
        'License Front': prefs.getString('license_front_path') ?? '',
        'License Back': prefs.getString('license_back_path') ?? '',
        'Aadhaar Front': prefs.getString('aadhaar_front_path') ?? '',
        'Aadhaar Back': prefs.getString('aadhaar_back_path') ?? '',
        'Vehicle Photo': prefs.getString('vehicle_photo_path') ?? '',
        'RC Front': prefs.getString('rc_front_path') ?? '',
        'RC Back': prefs.getString('rc_back_path') ?? '',
      };
    });
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
                      child: Image.file(
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(
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