import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'device_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check device compatibility before OTP (called from login screen)
  static Future<Map<String, dynamic>> checkDeviceCompatibility(String phoneNumber) async {
    try {
      // Generate device identifier
      String deviceIdentifier = await DeviceService.generateDeviceIdentifier(phoneNumber);
      
      // Check if user exists in Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('drivers')
          .doc(phoneNumber)
          .get();

      if (userDoc.exists) {
        // User exists - check device
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? deviceAddress = userData['device_address'];
        
        if (deviceAddress == null || deviceAddress.isEmpty) {
          // First time login - device will be registered after OTP
          return {
            'success': true,
            'message': 'Proceed to OTP verification',
          };
        } else if (deviceAddress == deviceIdentifier) {
          // Same device - allow login
          return {
            'success': true,
            'message': 'Proceed to OTP verification',
          };
        } else {
          // Different device - deny access
          return {
            'success': false,
            'message': 'This account is registered on another device. Contact support to change device.',
          };
        }
      } else {
        // User does not exist - allow to proceed for registration
        return {
          'success': true,
          'message': 'Proceed to OTP verification',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Device verification failed: ${e.toString()}',
      };
    }
  }

  // Verify OTP and handle user flow (called after OTP verification)
  static Future<Map<String, dynamic>> verifyOTPAndProceed(String phoneNumber, String otp) async {
    try {
      // Generate device identifier
      String deviceIdentifier = await DeviceService.generateDeviceIdentifier(phoneNumber);
      
      // Check if user exists in Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('drivers')
          .doc(phoneNumber)
          .get();

      if (userDoc.exists) {
        // User exists - check device
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? deviceAddress = userData['device_address'];
        
        if (deviceAddress == null || deviceAddress.isEmpty) {
          // First time login - store device ID
          await userDoc.reference.update({
            'device_address': deviceIdentifier,
            'updated_at': FieldValue.serverTimestamp(),
          });
          
          return {
            'success': true,
            'action': 'login',
            'message': 'Login successful - Device registered',
          };
        } else if (deviceAddress == deviceIdentifier) {
          // Same device - allow login
          return {
            'success': true,
            'action': 'login',
            'message': 'Login successful',
          };
        } else {
          // Different device - deny access
          return {
            'success': false,
            'action': 'blocked',
            'message': 'User is locked to another device. Contact support.',
          };
        }
      } else {
        // User does not exist - redirect to registration
        return {
          'success': true,
          'action': 'register',
          'message': 'Please complete your registration',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Verification failed: ${e.toString()}',
      };
    }
  }



  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }
}