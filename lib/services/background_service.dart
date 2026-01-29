import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await _initializeNotifications();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'Location Tracking Active',
      initialNotificationContent: 'Tracking location every 15 minutes',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'location_tracking',
            'Location Tracking',
            description: 'Notification for background location tracking',
            importance: Importance.low,
          ),
        );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer.periodic(const Duration(minutes: 15), (timer) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () async => await Geolocator.getLastKnownPosition() ?? Position(
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
        ),
      );

      final timestamp = DateTime.now().toIso8601String();
      print('\n═══════════════════════════════════════════════════════════');
      print('📍 LOCATION CAPTURED');
      print('═══════════════════════════════════════════════════════════');
      print('⏰ Time: $timestamp');
      print('📌 Latitude: ${position.latitude}');
      print('📌 Longitude: ${position.longitude}');
      print('🎯 Accuracy: ${position.accuracy}m');
      print('═══════════════════════════════════════════════════════════\n');

      await _sendLocationToBackend(
        position.latitude,
        position.longitude,
      );

      _showNotification(position.latitude, position.longitude);
    } catch (e) {
      print('❌ Error fetching location: $e');
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () async => await Geolocator.getLastKnownPosition() ?? Position(
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
      ),
    );

    final timestamp = DateTime.now().toIso8601String();
    print('\n═══════════════════════════════════════════════════════════');
    print('📍 LOCATION CAPTURED (iOS Background)');
    print('═══════════════════════════════════════════════════════════');
    print('⏰ Time: $timestamp');
    print('📌 Latitude: ${position.latitude}');
    print('📌 Longitude: ${position.longitude}');
    print('🎯 Accuracy: ${position.accuracy}m');
    print('═══════════════════════════════════════════════════════════\n');

    await _sendLocationToBackend(
      position.latitude,
      position.longitude,
    );
  } catch (e) {
    print('❌ iOS background location error: $e');
  }

  return true;
}

Future<void> _sendLocationToBackend(double lat, double lng) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final driverId = prefs.getString('driver_id');
    final backendUrl = prefs.getString('backend_url') ?? 'https://your-backend.com';

    if (token == null) {
      print('⚠️  No auth token found');
      return;
    }

    if (driverId == null) {
      print('⚠️  No driver_id found');
      return;
    }

    print('📤 Sending location to backend...');
    final response = await http.post(
      Uri.parse('$backendUrl/api/v1/drivers/$driverId/location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('✅ Location sent successfully to backend');
      await _saveLastLocationTime();
    } else {
      print('❌ Backend error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error sending location: $e');
  }
}

Future<void> _saveLastLocationTime() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'last_location_time',
    DateTime.now().toIso8601String(),
  );
}

void _showNotification(double lat, double lng) {
  flutterLocalNotificationsPlugin.show(
    888,
    'Location Updated',
    'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'location_tracking',
        'Location Tracking',
        channelDescription: 'Notification for background location tracking',
        importance: Importance.low,
        priority: Priority.low,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

Future<void> requestLocationPermissions() async {
  final permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    await Geolocator.requestPermission();
  } else if (permission == LocationPermission.deniedForever) {
    await Geolocator.openLocationSettings();
  }
}

Future<bool> isLocationServiceEnabled() async {
  return await Geolocator.isLocationServiceEnabled();
}
