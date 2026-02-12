import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('[WorkManager] 📍 Task started: $task at ${DateTime.now()}');
      
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId == null || driverId.isEmpty) {
        print('[WorkManager] ❌ No driver ID');
        return Future.value(true);
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[WorkManager] ❌ Location disabled');
        return Future.value(true);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('[WorkManager] ❌ Permission denied');
        return Future.value(true);
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition() ?? 
          Position(
            latitude: 0, longitude: 0, timestamp: DateTime.now(),
            accuracy: 0, altitude: 0, heading: 0, speed: 0,
            speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
          );
      }

      await _sendLocation(driverId, position);
      await _showNotification(position);
      
      await prefs.setString('last_workmanager_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      print('[WorkManager] ✅ Completed: ${position.latitude}, ${position.longitude}');
      return Future.value(true);
    } catch (e) {
      print('[WorkManager] ❌ Error: $e');
      return Future.value(false);
    }
  });
}

Future<void> _sendLocation(String driverId, Position position) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('BASE_URL') ?? 'https://api.cholacabs.in/api';
    
    final url = '$baseUrl/drivers/$driverId/location';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      }),
    ).timeout(const Duration(seconds: 15));

    print('[WorkManager] API: ${response.statusCode}');
  } catch (e) {
    print('[WorkManager] API Error: $e');
  }
}

Future<void> _showNotification(Position position) async {
  try {
    final notifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: androidSettings));
    
    const channel = AndroidNotificationChannel(
      'location_updates',
      'Location Updates',
      importance: Importance.high,
    );
    
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    await notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📍 Location Captured',
      'Time: $time | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  } catch (e) {
    print('[WorkManager] Notification error: $e');
  }
}

class WorkManagerLocationService {
  static const String _taskName = 'locationTrackingTask';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    await start();
  }

  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
    print('[WorkManager] ✅ Registered 5-min periodic task');
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_taskName);
    print('[WorkManager] 🛑 Cancelled');
  }
}