import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackgroundLocationService {
  static Timer? _locationTimer;
  
  static Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'location_tracking',
        initialNotificationTitle: 'Chola Cabs Driver',
        initialNotificationContent: 'Location tracking active for trip assignments',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
        autoStart: true,
      ),
    );

    await service.startService();
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

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      _locationTimer?.cancel();
      service.stopSelf();
    });

    // Update location immediately
    await _updateLocation(service);

    // Use Timer.periodic for reliable background execution
    _locationTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      await _updateLocation(service);
    });
  }

  static Future<void> _updateLocation(ServiceInstance service) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[BG Location] Location services disabled');
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('[BG Location] Location permission denied');
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        // Fallback to last known position
        position = await Geolocator.getLastKnownPosition() ?? 
          Position(
            latitude: 0,
            longitude: 0,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
      }

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId != null && driverId.isNotEmpty) {
        await _sendLocationToBackend(driverId, position, service);
      } else {
        print('[BG Location] No driver ID found');
      }
    } catch (e) {
      print('[BG Location Error] $e');
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
    _locationTimer?.cancel();
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
