import 'package:flutter_test/flutter_test.dart';
import 'package:cap_app/services/device_service.dart';

void main() {
  group('DeviceService Tests', () {
    test('generateDeviceIdentifier should combine phone and device ID', () async {
      // This test will work in a real device environment
      // For testing purposes, we'll mock the behavior
      
      String phoneNumber = '9876543210';
      String deviceIdentifier = await DeviceService.generateDeviceIdentifier(phoneNumber);
      
      // The identifier should start with the phone number
      expect(deviceIdentifier.startsWith(phoneNumber), true);
      
      // The identifier should contain an underscore separator
      expect(deviceIdentifier.contains('_'), true);
      
      // The identifier should be longer than just the phone number
      expect(deviceIdentifier.length, greaterThan(phoneNumber.length));
    });

    test('getDeviceId should return a string', () async {
      String deviceId = await DeviceService.getDeviceId();
      
      // Device ID should be a string (might be empty in test environment)
      expect(deviceId, isA<String>());
    });
  });
}