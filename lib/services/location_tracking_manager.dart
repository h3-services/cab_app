import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationTrackingManager {
  static const String _trackingEnabledKey = 'location_tracking_enabled';
  static const String _lastLocationTimeKey = 'last_location_time';
  static const String _lastLatitudeKey = 'last_latitude';
  static const String _lastLongitudeKey = 'last_longitude';

  static Future<void> enableTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, true);
    
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> disableTracking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, false);
    
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  static Future<bool> isTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingEnabledKey) ?? true;
  }

  static Future<String?> getLastLocationTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastLocationTimeKey);
  }

  static Future<Map<String, double>?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_lastLatitudeKey);
    final lng = prefs.getDouble(_lastLongitudeKey);
    
    if (lat == null || lng == null) return null;
    
    return {
      'latitude': lat,
      'longitude': lng,
    };
  }

  static Future<void> saveLastLocation(double latitude, double longitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatitudeKey, latitude);
    await prefs.setDouble(_lastLongitudeKey, longitude);
    await prefs.setString(
      _lastLocationTimeKey,
      DateTime.now().toIso8601String(),
    );
  }

}
