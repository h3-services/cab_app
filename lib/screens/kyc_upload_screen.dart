import 'package:flutter/material.dart';
import '../services/image_picker_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/user_service.dart';
import '../constants/app_colors.dart';
import '../widgets/widgets.dart';
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
  final Map<String, String> _imageUrls = {};
  Map<String, dynamic>? userData;
  bool _isSubmitting = false;

  bool get _allDocumentsUploaded => _uploadedDocuments.values.every((uploaded) => uploaded);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showBackButton: true),
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
            Icon(
              Icons.verified_user,
              size: 60,
              color: _allDocumentsUploaded ? AppColors.greenLight : const Color(0xFF424242),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload KYC Documents',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    if (_allDocumentsUploaded && userData != null) {
                      setState(() {
                        _isSubmitting = true;
                      });
                      
                      try {
                        for (String docType in _uploadedImages.keys) {
                          if (_uploadedImages[docType] != null) {
                            String imageUrl = await FirebaseStorageService.uploadImage(
                              _uploadedImages[docType]!,
                              '${userData!['phoneNumber']}/$docType',
                            );
                            _imageUrls[docType] = imageUrl;
                          }
                        }
                        
                        bool success = await UserService.createUser(
                          phoneNumber: userData!['phoneNumber'],
                          name: userData!['name'],
                          email: userData!['email'],
                          licenseNumber: userData!['licenseNumber'],
                          aadhaarNumber: userData!['aadhaarNumber'],
                          vehicleType: userData!['vehicleType'],
                          vehicleNumber: userData!['vehicleNumber'],
                          vehicleBrand: userData!['vehicleBrand'],
                          vehicleModel: userData!['vehicleModel'],
                          vehicleColor: userData!['vehicleColor'],
                          numberOfSeats: userData!['numberOfSeats'],
                          imageUrls: _imageUrls,
                        );
                        
                        setState(() {
                          _isSubmitting = false;
                        });
                        
                        if (success) {
                          Navigator.pushReplacementNamed(context, '/approval-pending');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to submit documents. Please try again.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _isSubmitting = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please upload all required documents'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allDocumentsUploaded ? AppColors.greenLight : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Documents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
        File? image = await ImagePickerService.showImageSourceDialog(context);
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
          color: isUploaded ? AppColors.greenLight.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUploaded ? AppColors.greenLight : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isUploaded ? AppColors.greenLight : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isUploaded ? AppColors.greenLight : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload,
              color: isUploaded ? AppColors.greenLight : Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}