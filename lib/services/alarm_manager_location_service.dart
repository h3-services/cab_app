import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlarmManagerLocationService {
  static const int _alarmId = 0;
  static const String _baseUrl = 'https://api.cholacabs.in/api';
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
    
    // Initialize notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: androidSettings));
    
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 2),
      _alarmId,
      _locationCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
    debugPrint('✅ Alarm Manager initialized for 2-minute location tracking');
  }

  @pragma('vm:entry-point')
  static Future<void> _locationCallback() async {
    debugPrint('[Alarm] 📍 Location callback triggered at ${DateTime.now()}');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      
      if (driverId == null || driverId.isEmpty) {
        debugPrint('[Alarm] ❌ No driver ID found');
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Alarm] ❌ Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('[Alarm] ❌ Location permission denied');
        return;
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

      await _sendLocationToBackend(driverId, position);
      
      // Show notification
      await _showLocationNotification(position);
      
      await prefs.setString('last_alarm_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      
      debugPrint('[Alarm] ✅ Location sent: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('[Alarm] ❌ Error: $e');
    }
  }

  static Future<void> _sendLocationToBackend(String driverId, Position position) async {
    try {
      final url = '$_baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[Alarm] API Response: ${response.statusCode}');
    } catch (e) {
      debugPrint('[Alarm] API Error: $e');
    }
  }

  static Future<void> _showLocationNotification(Position position) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      const androidDetails = AndroidNotificationDetails(
        'location_updates',
        'Location Updates',
        channelDescription: 'Notifications when location is captured',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '📍 Location Captured',
        'Time: $timeStr | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}',
        const NotificationDetails(android: androidDetails),
      );
      
      debugPrint('[Alarm] 🔔 Notification shown');
    } catch (e) {
      debugPrint('[Alarm] Notification error: $e');
    }
  }

  static Future<void> cancel() async {
    await AndroidAlarmManager.cancel(_alarmId);
    debugPrint('🛑 Alarm Manager cancelled');
  }
}
