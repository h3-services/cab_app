import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Gets the unique device ID based on platform
  /// Uses Android ID (hardware-based, persists across uninstall)
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Android ID - unique per device, persists across app uninstall/reinstall
        final deviceId = androidInfo.id;
        print('Android Device ID: $deviceId');
        return deviceId;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor - unique per vendor, persists until all vendor apps uninstalled
        final deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
        print('iOS Device ID: $deviceId');
        return deviceId;
      } else {
        return 'unsupported_platform';
      }
    } catch (e) {
      print('Error getting device ID: $e');
      return 'error_getting_device_id';
    }
  }

  /// Generates a unique device identifier
  static Future<String> generateDeviceIdentifier(String phoneNumber) async {
    final deviceId = await getDeviceId();
    print('Device identifier: $deviceId');
    return deviceId;
  }
}
