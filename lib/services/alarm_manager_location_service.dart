import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'notification_plugin.dart';
class AlarmManagerLocationService {
  static const int _alarmId = 0;
  static const String _baseUrl = 'https://api.cholacabs.in/api';
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
    await NotificationPlugin.initialize();
    // Cancel any existing alarms first
    await AndroidAlarmManager.cancel(_alarmId);
    // Schedule exact alarm every 5 minutes
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 5),
      _alarmId,
      _locationCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
      startAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    }
  @pragma('vm:entry-point')
  static Future<void> _locationCallback() async {
    debugPrint('[Alarm] 📍 Location callback triggered at ${DateTime.now()}');
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      if (driverId == null || driverId.isEmpty) {
        return;
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return;
      }
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        } catch (e) {
        position = await Geolocator.getLastKnownPosition() ?? 
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            forceAndroidLocationManager: true,
          );
        }
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        debugPrint('[Alarm] ❌ Invalid position (0,0), skipping');
        return;
      }
      await _sendLocationToBackend(driverId, position);
      await prefs.setString('last_alarm_location', jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      }));
      } catch (e) {
      // Store error for debugging
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_alarm_error', '$e');
        await prefs.setString('last_alarm_error_time', DateTime.now().toIso8601String());
      } catch (_) {}
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
      } catch (e) {
      }
  }
  static Future<void> cancel() async {
    await AndroidAlarmManager.cancel(_alarmId);
    }
}
