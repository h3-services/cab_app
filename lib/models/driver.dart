import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String phone;
  final String aadhaarNumber;
  final DateTime createdAt;
  final GeoPoint currentLocation;
  final String email;
  final bool isOnline;
  final String kycStatus;
  final String licenseNumber;
  final String name;
  final int numberOfSeats;
  final String profileImageUrl;
  final DateTime updatedAt;
  final String vehicleBrand;
  final String vehicleColor;
  final String vehicleNumber;
  final String vehicleType;
  final int vehicleYear;

  Driver({
    required this.phone,
    required this.aadhaarNumber,
    required this.createdAt,
    required this.currentLocation,
    required this.email,
    required this.isOnline,
    required this.kycStatus,
    required this.licenseNumber,
    required this.name,
    required this.numberOfSeats,
    required this.profileImageUrl,
    required this.updatedAt,
    required this.vehicleBrand,
    required this.vehicleColor,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleYear,
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Driver(
      phone: doc.id,
      aadhaarNumber: data['aadhaar_number']?.toString() ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      currentLocation: data['current_location'] ?? const GeoPoint(0, 0),
      email: data['email'] ?? '',
      isOnline: data['is_online'] ?? false,
      kycStatus: data['kyc_status'] ?? 'pending',
      licenseNumber: data['license_number'] ?? '',
      name: data['name'] ?? '',
      numberOfSeats: data['number_of_seats'] ?? 4,
      profileImageUrl: data['profile_image_url'] ?? '',
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      vehicleBrand: data['vehicle_brand'] ?? '',
      vehicleColor: data['vehicle_color'] ?? '',
      vehicleNumber: data['vehicle_number'] ?? '',
      vehicleType: data['vehicle_type'] ?? '',
      vehicleYear: data['vehicle_year'] ?? 2000,
    );
  }
}