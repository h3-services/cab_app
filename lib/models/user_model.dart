import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String aadhaarNumber;
  final Timestamp? createdAt;
  final GeoPoint currentLocation;
  final String deviceAddress;
  final String deviceId;
  final String email;
  final bool isOnline;
  final String kycStatus;
  final String licenseNumber;
  final String name;
  final int numberOfSeats;
  final String profileImageUrl;
  final Timestamp? updatedAt;
  final String vehicleBrand;
  final String vehicleColor;
  final String vehicleNumber;
  final String vehicleType;
  final int vehicleYear;

  UserModel({
    this.id,
    required this.aadhaarNumber,
    this.createdAt,
    required this.currentLocation,
    required this.deviceAddress,
    required this.deviceId,
    required this.email,
    required this.isOnline,
    required this.kycStatus,
    required this.licenseNumber,
    required this.name,
    required this.numberOfSeats,
    required this.profileImageUrl,
    this.updatedAt,
    required this.vehicleBrand,
    required this.vehicleColor,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleYear,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      aadhaarNumber: data['aadhaar_number'] ?? '',
      createdAt: data['created_at'],
      currentLocation: data['current_location'] ?? const GeoPoint(0, 0),
      deviceAddress: data['device_address'] ?? '',
      deviceId: data['device_id'] ?? '',
      email: data['email'] ?? '',
      isOnline: data['is_online'] ?? false,
      kycStatus: data['kyc_status'] ?? 'pending',
      licenseNumber: data['license_number'] ?? '',
      name: data['name'] ?? '',
      numberOfSeats: data['number_of_seats'] ?? 0,
      profileImageUrl: data['profile_image_url'] ?? '',
      updatedAt: data['updated_at'],
      vehicleBrand: data['vehicle_brand'] ?? '',
      vehicleColor: data['vehicle_color'] ?? '',
      vehicleNumber: data['vehicle_number'] ?? '',
      vehicleType: data['vehicle_type'] ?? '',
      vehicleYear: data['vehicle_year'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'aadhaar_number': aadhaarNumber,
      'created_at': createdAt,
      'current_location': currentLocation,
      'device_address': deviceAddress,
      'device_id': deviceId,
      'email': email,
      'is_online': isOnline,
      'kyc_status': kycStatus,
      'license_number': licenseNumber,
      'name': name,
      'number_of_seats': numberOfSeats,
      'profile_image_url': profileImageUrl,
      'updated_at': updatedAt,
      'vehicle_brand': vehicleBrand,
      'vehicle_color': vehicleColor,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'vehicle_year': vehicleYear,
    };
  }
}