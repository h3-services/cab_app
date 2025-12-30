import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Driver?> getDriver(String phone) async {
    try {
      DocumentSnapshot doc = await _db.collection('drivers').doc(phone).get();
      if (doc.exists) {
        return Driver.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createDriver({
    required String phone,
    required String name,
    required String email,
    required String licenseNumber,
    required String aadhaarNumber,
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleBrand,
    required String vehicleColor,
    required int vehicleYear,
    required int numberOfSeats,
  }) async {
    try {
      print('Creating driver with phone: $phone');
      await _db.collection('drivers').doc(phone).set({
        'name': name,
        'email': email,
        'license_number': licenseNumber,
        'aadhaar_number': aadhaarNumber,
        'vehicle_type': vehicleType,
        'vehicle_number': vehicleNumber,
        'vehicle_brand': vehicleBrand,
        'vehicle_color': vehicleColor,
        'vehicle_year': vehicleYear,
        'number_of_seats': numberOfSeats,
        'kyc_status': 'pending',
        'is_online': false,
        'current_location': const GeoPoint(0, 0),
        'profile_image_url': '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Driver created successfully');
      return true;
    } catch (e) {
      print('Error creating driver: $e');
      return false;
    }
  }
}