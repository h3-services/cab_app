import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Gets the unique device ID based on platform
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id; // Android ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      } else {
        return 'unsupported_platform';
      }
    } catch (e) {
      return 'error_getting_device_id';
    }
  }

  /// Generates a unique device identifier combining phone number and device ID
  static Future<String> generateDeviceIdentifier(String phoneNumber) async {
    final deviceId = await getDeviceId();
    return '${phoneNumber}_$deviceId';
  }
}
