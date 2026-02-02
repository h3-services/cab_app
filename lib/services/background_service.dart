import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
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
      print('\n═══════════════════════════════════════════════════════════');
      print('📍 BACKGROUND LOCATION CAPTURE (APP TERMINATED)');
      print('═══════════════════════════════════════════════════════════');
      print('⏰ Time: ${DateTime.now().toIso8601String()}');
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      print('📌 Latitude: ${position.latitude}');
      print('📌 Longitude: ${position.longitude}');
      print('🎯 Accuracy: ${position.accuracy}m');
      print('🔋 App State: TERMINATED/BACKGROUND');
      
      // Store location locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_bg_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
        'app_state': 'terminated'
      }));
      
      print('💾 Location stored locally');

      await sendLocationToServer(
        position.latitude,
        position.longitude,
        service,
      );
      
      print('═══════════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ [BG Location Error] $e');
      // Try last known position as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('🔄 Using last known position as fallback');
          print('📌 Fallback Lat: ${lastPosition.latitude}');
          print('📌 Fallback Lng: ${lastPosition.longitude}');
          
          await sendLocationToServer(
            lastPosition.latitude,
            lastPosition.longitude,
            service,
          );
        }
      } catch (fallbackError) {
        print('❌ [BG Fallback Error] $fallbackError');
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
      print('⚠️ No driver ID found - cannot store in DB');
      return;
    }

    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';
    final url = '$baseUrl/drivers/$driverId/location';
    
    print('📤 STORING LOCATION IN DATABASE');
    print('🔗 URL: $url');
    print('👤 Driver ID: $driverId');
    
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': 0, // Will be updated if available
        'source': 'background_service',
        'app_state': 'terminated'
      }),
    ).timeout(const Duration(seconds: 15));

    print('📊 Response Status: ${response.statusCode}');
    print('📋 Response Body: ${response.body}');

    // Update notification
    if (service is AndroidServiceInstance) {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ LOCATION SUCCESSFULLY STORED IN DATABASE');
        
        // Store success in local prefs
        await prefs.setString('last_db_sync', DateTime.now().toIso8601String());
        await prefs.setInt('total_locations_sent', (prefs.getInt('total_locations_sent') ?? 0) + 1);
        
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - Online",
          content: "Location synced to DB at $timeStr",
        );
      } else {
        print('❌ FAILED TO STORE IN DATABASE - Status: ${response.statusCode}');
        service.setForegroundNotificationInfo(
          title: "Chola Cabs Driver - DB Error",
          content: "Failed to sync location (${response.statusCode})",
        );
      }
    }
  } catch (e) {
    print('❌ DATABASE STORAGE ERROR: $e');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Chola Cabs Driver - Network Error",
        content: "Cannot reach database server",
      );
    }
  }
}
