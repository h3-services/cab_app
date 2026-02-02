import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
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

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // DartPluginRegistrant.ensureInitialized(); // Not needed in newer Flutter versions
  
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('[BG Service] dotenv load error: $e');
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
    service.stopSelf();
  });

  // Update location every 15 minutes
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      await sendLocationToServer(
        position.latitude,
        position.longitude,
        service,
      );
    } catch (e) {
      debugPrint('[BG Location Error] $e');
      // Try last known position as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          await sendLocationToServer(
            lastPosition.latitude,
            lastPosition.longitude,
            service,
          );
        }
      } catch (fallbackError) {
        debugPrint('[BG Fallback Error] $fallbackError');
      }
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 30),
    );

    await sendLocationToServer(
      position.latitude,
      position.longitude,
      service,
    );
  } catch (e) {
    debugPrint('[iOS BG Location Error] $e');
  }
  return true;
}

Future<void> sendLocationToServer(
  double lat,
  double lng,
  ServiceInstance service,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId');
    
    if (driverId == null || driverId.isEmpty) {
      debugPrint('[BG Location] No driver ID found');
      return;
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';
    final url = '$baseUrl/drivers/$driverId/location';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 15));

    debugPrint('[BG Location] Response: ${response.statusCode}');

    // Update notification
    if (service is AndroidServiceInstance) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Online",
          content: "Location updated at $timeStr",
        );
      } else {
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Connection Issue",
          content: "Failed to update location",
        );
      }
    }
  } catch (e) {
    debugPrint('[BG Location API Error] $e');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Chola Cabs Driver - Network Error",
        content: "Check internet connection",
      );
    }
  }
}
