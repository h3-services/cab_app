import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Gets the unique device ID based on platform
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use androidId as primary, fallback to other identifiers
        String deviceId = androidInfo.id;
        if (deviceId.isEmpty || deviceId == 'unknown') {
          deviceId = '${androidInfo.brand}_${androidInfo.model}_${androidInfo.device}';
        }
        print('Android Device ID: $deviceId');
        return deviceId;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        String deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
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

  /// Generates a unique device identifier combining phone number and device ID
  static Future<String> generateDeviceIdentifier(String phoneNumber) async {
    final deviceId = await getDeviceId();
    final identifier = '${phoneNumber}_$deviceId';
    print('Generated device identifier: $identifier');
    return identifier;
  }
}
