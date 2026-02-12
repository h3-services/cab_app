import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://api.cholacabs.in/api';

  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/auth/send-otp');
    
    try {
      debugPrint('POST Request: $url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send OTP: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final url = Uri.parse('$baseUrl/auth/verify-otp');
    
    try {
      debugPrint('POST Request: $url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timeout'),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Invalid OTP');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> checkPhoneExists(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/drivers/check-phone');
    
    final body = {
      "phone_number": phoneNumber,
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
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('API Timeout: checkPhoneExists after 30 seconds');
          throw TimeoutException('Server not responding. Please check your internet connection or try again later.');
        },
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to check phone: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      rethrow;
    }
  }

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

  static Future<void> uploadPoliceVerification(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_police_verification.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/police_verification', 'file', file,
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

  static Future<void> uploadOdometerStart(String tripId, File file) async {
    final ext = file.path.split('.').last;
    await _uploadFile(
        '$baseUrl/uploads/trip/$tripId/odo_start', 'file', file,
        filename: 'odo_start.$ext');
  }

  static Future<void> uploadOdometerEnd(String tripId, File file) async {
    final ext = file.path.split('.').last;
    await _uploadFile(
        '$baseUrl/uploads/trip/$tripId/odo_end', 'file', file,
        filename: 'odo_end.$ext');
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

  /// Get all vehicles and cache them
  static Future<List<Map<String, dynamic>>> getAllVehicles({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Return cached data if available and not forcing refresh
    if (!forceRefresh) {
      final cachedData = prefs.getString('all_vehicles_data');
      if (cachedData != null) {
        try {
          final List<dynamic> vehicles = jsonDecode(cachedData);
          return vehicles.cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error parsing cached vehicles: $e');
        }
      }
    }
    
    // Fetch from API
    final url = Uri.parse('$baseUrl/vehicles/');
    try {
      debugPrint('GET Request: $url');
      final response = await http.get(url);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> vehicles = jsonDecode(response.body);
        final vehiclesList = vehicles.cast<Map<String, dynamic>>();
        
        // Cache the data
        await prefs.setString('all_vehicles_data', jsonEncode(vehicles));
        await prefs.setString('vehicles_last_updated', DateTime.now().toIso8601String());
        
        return vehiclesList;
      } else {
        debugPrint('Failed to get vehicles: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('API Error: $e');
      return [];
    }
  }

  /// Get vehicle by driver ID from cached data
  static Future<Map<String, dynamic>?> getVehicleByDriverId(String driverId) async {
    final vehicles = await getAllVehicles();
    try {
      return vehicles.firstWhere((vehicle) => vehicle['driver_id'] == driverId);
    } catch (e) {
      return null;
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

  static Future<void> updateKycStatus(String driverId, String status) async {
    final url =
        Uri.parse('$baseUrl/drivers/$driverId/kyc-status?kyc_status=$status');
    try {
      debugPrint('PATCH Request: $url');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update KYC status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> clearDriverErrors(String driverId) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId/clear-errors');
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
            'Failed to clear driver errors: ${response.statusCode}');
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
    double? walletBalance,
  }) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId');

    final Map<String, dynamic> body = {
      "name": name,
      "email": email,
      "primary_location": primaryLocation,
      "licence_number": licenceNumber,
      "aadhar_number": aadharNumber,
      "licence_expiry": licenceExpiry,
    };

    if (walletBalance != null) {
      body["wallet_balance"] = walletBalance;
    }

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

  static Future<void> reuploadPoliceVerification(String driverId, File file) async {
    final ext = file.path.split('.').last;
    final filename = 'driver_${driverId}_police_verification.$ext';
    await _uploadFile('$baseUrl/uploads/driver/$driverId/police_verification', 'file', file,
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

  static Future<List<dynamic>> getAllTrips() async {
    final url = Uri.parse('$baseUrl/trips/');
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
        throw Exception('Failed to get all trips: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAvailableTrips() async {
    final url = Uri.parse('$baseUrl/trips/');
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

  static Future<void> startTripV2(String tripId, String startingKm) async {
    final url = Uri.parse('$baseUrl/trips/$tripId/start');
    debugPrint('PATCH Request: $url');
    debugPrint(
        'Request Body: ${jsonEncode({'odo_start': int.parse(startingKm)})}');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'odo_start': int.parse(startingKm)}),
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
            'Failed to start trip (PATCH): ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getTripDetails(String tripId) async {
    final url = Uri.parse('$baseUrl/trips/$tripId');
    try {
      debugPrint('GET Request: $url');
      final response = await http.get(url);

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get trip details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> startTripAPI(String tripId) async {
    final url = Uri.parse('$baseUrl/trips/$tripId/start');
    debugPrint('POST Request: $url');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
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

  static Future<void> completeTripStatus(String tripId) async {
    final url = Uri.parse('$baseUrl/trips/$tripId/complete');
    debugPrint('PATCH Request: $url');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
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

  static Future<void> updateOdometerStart(String tripId, num odoStart) async {
    final url =
        Uri.parse('$baseUrl/trips/$tripId/odometer/start?odo_start=$odoStart');
    debugPrint('PATCH Request (Odometer Start): $url');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to update odometer start: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> updateOdometerEnd(
      String tripId,
      num odoEnd, {
      num? waitingCharges,
      num? interStatePermitCharges,
      num? driverAllowance,
      num? luggageCost,
      num? petCost,
      num? tollCharges,
      num? nightAllowance,
    }) async {
    final queryParams = {'odo_end': odoEnd.toString()};
    if (waitingCharges != null) queryParams['waiting_charges'] = waitingCharges.toString();
    if (interStatePermitCharges != null) queryParams['inter_state_permit_charges'] = interStatePermitCharges.toString();
    if (driverAllowance != null) queryParams['driver_allowance'] = driverAllowance.toString();
    if (luggageCost != null) queryParams['luggage_cost'] = luggageCost.toString();
    if (petCost != null) queryParams['pet_cost'] = petCost.toString();
    if (tollCharges != null) queryParams['toll_charges'] = tollCharges.toString();
    if (nightAllowance != null) queryParams['night_allowance'] = nightAllowance.toString();

    final url = Uri.parse('$baseUrl/trips/$tripId/odometer/end').replace(queryParameters: queryParams);
    debugPrint('PATCH Request (Odometer End): $url');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update odometer end: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> updateWalletBalance(
      String driverId, double newBalance) async {
    final url = Uri.parse(
        '$baseUrl/drivers/$driverId/wallet-balance?new_balance=$newBalance');
    debugPrint('PATCH Request (Wallet Balance): $url');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Sending body as well just in case, but query param is primary for this API
        body: jsonEncode({'new_balance': newBalance}),
      );

      debugPrint('Wallet Balance Update - Status: ${response.statusCode}');
      debugPrint('Wallet Balance Update - Response: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to update wallet balance: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> createPayment({
    required String driverId,
    required double amount,
    required String paymentMethod,
    required String transactionType,
    String? tripId,
    String? transactionId,
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    String status = 'SUCCESS',
  }) async {
    final url = Uri.parse('$baseUrl/../api/v1/payments/');

    final body = {
      "driver_id": driverId,
      "amount": (amount * 100).toInt(),
      "transaction_type": transactionType,
      "status": status,
      "transaction_id": transactionId ??
          razorpayPaymentId ??
          'TXN${DateTime.now().millisecondsSinceEpoch}',
      "razorpay_payment_id": razorpayPaymentId ?? '',
      "razorpay_order_id": razorpayOrderId ?? '',
      "razorpay_signature": razorpaySignature ?? '',
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
            'Failed to create payment: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> updateDriverDeviceId(
      String driverId, String deviceId) async {
    // Using query parameters as it seems to be the pattern for PATCH in this API
    final url =
        Uri.parse('$baseUrl/drivers/$driverId/device-id?device_id=$deviceId');
    debugPrint('PATCH Request (Device ID): $url');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Accept': 'application/json',
        },
      );

      debugPrint('Device ID Update - Status: ${response.statusCode}');
      debugPrint('Device ID Update - Response: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint(
            'WARNING: Failed to update Device ID. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CRITICAL: Error updating Device ID: $e');
    }
  }

  static Future<void> addFcmToken(String driverId, String token) async {
    final url = Uri.parse('$baseUrl/drivers/$driverId/fcm-token');
    debugPrint('POST Request (FCM Token): $url');

    final body = {
      "fcm_token": token,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('FCM Token Update - Status: ${response.statusCode}');
      debugPrint('FCM Token Update - Response: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
            'WARNING: Failed to add FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CRITICAL: Error updating FCM token: $e');
    }
  }

  static Future<Map<String, dynamic>> updateTripExtras(
    String tripId,
    Map<String, dynamic> extras,
  ) async {
    final url = Uri.parse('$baseUrl/trips/$tripId/extras');
    debugPrint('PATCH Request (Trip Extras): $url');
    debugPrint('Body: ${jsonEncode(extras)}');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(extras),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update trip extras: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> updateTripStatus(String tripId, String status) async {
    final url = Uri.parse('$baseUrl/trips/$tripId/status?new_status=$status');
    debugPrint('PATCH Request (Trip Status): $url');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Failed to update trip status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<void> _uploadFile(String url, String fieldName, File file,
      {String? filename, String method = 'POST'}) async {
    try {
      var request = http.MultipartRequest(method, Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        file.path,
        filename: filename,
      ));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }
}
