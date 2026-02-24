import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_plugin.dart';
import 'alarm_manager_location_service.dart';

Future<void> initializeService() async {
  await AlarmManagerLocationService.initialize();
  
  final service = FlutterBackgroundService();

  await NotificationPlugin.initialize();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'Chola Cabs Driver',
      initialNotificationContent: 'Location tracking active',
      foregroundServiceNotificationId: 888,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
      autoStart: true,
    ),
  );

  try {
    await service.startService();
  } catch (e) {
    debugPrint('[Service Start Error] $e');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    await dotenv.load();
  } catch (e) {
    debugPrint('[BG Service] dotenv load error: $e');
  }

  await NotificationPlugin.initialize();

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

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    try {
      debugPrint('📍 Background location update at ${DateTime.now()}');
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_bg_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
        'app_state': 'terminated'
      }));

      await sendLocationToServer(position.latitude, position.longitude, service);
      
      await NotificationPlugin.showLocationCapturedNotification(
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'Terminated',
      );
      
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }
    } catch (e) {
      debugPrint('[BG Location Error] $e');
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          await sendLocationToServer(lastPosition.latitude, lastPosition.longitude, service);
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
    await sendLocationToServer(position.latitude, position.longitude, service);
  } catch (e) {
    debugPrint('[iOS BG Location Error] $e');
  }
  return true;
}

Future<void> sendLocationToServer(double lat, double lng, ServiceInstance service) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId');
    
    if (driverId == null || driverId.isEmpty) return;

    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';
    final url = '$baseUrl/drivers/$driverId/location';
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': 0,
        'source': 'background_service',
        'app_state': 'terminated'
      }),
    ).timeout(const Duration(seconds: 15));

    if (service is AndroidServiceInstance) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await prefs.setString('last_db_sync', DateTime.now().toIso8601String());
        await prefs.setInt('total_locations_sent', (prefs.getInt('total_locations_sent') ?? 0) + 1);
        
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Online",
          content: "Location synced at $timeStr",
        );
      } else {
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Error",
          content: "Failed to sync location",
        );
      }
    }
  } catch (e) {
    debugPrint('[Location Sync Error] $e');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Chola Cabs Driver - Network Error",
        content: "Cannot reach server",
      );
    }
  }
}