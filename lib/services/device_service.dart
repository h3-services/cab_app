import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Gets the unique device ID based on platform
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;

        // Combine 3 distinct hardware identifiers for Android
        final String id = androidInfo.id; // Build ID / Hardware ID
        final String hardware = androidInfo.hardware; // Hardware Name
        final String model = androidInfo.model; // Device Model

        final String deviceId = '${id}_${hardware}_${model}';
        print('Android Combined Device ID: $deviceId');
        return deviceId;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;

        // Combine 3 identifiers for iOS for consistency
        final String vendorId = iosInfo.identifierForVendor ?? 'unknown';
        final String model = iosInfo.model;
        final String systemName = iosInfo.systemName;

        final String deviceId = '${vendorId}_${model}_${systemName}';
        print('iOS Combined Device ID: $deviceId');
        return deviceId;
      } else {
        return 'unsupported_platform';
      }
    } catch (e) {
      print('Error getting device ID: $e');
      return 'error_getting_device_id';
    }
  }

  /// Generates a unique device identifier combining three hardware IDs
  static Future<String> generateDeviceIdentifier(String phoneNumber) async {
    final deviceId = await getDeviceId();
    // Returning only the hardware combined ID as requested
    print('Generated hardware-based device identifier: $deviceId');
    return deviceId;
  }
}
