import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api/v1';

  static Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String phoneNumber,
    required String email,
    required String primaryLocation,
    required String licenceNumber,
    required String aadharNumber,
    required String licenceExpiry,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/drivers/');

    final body = {
      "name": name,
      "phone_number": phoneNumber,
      "email": email,
      "primary_location": primaryLocation,
      "licence_number": licenceNumber,
      "aadhar_number": aadharNumber,
      "licence_expiry": licenceExpiry,
      "device_id": deviceId,
    };

    try {
      debugPrint('POST Request: $url');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to register driver: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> registerVehicle({
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehicleNumber,
    required String vehicleColor,
    required int seatingCapacity,
    required String driverId,
    required String rcExpiryDate,
    required String fcExpiryDate,
  }) async {
    final url = Uri.parse('$baseUrl/vehicles/');

    final body = {
      "vehicle_type": vehicleType,
      "vehicle_brand": vehicleBrand,
      "vehicle_model": vehicleModel,
      "vehicle_number": vehicleNumber,
      "vehicle_color": vehicleColor,
      "seating_capacity": seatingCapacity,
      "driver_id": driverId,
      "rc_expiry_date": rcExpiryDate,
      "fc_expiry_date": fcExpiryDate,
    };

    try {
      debugPrint('POST Request: $url');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to register vehicle: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> uploadDriverPhoto(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_photo.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/photo', 'file', file,
        filename: filename);
  }

  static Future<void> uploadAadhar(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_aadhar.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/aadhar', 'file', file,
        filename: filename);
  }

  static Future<void> uploadLicence(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_licence.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/licence', 'file', file,
        filename: filename);
  }

  static Future<void> uploadVehicleRC(String vehicleId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_rc.$ext';
    await _uploadFile('$baseUrl/uploads/vehicle/$vehicleId/rc', 'file', file,
        filename: filename);
  }

  static Future<void> uploadVehicleFC(String vehicleId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_fc.$ext';
    await _uploadFile('$baseUrl/uploads/vehicle/$vehicleId/fc', 'file', file,
        filename: filename);
  }

  static Future<void> uploadVehiclePhoto(
      String vehicleId, String position, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_$position.$ext';
    await _uploadFile(
        '$baseUrl/uploads/vehicle/$vehicleId/photo/$position', 'file', file,
        filename: filename);
  }

  static Future<void> updateDriverAvailability(
      String driverId, bool isAvailable) async {
    final url = Uri.parse(
        '$baseUrl/drivers/$driverId/availability?is_available=$isAvailable');
    try {
      debugPrint('PATCH Request: $url');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update availability: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> _uploadFile(String url, String fieldName, File file,
      {String? filename}) async {
    try {
      debugPrint('UPLOAD Request: $url');
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        filename: filename,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Upload failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Upload Error: $e');
      throw Exception('Upload error: $e');
    }
  }
}
