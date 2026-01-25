import 'package:flutter/material.dart';
import '../services/image_picker_service.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/widgets.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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
  Map<String, dynamic>? userData;
  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isTestMode = false; // Test Mode Flag
  List<String> _errorFields = [];

  bool get _allDocumentsUploaded =>
      _uploadedDocuments.values.every((uploaded) => uploaded);

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _isInitialized = true;

    userData =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    _isEditing = userData?['isEditing'] == true;

    if (userData?['errorFields'] != null) {
      _errorFields = List<String>.from(userData!['errorFields']);
    }

    if (_isEditing) {
      // Pre-fill as valid since we are updating existing application
      setState(() {
        _uploadedDocuments.updateAll((key, value) => true);

        // If there are error fields, mark them as NOT uploaded so user must re-upload
        for (var field in _errorFields) {
          if (_uploadedDocuments.containsKey(field)) {
            _uploadedDocuments[field] = false;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        showMenuIcon: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Refreshed'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
        onBack: () {
          // If editing (from rejection), we might want to go to personal details or just pop
          // But user requested "if that click person and detail section go"
          // We can navigate to personal details screen
          if (_isEditing) {
            // Pass arguments back if needed, or just pop if it was pushed
            // However, usually going "back" from KYC implies checking Personal Details
            Map<String, dynamic> args =
                Map<String, dynamic>.from(userData ?? {});
            args['isEditing'] = true;
            args['errorFields'] =
                _errorFields; // Explicitly pass the local list
            Navigator.pushReplacementNamed(context, '/personal-details',
                arguments: args);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.appGradientStart,
              AppColors.appGradientEnd,
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.verified_user,
              size: 60,
              color: _allDocumentsUploaded
                  ? AppColors.greenLight
                  : const Color(0xFF424242),
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
            // Test Mode Toggle
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Test Mode (Auto-Fill): "),
                  Switch(
                    value: _isTestMode,
                    onChanged: (val) {
                      setState(() {
                        _isTestMode = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                          _buildUploadItem(
                              'Driving License',
                              'Upload a clear photo of your driving license',
                              Icons.credit_card),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'Aadhaar Card',
                              'Upload a clear photo of your Aadhaar card',
                              Icons.credit_card),
                          const SizedBox(height: 12),
                          _buildUploadItem('Profile Picture',
                              'Upload a recent profile photo', Icons.person),
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
                          _buildUploadItem(
                              'RC Book',
                              'Upload a clear photo of your vehicle RC',
                              Icons.description),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'FC Certificate',
                              'Upload valid vehicle fitness certificate',
                              Icons.description),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'Front View',
                              'Upload the front view of your car',
                              Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'Back View',
                              'Upload the rear side of your car',
                              Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'Left Side View',
                              'Upload the left side of your car',
                              Icons.directions_car),
                          const SizedBox(height: 12),
                          _buildUploadItem(
                              'Right Side View',
                              'Upload the right side of your car',
                              Icons.directions_car),
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
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          // Check if all are uploaded/selected
                          // We check if value is true in _uploadedDocuments (which we set on selection now)
                          bool allSelected = _uploadedDocuments.length == 9 &&
                              _uploadedDocuments.values.every((v) => v);

                          if (allSelected) {
                            _submitAllDocuments();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please upload all required documents'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allDocumentsUploaded
                        ? AppColors.greenLight
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isEditing
                              ? 'Update Application'
                              : 'Submit Documents',
                          style: const TextStyle(
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
    bool isSelected = _uploadedDocuments[title] ?? false;
    File? selectedFile = _uploadedImages[title];
    bool hasError = _errorFields.contains(title) && !isSelected;

    return GestureDetector(
      onTap: () async {
        if (_isTestMode) {
          final List<XFile> images = await ImagePicker().pickMultiImage();
          if (images.isNotEmpty) {
            int index = 0;
            // 1. Assign first image to the clicked item
            if (index < images.length) {
              setState(() {
                _uploadedImages[title] = File(images[index].path);
                _uploadedDocuments[title] = true;
              });
              index++;
            }

            // 2. Auto-fill other empty items
            for (var key in _uploadedDocuments.keys) {
              if (index >= images.length) break;
              if (key != title && _uploadedDocuments[key] == false) {
                setState(() {
                  _uploadedImages[key] = File(images[index].path);
                  _uploadedDocuments[key] = true;
                });
                index++;
              }
            }
          }
        } else {
          File? image = await ImagePickerService.showImageSourceDialog(context);
          if (image != null) {
            setState(() {
              _uploadedImages[title] = image;
              _uploadedDocuments[title] = true;
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: hasError
              ? Colors.red.withValues(alpha: 0.05)
              : (isSelected
                  ? AppColors.greenLight.withValues(alpha: 0.1)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasError
                ? Colors.red
                : (isSelected ? AppColors.greenLight : Colors.grey.shade300),
            width: hasError ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon or Preview
            if (isSelected && selectedFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  selectedFile,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              Icon(
                icon,
                color: Colors.grey,
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
                      color: isSelected ? AppColors.greenLight : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasError
                        ? 'Resubmission Required'
                        : (isSelected ? 'Tap to change' : subtitle),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasError
                          ? Colors.red
                          : (isSelected ? AppColors.greenLight : Colors.grey),
                      fontWeight:
                          hasError ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (hasError && !isSelected)
              const Icon(Icons.priority_high, color: Colors.red, size: 24)
            else if (isSelected)
              Icon(
                Icons.edit,
                color: AppColors.greenLight,
                size: 20,
              )
            else
              const Icon(
                Icons.upload,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAllDocuments() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      String driverId = userData?['driverId']?.toString() ?? '';
      String vehicleId = userData?['vehicleId']?.toString() ?? '';

      if (_isEditing) {
        if (driverId.isEmpty || vehicleId.isEmpty)
          throw Exception("Cannot update: Missing IDs");

        await ApiService.updateDriver(
          driverId: driverId,
          name: userData?['name'] ?? '',
          email: userData?['email'] ?? '',
          primaryLocation: userData?['primaryLocation'] ?? '',
          licenceNumber: userData?['licenceNumber'] ?? '',
          aadharNumber: userData?['aadharNumber'] ?? '',
          licenceExpiry: userData?['licenceExpiry'] ?? '',
        );

        await ApiService.updateVehicle(
          vehicleId: vehicleId,
          vehicleType: userData?['vehicleType'] ?? '',
          vehicleBrand: userData?['vehicleBrand'] ?? '',
          vehicleModel: userData?['vehicleModel'] ?? '',
          vehicleColor: userData?['vehicleColor'] ?? '',
          seatingCapacity:
              int.parse((userData?['seatingCapacity'] ?? 4).toString()),
          rcExpiryDate: userData?['rcExpiryDate'] ?? '',
          fcExpiryDate: userData?['fcExpiryDate'] ?? '',
        );

        // Update Local Storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('name', userData?['name'] ?? '');
        await prefs.setString('email', userData?['email'] ?? '');
        await prefs.setString(
            'primaryLocation', userData?['primaryLocation'] ?? '');
        await prefs.setString(
            'licenceExpiry', userData?['licenceExpiry'] ?? '');
        await prefs.setString('rcExpiryDate', userData?['rcExpiryDate'] ?? '');
        await prefs.setString('fcExpiryDate', userData?['fcExpiryDate'] ?? '');
      } else if (driverId.isEmpty) {
        debugPrint("ERROR: Driver ID missing in KYC screen flow.");
        throw Exception(
            'Driver ID missing. Please restart the registration process.');
      }

      if (driverId.isEmpty) throw Exception('Driver ID missing. Restart flow.');

      // Iterate through all required keys to ensure everything is uploaded
      // (Or just iterate _uploadedImages if we trust the validation)
      for (var entry in _uploadedImages.entries) {
        String title = entry.key;
        File file = entry.value!;

        debugPrint('Uploading $title...');

        switch (title) {
          case 'Driving License':
            if (_isEditing)
              await ApiService.reuploadLicence(driverId, file);
            else
              await ApiService.uploadLicence(driverId, file);
            break;
          case 'Aadhaar Card':
            if (_isEditing)
              await ApiService.reuploadAadhar(driverId, file);
            else
              await ApiService.uploadAadhar(driverId, file);
            break;
          case 'Profile Picture':
            if (_isEditing)
              await ApiService.reuploadDriverPhoto(driverId, file);
            else
              await ApiService.uploadDriverPhoto(driverId, file);
            // Save Profile Photo Path locally
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('profile_photo_path', file.path);
            break;
          case 'RC Book':
            if (_isEditing)
              await ApiService.reuploadVehicleRC(vehicleId, file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehicleRC(vehicleId, file);
            }
            break;
          case 'FC Certificate':
            if (_isEditing)
              await ApiService.reuploadVehicleFC(vehicleId, file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehicleFC(vehicleId, file);
            }
            break;
          case 'Front View':
            if (_isEditing)
              await ApiService.reuploadVehiclePhoto(vehicleId, 'front', file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehiclePhoto(vehicleId, 'front', file);
            }
            break;
          case 'Back View':
            if (_isEditing)
              await ApiService.reuploadVehiclePhoto(vehicleId, 'back', file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehiclePhoto(vehicleId, 'back', file);
            }
            break;
          case 'Left Side View':
            if (_isEditing)
              await ApiService.reuploadVehiclePhoto(vehicleId, 'left', file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehiclePhoto(vehicleId, 'left', file);
            }
            break;
          case 'Right Side View':
            if (_isEditing)
              await ApiService.reuploadVehiclePhoto(vehicleId, 'right', file);
            else {
              if (vehicleId.isEmpty) throw Exception('Vehicle ID missing');
              await ApiService.uploadVehiclePhoto(vehicleId, 'right', file);
            }
            break;
        }
      }

      // Update Status back to 'pending' if this was a correction/resubmission
      if (_isEditing) {
        debugPrint('Clearing previous errors...');
        await ApiService.clearDriverErrors(driverId);
        debugPrint('Updating KYC status to pending for re-review...');
        await ApiService.updateKycStatus(driverId, 'pending');
      }

      // Success!
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isKycSubmitted', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All documents uploaded successfully!')),
        );
        Navigator.pushReplacementNamed(context, '/approval-pending');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed',
                style: TextStyle(color: Colors.red)),
            content: Text(e.toString().replaceAll("Exception:", "")),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
