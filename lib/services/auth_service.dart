import 'package:http/http.dart' as http;
import 'dart:convert';
import 'device_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  static String get _baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api/v1';

  static Future<Map<String, dynamic>> verifyDeviceAndLogin(
      String phoneNumber) async {
    try {
      final deviceIdentifier =
          await DeviceService.generateDeviceIdentifier(phoneNumber);
      print('Sending device identifier: $deviceIdentifier');

      final response = await http.post(
        Uri.parse('$_baseUrl/drivers/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'phone_number': phoneNumber,
          'device_id': deviceIdentifier,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'Login successful',
          'data': responseData,
        };
      } else if (response.statusCode == 409) {
        // Device ID mismatch - phone exists but different device
        return {
          'success': false,
          'message': 'device_blocked',
          'showBlockedScreen': true,
        };
      } else {
        return {
          'success': false,
          'message': 'Login failed. Please try again.',
        };
      }
    } catch (e) {
      print('Auth error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
