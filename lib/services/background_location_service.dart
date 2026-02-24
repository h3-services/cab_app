import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'alarm_manager_location_service.dart';

class BackgroundLocationService {
  static Timer? _locationTimer;
  static bool _serviceInitialized = false;
  
  static Future<void> initializeBackgroundService() async {
    debugPrint('🚀 Initializing background location services');

    // Initialize Alarm Manager for terminated state
    await AlarmManagerLocationService.initialize();

    final service = FlutterBackgroundService();
    await NotificationPlugin.initialize();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'location_tracking',
        initialNotificationTitle: 'Chola Cabs Driver',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
        autoStart: true,
      ),
    );

    await service.startService();
    _serviceInitialized = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_service_running', true);
    await prefs.setString('service_last_start', DateTime.now().toIso8601String());
    
    debugPrint('✅ Background location service initialized');
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    await _updateLocation(service);
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    try {
      await dotenv.load();
    } catch (e) {
      print('[BG Service] dotenv load error: $e');
    }
    
    await NotificationPlugin.initialize();
    await NotificationPlugin.showTestNotification();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
      service.setAsForegroundService();
    }

    service.on('stopService').listen((event) {
      _locationTimer?.cancel();
      service.stopSelf();
    });

    if (_locationTimer != null && _locationTimer!.isActive) {
      print('[BG Service] Canceling existing timer');
      _locationTimer!.cancel();
    }

    await _updateLocation(service);

    _locationTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      print('[BG Service] 🔄 5-min timer at ${DateTime.now()}');
      await _updateLocation(service);
      
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }
    });
    
    print('[BG Service] ✅ Started with 5-min intervals');
  }

  static Future<void> _updateLocation(ServiceInstance service) async {
    try {
      print('[BG Location] 🔄 Starting location update at ${DateTime.now()}...');
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[BG Location] ❌ Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('[BG Location] ❌ Location permission denied: $permission');
        return;
      }
      
      print('[BG Location] ✅ Permissions OK, getting position...');

      Position position;
      try {
        // Try high accuracy with shorter timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        print('[BG Location] 📍 Position (high): ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('[BG Location] ⚠️ High accuracy failed: $e, trying medium...');
        try {
          // Fallback to medium accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
          print('[BG Location] 📍 Position (medium): ${position.latitude}, ${position.longitude}');
        } catch (e2) {
          print('[BG Location] ⚠️ Medium failed: $e2, trying last known...');
          // Try last known position
          position = await Geolocator.getLastKnownPosition() ?? 
            await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              forceAndroidLocationManager: true,
            );
          print('[BG Location] 📍 Position (fallback): ${position.latitude}, ${position.longitude}');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId != null && driverId.isNotEmpty) {
        print('[BG Location] 📤 Sending location for driver: $driverId');
        await _sendLocationToBackend(driverId, position, service);
        
        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'accuracy': position.accuracy,
          'app_state': 'background',
        };
        await prefs.setString('last_location', jsonEncode(locationData));
        await prefs.setString('last_location_time', DateTime.now().toIso8601String());
        await prefs.setInt('location_update_count', (prefs.getInt('location_update_count') ?? 0) + 1);
        
        print('[BG Location] 🔔 Showing notification');
        try {
          await NotificationPlugin.showLocationCapturedNotification(
            latitude: position.latitude,
            longitude: position.longitude,
            source: 'Background',
          );
          print('[BG Location] ✅ Notification sent');
        } catch (e) {
          print('[BG Location] ❌ Notification error: $e');
        }
        
        print('[BG Location] ✅ Update completed at ${DateTime.now()}');
      } else {
        print('[BG Location] ❌ No driver ID found');
      }
    } catch (e) {
      print('[BG Location Error] ❌ $e');
      // Store error for debugging
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_bg_location_error', '$e');
        await prefs.setString('last_bg_location_error_time', DateTime.now().toIso8601String());
      } catch (_) {}
    }
  }

  static Future<void> _sendLocationToBackend(
    String driverId,
    Position position,
    ServiceInstance service,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';
      
      final url = '$baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      };

      print('[BG Location] Sending to: $url');
      print('[BG Location] Data: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      print('[BG Location] Response: ${response.statusCode}');

      if (service is AndroidServiceInstance) {
        final isAvailable = prefs.getBool('is_available') ?? false;
        final statusText = isAvailable ? "Online" : "Offline";
        final now = DateTime.now();
        final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

        if (response.statusCode == 200 || response.statusCode == 201) {
          service.setForegroundNotificationInfo(
            title: "Chola Cabs Driver - $statusText",
            content: "Location updated at $timeStr • Lat: ${position.latitude.toStringAsFixed(4)}",
          );
          
          // Save last successful update
          await prefs.setString('last_location_update', DateTime.now().toIso8601String());
        } else {
          service.setForegroundNotificationInfo(
            title: "Chola Cabs Driver - Connection Issue",
            content: "Failed to update location (${response.statusCode})",
          );
        }
      }
    } catch (e) {
      print('[BG Location API Error] $e');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Network Error",
          content: "Check internet connection and try again",
        );
      }
    }
  }

  static Future<void> stopBackgroundService() async {
    debugPrint('🛑 Stopping background location service...');
    _locationTimer?.cancel();
    _locationTimer = null;
    _serviceInitialized = false;
    await AlarmManagerLocationService.cancel();
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
