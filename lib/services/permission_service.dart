import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static Future<bool> requestLocationPermissions() async {
    print('\n═══════════════════════════════════════════════════════════');
    print('🔐 REQUESTING LOCATION PERMISSIONS');
    print('═══════════════════════════════════════════════════════════');
    
    // Request notification permission first (Android 13+)
    try {
      PermissionStatus notificationStatus = await Permission.notification.request();
      print('🔔 Notification Permission: $notificationStatus');
    } catch (e) {
      print('⚠️ Notification permission request failed: $e');
    }
    
    // Request basic location permission first
    PermissionStatus locationStatus = await Permission.location.request();
    print('📍 Location Permission: $locationStatus');
    
    if (locationStatus != PermissionStatus.granted) {
      print('❌ Location permission denied');
      throw 'Location permission required for driver tracking';
    }

    // Small delay before requesting background permission
    await Future.delayed(const Duration(milliseconds: 500));

    // Request background location permission
    print('🌍 Requesting background location permission...');
    PermissionStatus backgroundStatus = await Permission.locationAlways.request();
    print('🌍 Background Location Permission: $backgroundStatus');
    
    if (backgroundStatus != PermissionStatus.granted) {
      print('⚠️ Background location permission denied - will work only when app is open');
    }

    // Request battery optimization exemption (only once)
    try {
      final prefs = await SharedPreferences.getInstance();
      final batteryOptAsked = prefs.getBool('battery_opt_asked') ?? false;
      
      if (!batteryOptAsked) {
        print('🔋 Requesting battery optimization exemption...');
        PermissionStatus batteryStatus = await Permission.ignoreBatteryOptimizations.request();
        print('🔋 Battery Optimization: $batteryStatus');
        await prefs.setBool('battery_opt_asked', true);
      } else {
        print('🔋 Battery optimization already asked, skipping...');
      }
    } catch (e) {
      print('⚠️ Battery optimization request failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_permission_granted', locationStatus == PermissionStatus.granted);
    await prefs.setBool('background_location_granted', backgroundStatus == PermissionStatus.granted);
    await prefs.setString('permission_granted_at', DateTime.now().toIso8601String());
    
    if (backgroundStatus == PermissionStatus.granted) {
      print('✅ ALL LOCATION PERMISSIONS GRANTED');
    } else {
      print('⚠️ PARTIAL PERMISSIONS - Background location denied');
    }
    print('💾 Permission status stored in SharedPreferences');
    print('═══════════════════════════════════════════════════════════\n');

    return locationStatus == PermissionStatus.granted;
  }

  static Future<bool> checkLocationPermissions() async {
    PermissionStatus locationStatus = await Permission.location.status;
    PermissionStatus backgroundStatus = await Permission.locationAlways.status;
    
    print('🔍 Checking permissions - Location: $locationStatus, Background: $backgroundStatus');
    
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
                print('❌ Permission request failed: $e');
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