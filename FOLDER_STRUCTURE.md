# Chola Cabs Driver App - Folder Structure

## Overview
Clean and organized folder structure for better maintainability and scalability.

## Directory Structure

```
lib/
├── constants/
│   ├── app_colors.dart          # App-wide color definitions
│   └── error_codes.dart         # Error code constants
│
├── screens/
│   ├── auth/                    # Authentication screens
│   │   ├── login_screen.dart
│   │   ├── otp_verification_screen.dart
│   │   ├── verification_screen.dart
│   │   ├── personal_details_screen.dart
│   │   └── kyc_upload_screen.dart
│   │
│   ├── trip/                    # Trip management screens
│   │   ├── trip_start_screen.dart
│   │   ├── trip_process_screen.dart
│   │   └── trip_details_input_screen.dart
│   │
│   ├── profile/                 # User profile screens
│   │   ├── profile_screen.dart
│   │   ├── wallet_screen.dart
│   │   ├── settings_screen.dart
│   │   └── notifications_screen.dart
│   │
│   ├── admin/                   # Admin/approval screens
│   │   ├── approval_pending_screen.dart
│   │   ├── contact_admin_screen.dart
│   │   └── device_blocked_screen.dart
│   │
│   ├── dashboard_screen.dart    # Main dashboard
│   ├── splash_screen.dart       # App splash screen
│   └── no_network_screen.dart   # Network error screen
│
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── background_location_service.dart
│   ├── background_service.dart
│   ├── battery_optimization_service.dart
│   ├── connectivity_service.dart
│   ├── device_service.dart
│   ├── firebase_messaging_service.dart
│   ├── image_picker_service.dart
│   ├── location_tracking_service.dart
│   ├── notification_plugin.dart
│   ├── notification_service.dart
│   ├── otp_service.dart
│   ├── payment_service.dart
│   ├── permission_service.dart
│   ├── razorpay_service.dart
│   ├── trip_state_service.dart
│   └── workmanager_location_service.dart
│
├── widgets/
│   ├── buttons/
│   │   └── gradient_button.dart
│   ├── cards/
│   │   └── info_card.dart
│   ├── common/
│   │   ├── app_drawer.dart
│   │   ├── app_logo.dart
│   │   ├── custom_app_bar.dart
│   │   └── gradient_background.dart
│   ├── dialogs/
│   │   ├── cancel_trip_dialog.dart
│   │   ├── payment_success_dialog.dart
│   │   └── trip_details_dialog.dart
│   ├── inputs/
│   │   ├── custom_dropdown_field.dart
│   │   ├── custom_text_field.dart
│   │   ├── otp_input_field.dart
│   │   └── phone_input_field.dart
│   ├── bottom_navigation.dart
│   └── widgets.dart
│
└── main.dart                    # App entry point
```

## Removed Files
- `menu_screen.dart` - Functionality integrated into app_drawer
- `document_view_screen.dart` - Unused screen

## Import Path Changes

### Authentication Screens
- `screens/login_screen.dart` → `screens/auth/login_screen.dart`
- `screens/otp_verification_screen.dart` → `screens/auth/otp_verification_screen.dart`
- `screens/verification_screen.dart` → `screens/auth/verification_screen.dart`
- `screens/personal_details_screen.dart` → `screens/auth/personal_details_screen.dart`
- `screens/kyc_upload_screen.dart` → `screens/auth/kyc_upload_screen.dart`

### Trip Screens
- `screens/trip_start_screen.dart` → `screens/trip/trip_start_screen.dart`
- `screens/trip_process_screen.dart` → `screens/trip/trip_process_screen.dart`
- `screens/trip_details_input_screen.dart` → `screens/trip/trip_details_input_screen.dart`

### Profile Screens
- `screens/profile_screen.dart` → `screens/profile/profile_screen.dart`
- `screens/wallet_screen.dart` → `screens/profile/wallet_screen.dart`
- `screens/settings_screen.dart` → `screens/profile/settings_screen.dart`
- `screens/notifications_screen.dart` → `screens/profile/notifications_screen.dart`

### Admin Screens
- `screens/approval_pending_screen.dart` → `screens/admin/approval_pending_screen.dart`
- `screens/contact_admin_screen.dart` → `screens/admin/contact_admin_screen.dart`
- `screens/device_blocked_screen.dart` → `screens/admin/device_blocked_screen.dart`

## Benefits
1. **Better Organization**: Related screens grouped together
2. **Easier Navigation**: Clear folder structure
3. **Scalability**: Easy to add new features
4. **Maintainability**: Logical separation of concerns
5. **Clean Codebase**: Removed unused files
