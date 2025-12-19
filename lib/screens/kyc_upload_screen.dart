import 'package:flutter/material.dart';
import 'kyc_complete_screen.dart';
import '../services/image_picker_service.dart';
import 'dart:io';

class KycUploadScreen extends StatefulWidget {
  const KycUploadScreen({super.key});

  @override
  State<KycUploadScreen> createState() => _KycUploadScreenState();
}

class _KycUploadScreenState extends State<KycUploadScreen> {
  final Map<String, bool> _uploadedDocuments = {
    'Driving License': false,
    'Aadhaar Card': false,
    'Profile Picture': false,
    'RC Book': false,
    'FC Certificate': false,
    'Front View': false,
    'Back View': false,
    'Left Side View': false,
    'Right Side View': false,
  };
  
  final Map<String, File?> _uploadedImages = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF424242),
        title: const Text(
          'CHOLA CABS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Shield Icon
            const Icon(
              Icons.verified_user,
              size: 60,
              color: Color(0xFF424242),
            ),
            const SizedBox(height: 20),
            // Title
            const Text(
              'Upload KYC Documents',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            const Text(
              'Upload your documents to activate your account',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Required Documents Card
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Required Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildUploadItem('Driving License', 'Upload a clear photo of your driving license', Icons.credit_card),
                          const SizedBox(height: 12),
                          _buildUploadItem('Aadhaar Card', 'Upload a clear photo of your Aadhaar card', Icons.credit_card),
                          const SizedBox(height: 12),
                          _buildUploadItem('Profile Picture', 'Upload a recent profile photo', Icons.person),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vehicle Details Card
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildUploadItem('RC Book', 'Upload a clear photo of your vehicle RC', Icons.description),
                          const SizedBox(height: 12),
                          _buildUploadItem('FC Certificate', 'Upload valid vehicle fitness certificate', Icons.description),
                          const SizedBox(height: 12),
                          _buildUploadItem('Front View', 'Upload the front view of your car', Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem('Back View', 'Upload the rear side of your car', Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem('Left Side View', 'Upload the left side of your car', Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem('Right Side View', 'Upload the right side of your car', Icons.directions_car),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            // Submit Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    bool allUploaded = _uploadedDocuments.values.every((uploaded) => uploaded);
                    if (allUploaded) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const KycCompleteScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please upload all required documents')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF616161),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Submit for Verification',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadItem(String title, String subtitle, IconData icon) {
    bool isUploaded = _uploadedDocuments[title] ?? false;
    return GestureDetector(
      onTap: () async {
        final image = await ImagePickerService.showImageSourceDialog(context);
        if (image != null) {
          setState(() {
            _uploadedDocuments[title] = true;
            _uploadedImages[title] = image;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title uploaded successfully')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: isUploaded ? const Color(0xFF4CAF50) : Colors.grey.shade300,
            width: isUploaded ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            isUploaded
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.cloud_upload_outlined,
                    size: 24,
                    color: Colors.grey.shade600,
                  ),
          ],
        ),
      ),
    );
  }
}