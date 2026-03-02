import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class PermissionService {
  static bool _permissionRequestInProgress = false;
  static bool _backgroundPermissionAsked = false;
  static Future<bool> requestLocationPermissions() async {
    // Prevent multiple simultaneous permission requests
    if (_permissionRequestInProgress) {
      return false;
    }
    _permissionRequestInProgress = true;
    try {
      return await _requestPermissionsInternal();
    } finally {
      _permissionRequestInProgress = false;
    }
  }
  static Future<bool> _requestPermissionsInternal() async {
    final prefs = await SharedPreferences.getInstance();
    // Request notification permission first (Android 13+)
    try {
      PermissionStatus notificationStatus = await Permission.notification.request();
      } catch (e) {
      }
    // Request basic location permission first
    PermissionStatus locationStatus = await Permission.location.request();
    if (locationStatus != PermissionStatus.granted) {
      throw 'Location permission required for driver tracking';
    }
    // Check if background permission was already asked in this session
    final backgroundAskedBefore = prefs.getBool('background_permission_asked') ?? false;
    if (_backgroundPermissionAsked || backgroundAskedBefore) {
      final backgroundStatus = await Permission.locationAlways.status;
      await prefs.setBool('background_location_granted', backgroundStatus == PermissionStatus.granted);
      return locationStatus == PermissionStatus.granted;
    }
    // Small delay before requesting background permission
    await Future.delayed(const Duration(milliseconds: 500));
    // Request background location permission
    PermissionStatus backgroundStatus = await Permission.locationAlways.request();
    _backgroundPermissionAsked = true;
    await prefs.setBool('background_permission_asked', true);
    if (backgroundStatus != PermissionStatus.granted) {
      }
    // Request battery optimization exemption (only once)
    try {
      final batteryOptAsked = prefs.getBool('battery_opt_asked') ?? false;
      if (!batteryOptAsked) {
        PermissionStatus batteryStatus = await Permission.ignoreBatteryOptimizations.request();
        await prefs.setBool('battery_opt_asked', true);
      } else {
        }
    } catch (e) {
      }
    await prefs.setBool('location_permission_granted', locationStatus == PermissionStatus.granted);
    await prefs.setBool('background_location_granted', backgroundStatus == PermissionStatus.granted);
    await prefs.setString('permission_granted_at', DateTime.now().toIso8601String());
    await prefs.setBool('permissions_requested_once', true);
    if (backgroundStatus == PermissionStatus.granted) {
      } else {
      }
    return locationStatus == PermissionStatus.granted;
  }
  static Future<bool> checkLocationPermissions() async {
    PermissionStatus locationStatus = await Permission.location.status;
    PermissionStatus backgroundStatus = await Permission.locationAlways.status;
    // Store current status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_location_granted', backgroundStatus == PermissionStatus.granted);
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dont_show_permission_dialog', true);
            },
            child: const Text('Don\'t ask again'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await requestLocationPermissions();
                // If successful, mark as granted
                final prefs = await SharedPreferences.getInstance();
                final backgroundStatus = await Permission.locationAlways.status;
                if (backgroundStatus == PermissionStatus.granted) {
                  await prefs.setBool('dont_show_permission_dialog', true);
                }
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