import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await dotenv.load();
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return Future.value(true);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
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

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId != null && driverId.isNotEmpty) {
        final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';
        final url = '$baseUrl/drivers/$driverId/location';
        
        await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'timestamp': DateTime.now().toIso8601String(),
            'accuracy': position.accuracy,
            'source': 'workmanager',
          }),
        ).timeout(const Duration(seconds: 15));

        await prefs.setString('last_workmanager_update', DateTime.now().toIso8601String());
      }
      
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

class WorkManagerLocationService {
  static const String taskName = 'locationUpdateTask';

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await registerPeriodicTask();
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(taskName);
  }
}
