import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> showImageSourceDialog(BuildContext context) async {
    // 1. Ask user for source
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    // 2. If source selected, pick image
    if (source != null) {
      try {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 50, // Optimize image size
        );
        if (image != null) {
          return File(image.path);
        }
      } catch (e) {
        debugPrint('Image Picker Error: $e');
      }
    }
    return null;
  }
}
