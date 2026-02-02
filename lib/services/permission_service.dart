import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> requestLocationPermissions() async {
    // Request basic location permission first
    PermissionStatus locationStatus = await Permission.location.request();
    
    if (locationStatus != PermissionStatus.granted) {
      throw 'Location permission required for driver tracking';
    }

    // Request background location permission
    PermissionStatus backgroundStatus = await Permission.locationAlways.request();
    
    if (backgroundStatus != PermissionStatus.granted) {
      throw 'Background location permission required for continuous tracking';
    }

    return true;
  }

  static Future<bool> checkLocationPermissions() async {
    PermissionStatus locationStatus = await Permission.location.status;
    PermissionStatus backgroundStatus = await Permission.locationAlways.status;
    
    return locationStatus == PermissionStatus.granted && 
           backgroundStatus == PermissionStatus.granted;
  }

  static Future<void> showPermissionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location access to:\n\n'
          '• Track your location for trip assignments\n'
          '• Ensure driver safety\n'
          '• Provide accurate pickup/drop locations\n\n'
          'Please grant "Allow all the time" permission.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await requestLocationPermissions();
              } catch (e) {
                // Show settings if permission denied
                await openAppSettings();
              }
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}