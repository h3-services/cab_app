import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'background_location_service.dart';
import 'notification_plugin.dart';
import 'workmanager_location_service.dart';
class LocationTrackingService {
  static Timer? _locationTimer;
  static bool _isInitialized = false;
  static Future<void> startLocationTracking() async {
    if (_isInitialized) {
      stopLocationTracking();
    }
    await BackgroundLocationService.initializeBackgroundService();
    await WorkManagerLocationService.initialize();
    await _captureAndStoreLocation();
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _captureAndStoreLocation();
    });
    _isInitialized = true;
    }
  static Future<void> _captureAndStoreLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Try to open location settings
        await Geolocator.openLocationSettings();
        return;
      }
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      Position position;
      try {
        // Try high accuracy first
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
      } catch (e) {
        try {
          // Fallback to medium accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
        } catch (e2) {
          // Final fallback to last known position
          position = await Geolocator.getLastKnownPosition() ?? 
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              forceAndroidLocationManager: true,
            );
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
        'app_state': 'foreground',
      };
      await prefs.setString('last_location', jsonEncode(locationData));
      debugPrint('📍 LOCATION CAPTURED (FOREGROUND)');
      debugPrint('⏰ Time: ${DateTime.now().toIso8601String()}');
      debugPrint('🎯 Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
      if (driverId != null) {
        await _sendLocationToBackend(driverId, position);
      } else {
        }
    } catch (e) {
      // Store error for debugging
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_location_error', '$e');
      await prefs.setString('last_location_error_time', DateTime.now().toIso8601String());
    }
  }
  static Future<void> _sendLocationToBackend(
      String driverId, Position position) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null) {
        return;
      }
      final url = '$baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
      debugPrint('[API] Body: ${jsonEncode(body)}');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );
      if (response.statusCode == 200 || response.statusCode == 201) {
        } else {
        }
    } catch (e) {
      }
  }
  static void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isInitialized = false;
    WorkManagerLocationService.stop();
  }
  static Future<Map<String, dynamic>?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString('last_location');
    if (locationStr != null) {
      return jsonDecode(locationStr);
    }
    return null;
  }
  /// Reset location tracking initialization (for testing/troubleshooting)
  static Future<void> resetLocationTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_tracking_initialized', false);
    stopLocationTracking();
  }
  /// Check if location tracking is properly initialized
  static Future<bool> isLocationTrackingActive() async {
    final prefs = await SharedPreferences.getInstance();
    final isInitialized = prefs.getBool('location_tracking_initialized') ?? false;
    final hasActiveTimer = _locationTimer != null && _locationTimer!.isActive;
    return isInitialized && hasActiveTimer && _isInitialized;
  }
  /// Test notification immediately (for debugging)
  static Future<void> testTerminatedNotification() async {
    await NotificationPlugin.showTerminatedLocationNotification(
      latitude: 10.0817618,
      longitude: 78.7463452,
    );
  }
}
