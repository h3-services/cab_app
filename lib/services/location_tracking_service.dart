import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'background_location_service.dart';

class LocationTrackingService {
  static Timer? _locationTimer;
  static bool _isInitialized = false;

  static Future<void> startLocationTracking() async {
    if (_isInitialized) {
      debugPrint('⚠️ Location tracking already running, skipping initialization');
      return;
    }

    debugPrint('🚀 Starting location tracking service...');
    
    // Start background service
    await BackgroundLocationService.initializeBackgroundService();

    // Capture initial location
    await _captureAndStoreLocation();
    
    // Set up 15-minute timer
    _locationTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      await _captureAndStoreLocation();
    });
    
    _isInitialized = true;
    debugPrint('✅ Location tracking initialized with 15-minute intervals');
  }

  static Future<void> _captureAndStoreLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      };

      await prefs.setString('last_location', jsonEncode(locationData));

      debugPrint(
          '\n═══════════════════════════════════════════════════════════');
      debugPrint('📍 LOCATION CAPTURED');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('⏰ Time: ${DateTime.now().toIso8601String()}');
      debugPrint('📌 Latitude: ${position.latitude}');
      debugPrint('📌 Longitude: ${position.longitude}');
      debugPrint('🎯 Accuracy: ${position.accuracy.toStringAsFixed(1)}m');
      debugPrint('═══════════════════════════════════════════════════════════');

      if (driverId != null) {
        await _sendLocationToBackend(driverId, position);
      } else {
        debugPrint('! Driver ID not found, skipping location update');
      }
    } catch (e) {
      debugPrint('[Location Error] $e');
    }
  }

  static Future<void> _sendLocationToBackend(
      String driverId, Position position) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null) {
        debugPrint('[API] ERROR: BASE_URL not configured in .env');
        return;
      }

      final url = '$baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      debugPrint('[API] POST: $url');
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

      debugPrint('[API] Status: ${response.statusCode}');
      debugPrint('[API] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[API] ✓ Location updated in database');
      } else {
        debugPrint('[API] ✗ Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[API] ✗ Error: $e');
    }
  }

  static void stopLocationTracking() {
    debugPrint('🛑 Stopping location tracking service...');
    _locationTimer?.cancel();
    _locationTimer = null;
    _isInitialized = false;
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
    debugPrint('🔄 Resetting location tracking initialization...');
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
}
