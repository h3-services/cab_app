import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_manager_location_service.dart';
import 'workmanager_location_service.dart';

class BackgroundLocationService {
  static bool _serviceInitialized = false;

  static Future<void> initializeBackgroundService() async {
    try {
      print('[BG Service] Initializing native Android services...');
      
      // Use ONLY native Android solutions
      await AlarmManagerLocationService.initialize();
      await WorkManagerLocationService.initialize();
      
      _serviceInitialized = true;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_service_running', true);
      await prefs.setString('service_last_start', DateTime.now().toIso8601String());
      
      print('[BG Service] ✅ Services initialized successfully');
    } catch (e) {
      print('[BG Service] ❌ Init error: $e');
    }
  }

  static Future<void> stopBackgroundService() async {
    _serviceInitialized = false;
    
    await AlarmManagerLocationService.cancel();
    await WorkManagerLocationService.stop();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_service_running', false);
    
    print('[BG Service] ✅ Services stopped');
  }
}
