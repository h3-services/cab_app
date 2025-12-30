import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'device_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> createUser({
    required String phoneNumber,
    required String name,
    required String email,
    required String licenseNumber,
    required String aadhaarNumber,
    required String vehicleType,
    required String vehicleNumber,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehicleColor,
    required int numberOfSeats,
    Map<String, String>? imageUrls,
  }) async {
    try {
      String deviceAddress = await DeviceService.getDeviceAddress();
      String deviceId = await DeviceService.getDeviceId();

      UserModel user = UserModel(
        aadhaarNumber: aadhaarNumber,
        createdAt: Timestamp.now(),
        currentLocation: const GeoPoint(0, 0),
        deviceAddress: deviceAddress,
        deviceId: deviceId,
        email: email,
        isOnline: false,
        kycStatus: 'pending',
        licenseNumber: licenseNumber,
        name: name,
        numberOfSeats: numberOfSeats,
        profileImageUrl: imageUrls?['Profile Picture'] ?? '',
        updatedAt: Timestamp.now(),
        vehicleBrand: vehicleBrand,
        vehicleColor: vehicleColor,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        vehicleYear: DateTime.now().year,
      );

      Map<String, dynamic> userData = user.toFirestore();
      if (imageUrls != null) {
        userData['kycDocuments'] = imageUrls;
      }

      await _firestore
          .collection('drivers')
          .doc(phoneNumber)
          .set(userData);

      return true;
    } catch (e) {
      return false;
    }
  }
}