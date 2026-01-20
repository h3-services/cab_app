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

  static Future<Map<String, dynamic>> getDriverDetails(String driverId) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId');
    try {
      debugPrint('GET Request: $url');
      final response = await http.get(url);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get driver details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
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

  static Future<Map<String, dynamic>> updateDriver({
    required String driverId,
    required String name,
    required String email,
    required String primaryLocation,
    required String licenceNumber,
    required String aadharNumber,
    required String licenceExpiry,
  }) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId');

    final body = {
      "name": name,
      "email": email,
      "primary_location": primaryLocation,
      "licence_number": licenceNumber,
      "aadhar_number": aadharNumber,
      "licence_expiry": licenceExpiry,
    };

    try {
      debugPrint('PUT Request: $url');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update driver: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> updateVehicle({
    required String vehicleId,
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehicleColor,
    required int seatingCapacity,
    required String rcExpiryDate,
    required String fcExpiryDate,
  }) async {
    final url = Uri.parse('$baseUrl/vehicles/$vehicleId');

    final body = {
      "vehicle_type": vehicleType,
      "vehicle_brand": vehicleBrand,
      "vehicle_model": vehicleModel,
      "vehicle_color": vehicleColor,
      "seating_capacity": seatingCapacity,
      "rc_expiry_date": rcExpiryDate,
      "fc_expiry_date": fcExpiryDate,
    };

    try {
      debugPrint('PUT Request: $url');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update vehicle: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Re-upload methods (using PUT)
  static Future<void> reuploadDriverPhoto(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_photo.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/photo', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<void> reuploadAadhar(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_aadhar.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/aadhar', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<void> reuploadLicence(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_licence.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/licence', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<void> reuploadVehicleRC(String vehicleId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_rc.$ext';
    await _uploadFile('$baseUrl/uploads/vehicle/$vehicleId/rc', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<void> reuploadVehicleFC(String vehicleId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_fc.$ext';
    await _uploadFile('$baseUrl/uploads/vehicle/$vehicleId/fc', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<void> reuploadVehiclePhoto(
      String vehicleId, String position, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'vehicle_${vehicleId}_$position.$ext';
    await _uploadFile(
        '$baseUrl/uploads/vehicle/$vehicleId/photo/$position', 'file', file,
        filename: filename, method: 'PUT');
  }

  static Future<List<dynamic>> getAvailableTrips() async {
    final url = Uri.parse('$baseUrl/trips/available');
    debugPrint('GET Request: $url');
    try {
      final response = await http.get(url);
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        // Handle common wrapper cases if any, otherwise return empty or throw
        return [];
      } else {
        throw Exception('Failed to load trips: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      // Return empty list on error to allow UI to show placeholder or empty state
      return [];
    }
  }

  static Future<List<dynamic>> getDriverRequests(String driverId) async {
    final url = Uri.parse('$baseUrl/trip-requests/driver/$driverId');
    try {
      debugPrint('GET Request: $url');
      final response = await http.get(url);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        return [];
      } else {
        throw Exception(
            'Failed to get driver requests: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      return [];
    }
  }

  static Future<void> updateRequestStatus(
      String requestId, String status) async {
    final url = Uri.parse(
        '$baseUrl/trip-requests/$requestId/status?new_status=$status');
    debugPrint('PATCH Request: $url');
    try {
      final response = await http.patch(url);
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> createTripRequest(String tripId, String driverId) async {
    final url = Uri.parse(
        '$baseUrl/trip-requests/?trip_id=$tripId&driver_id=$driverId');
    debugPrint('POST Request: $url');
    try {
      final response = await http.post(url);
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Failed to create trip request: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> completeTrip(
      String requestId, Map<String, dynamic> details) async {
    final url = Uri.parse('$baseUrl/trip-requests/$requestId/complete');
    debugPrint('POST Request: $url');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(details),
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Failed to complete trip: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> startTrip(String requestId, String startingKm) async {
    final url = Uri.parse('$baseUrl/trip-requests/$requestId/start');
    debugPrint('POST Request: $url');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'starting_km': startingKm}),
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Failed to start trip: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> _uploadFile(String url, String fieldName, File file,
      {String? filename, String method = 'POST'}) async {
    try {
      debugPrint('$method Upload Request: $url');
      var request = http.MultipartRequest(method, Uri.parse(url));
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
