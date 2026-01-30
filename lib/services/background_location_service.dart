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
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'location_tracking',
        initialNotificationTitle: 'Chola Cabs Tracking',
        initialNotificationContent:
            'Running in background to find nearby trips',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
  }

  static Future<bool> onIosBackground(ServiceInstance service) async {
    await _updateLocation(service);
    return true;
  }

  static void onStart(ServiceInstance service) async {
    await dotenv.load();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Update location immediately
    await _updateLocation(service);

    // Update every 15 minutes
    service.on('update').listen((event) async {
      await _updateLocation(service);
    });

    // Periodic timer for 15 minutes
    Future.delayed(const Duration(minutes: 15), () async {
      while (true) {
        await _updateLocation(service);
        await Future.delayed(const Duration(minutes: 15));
      }
    });
  }

  static Future<void> _updateLocation(ServiceInstance service) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final prefs = await SharedPreferences.getInstance();
      final driverId = prefs.getString('driverId');
      if (driverId != null) {
        await _sendLocationToBackend(driverId, position, service);
      }
    } catch (e) {
      print('[BG Location Error] $e');
    }
  }

  static Future<void> _sendLocationToBackend(
    String driverId,
    Position position,
    ServiceInstance service,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = dotenv.env['BASE_URL'];
      if (baseUrl == null) return;

      final url = '$baseUrl/drivers/$driverId/location';
      final body = {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      print('[BG Location] Status: ${response.statusCode}');

      if (service is AndroidServiceInstance) {
        final isAvailable = prefs.getBool('is_available') ?? false;
        final statusText = isAvailable ? "Online" : "Offline";

        if (response.statusCode == 200 || response.statusCode == 201) {
          final now = DateTime.now();
          final timeStr =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
          service.setForegroundNotificationInfo(
            title: "Chola Cabs: $statusText",
            content: "Last location update sent at $timeStr",
          );
        } else {
          service.setForegroundNotificationInfo(
            title: "Chola Cabs: Status Issue",
            content: "Failed to send location update",
          );
        }
      }
    } catch (e) {
      print('[BG Location API Error] $e');
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Chola Cabs: Tracking Error",
          content: "Please check your internet connection",
        );
      }
    }
  }

  static Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }
}
