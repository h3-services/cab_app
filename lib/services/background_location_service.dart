import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackgroundLocationService {
  static Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: false,
        autoStart: true,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    await _updateLocation();
    return true;
  }

  static void onStart(ServiceInstance service) async {
    await dotenv.load();

    // Update location immediately
    await _updateLocation();

    // Update every 15 minutes
    service.on('update').listen((event) async {
      await _updateLocation();
    });

    // Periodic timer for 15 minutes
    Future.delayed(const Duration(minutes: 15), () async {
      while (true) {
        await _updateLocation();
        await Future.delayed(const Duration(minutes: 15));
      }
    });
  }

  static Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      final authToken = prefs.getString('auth_token');

      if (driverId != null && authToken != null) {
        await _sendLocationToBackend(driverId, position, authToken);
      }
    } catch (e) {
      print('[BG Location Error] $e');
    }
  }

  static Future<void> _sendLocationToBackend(
    String driverId,
    Position position,
    String authToken,
  ) async {
    try {
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null) return;

      final url = '$baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('[BG Location] Status: ${response.statusCode}');
    } catch (e) {
      print('[BG Location API Error] $e');
    }
  }

  static Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }
}
