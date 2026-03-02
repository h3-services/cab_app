import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'location_tracking_service.dart';
import 'background_location_service.dart';
import 'alarm_manager_location_service.dart';
import 'workmanager_location_service.dart';
/// Centralized manager for all location tracking services
/// Ensures location is captured every 5 minutes across all app states
class LocationServiceManager {
  static bool _isInitialized = false;
  static Timer? _healthCheckTimer;
  /// Initialize all location tracking mechanisms
  static Future<void> initializeAllServices() async {
    if (_isInitialized) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_services_active', true);
      await prefs.setString('services_init_time', DateTime.now().toIso8601String());
      // 1. Foreground tracking (when app is open)
      await LocationTrackingService.startLocationTracking();
      // 2. Background service (when app is minimized)
      await BackgroundLocationService.initializeBackgroundService();
      // 3. Alarm Manager (most reliable for terminated state)
      await AlarmManagerLocationService.initialize();
      // 4. WorkManager (backup for terminated state)
      await WorkManagerLocationService.initialize();
      // Start health check to ensure services stay alive
      _startHealthCheck();
      _isInitialized = true;
      } catch (e) {
      rethrow;
    }
  }
  /// Health check every 10 minutes to ensure services are running
  static void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastLocation = prefs.getString('last_location');
        final lastUpdate = prefs.getString('last_location_time');
        if (lastUpdate != null) {
          final lastUpdateTime = DateTime.parse(lastUpdate);
          final minutesSinceUpdate = DateTime.now().difference(lastUpdateTime).inMinutes;
          if (minutesSinceUpdate > 10) {
            await restartAllServices();
          } else {
            }
        }
        // Update health check timestamp
        await prefs.setString('last_health_check', DateTime.now().toIso8601String());
      } catch (e) {
        }
    });
  }
  /// Restart all location services
  static Future<void> restartAllServices() async {
    try {
      await stopAllServices();
      await Future.delayed(const Duration(seconds: 2));
      _isInitialized = false;
      await initializeAllServices();
      } catch (e) {
      }
  }
  /// Stop all location services
  static Future<void> stopAllServices() async {
    try {
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      LocationTrackingService.stopLocationTracking();
      await BackgroundLocationService.stopBackgroundService();
      await AlarmManagerLocationService.cancel();
      await WorkManagerLocationService.stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('location_services_active', false);
      _isInitialized = false;
      } catch (e) {
      }
  }
  /// Check if services are running
  static Future<bool> areServicesRunning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('location_services_active') ?? false;
    } catch (e) {
      return false;
    }
  }
  /// Get service status report
  static Future<Map<String, dynamic>> getServiceStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'initialized': _isInitialized,
        'services_active': prefs.getBool('location_services_active') ?? false,
        'last_location': prefs.getString('last_location'),
        'last_location_time': prefs.getString('last_location_time'),
        'last_health_check': prefs.getString('last_health_check'),
        'last_alarm_location': prefs.getString('last_alarm_location'),
        'last_workmanager_location': prefs.getString('last_workmanager_location'),
        'last_bg_location': prefs.getString('last_bg_location'),
        'init_time': prefs.getString('services_init_time'),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
