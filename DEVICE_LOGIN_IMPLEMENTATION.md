# Device-Specific Login Implementation

## Overview
This implementation ensures that each user can only login from a single device. The system combines the user's phone number with their device's hardware ID to create a unique device identifier that is stored in Firestore.

## How It Works

### 1. Device Identification
- When a user attempts to login, the app retrieves the device's unique hardware ID
- For Android: Uses `AndroidDeviceInfo.id`
- For iOS: Uses `IosDeviceInfo.identifierForVendor`
- The device ID is combined with the phone number to create a unique identifier: `{phoneNumber}_{deviceId}`

### 2. Login Flow

#### First Time Login (New User)
1. User enters phone number
2. System generates device identifier
3. System checks if user exists in Firestore
4. If user doesn't exist, creates new user document with device_id
5. User is logged in successfully

#### Existing User - Same Device
1. User enters phone number
2. System generates device identifier
3. System finds user in Firestore
4. Compares stored device_id with current device identifier
5. If they match, user is logged in successfully

#### Existing User - Different Device
1. User enters phone number
2. System generates device identifier
3. System finds user in Firestore
4. Compares stored device_id with current device identifier
5. If they don't match, login is denied with error message
6. User must contact support to reset device

## Files Modified/Created

### New Files
1. `lib/services/device_service.dart` - Handles device ID retrieval
2. `lib/services/auth_service.dart` - Manages authentication and device verification
3. `lib/models/user_model.dart` - User data model matching Firestore structure
4. `lib/widgets/auth_guard.dart` - Protects routes requiring authentication

### Modified Files
1. `pubspec.yaml` - Added dependencies:
   - `cloud_firestore: ^5.7.0`
   - `device_info_plus: ^10.1.2`

2. `lib/screens/login_screen.dart` - Integrated device verification
3. `lib/main.dart` - Added Firebase initialization and routing
4. `android/app/src/main/AndroidManifest.xml` - Added required permissions

## Firestore Structure

### Users Collection
```
users/{userId}
  - aadhaar_number: string (stores phone number)
  - device_id: string (format: "{phoneNumber}_{hardwareId}")
  - created_at: timestamp
  - updated_at: timestamp
  - email: string
  - name: string
  - kyc_status: string
  - is_online: boolean
  - current_location: geopoint
  - device_address: string
  - license_number: string
  - number_of_seats: number
  - profile_image_url: string
  - vehicle_brand: string
  - vehicle_color: string
  - vehicle_number: string
  - vehicle_type: string
  - vehicle_year: number
```

## Security Features

1. **Device Binding**: Each account is permanently bound to the first device used for login
2. **Automatic Detection**: System automatically detects and prevents multi-device access
3. **No Manual Override**: Users cannot bypass device restriction without admin intervention
4. **Persistent Storage**: Device ID is stored in Firestore, not locally

## Installation Steps

1. Install dependencies:
```bash
flutter pub get
```

2. Ensure Firebase is properly configured:
   - `google-services.json` in `android/app/`
   - `firebase_options.dart` is generated

3. Run the app:
```bash
flutter run
```

## Testing

### Test Scenario 1: New User
1. Enter a new phone number
2. Click Continue
3. User should be logged in and device_id stored in Firestore

### Test Scenario 2: Same Device Login
1. Logout and login again with same phone number on same device
2. User should be logged in successfully

### Test Scenario 3: Different Device Login
1. Try to login with same phone number on a different device
2. Login should be denied with error message

## Important Notes

1. **Device ID Persistence**: The Android device ID is persistent across app reinstalls but may change if the device is factory reset
2. **OTP Verification**: Current implementation uses a dummy OTP for demonstration. Implement proper Firebase Phone Authentication in production
3. **Error Handling**: All device verification errors are caught and displayed to the user
4. **Support Process**: Establish a support process for users who need to change devices

## Future Enhancements

1. Implement proper Firebase Phone Authentication with OTP
2. Add admin panel to manage device resets
3. Add device change request feature
4. Implement device history tracking
5. Add biometric authentication for additional security

## Troubleshooting

### Issue: Device ID returns empty string
- Check Android permissions in AndroidManifest.xml
- Ensure device_info_plus plugin is properly installed

### Issue: Firestore permission denied
- Check Firestore security rules
- Ensure Firebase is properly initialized

### Issue: User can login from multiple devices
- Verify device_id is being stored correctly in Firestore
- Check that device identifier generation is working properly
