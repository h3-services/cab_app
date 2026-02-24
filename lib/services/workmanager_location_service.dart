import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_plugin.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('[WorkManager] 📍 Task started: $task at ${DateTime.now()}');
      
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId == null || driverId.isEmpty) {
        print('[WorkManager] ❌ No driver ID');
        // Schedule next task before returning
        await WorkManagerLocationService._scheduleNextTask();
        return Future.value(true);
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[WorkManager] ❌ Location disabled');
        await WorkManagerLocationService._scheduleNextTask();
        return Future.value(true);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('[WorkManager] ❌ Permission denied');
        await WorkManagerLocationService._scheduleNextTask();
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
      await NotificationPlugin.showLocationCapturedNotification(
        latitude: position.latitude,
        longitude: position.longitude,
        source: 'WorkManager',
      );
      
      await prefs.setString('last_workmanager_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      print('[WorkManager] ✅ Completed: ${position.latitude}, ${position.longitude}');
      
      // Schedule next task
      await WorkManagerLocationService._scheduleNextTask();
      
      return Future.value(true);
    } catch (e) {
      print('[WorkManager] ❌ Error: $e');
      // Still schedule next task even on error
      await WorkManagerLocationService._scheduleNextTask();
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

class WorkManagerLocationService {
  static const String _taskName = 'locationTrackingTask';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    await start();
  }

  static Future<void> start() async {
    // Cancel existing tasks first
    await Workmanager().cancelAll();
    
    // Register one-time task that repeats every 5 minutes
    // WorkManager has 15-min minimum for periodic, so we use one-time with reschedule
    await _scheduleNextTask();
    print('[WorkManager] ✅ Registered 5-min task chain');
  }

  static Future<void> _scheduleNextTask() async {
    await Workmanager().registerOneOffTask(
      '${_taskName}_${DateTime.now().millisecondsSinceEpoch}',
      _taskName,
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_taskName);
    print('[WorkManager] 🛑 Cancelled');
  }
}