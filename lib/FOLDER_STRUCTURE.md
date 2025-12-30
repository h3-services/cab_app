# Folder Structure

This document outlines the organized folder structure for the Cap App Flutter project.

## Directory Structure

```
lib/
├── constants/          # App-wide constants
│   └── app_colors.dart
├── models/            # Data models and entities
├── screens/           # UI screens/pages

│   ├── kyc_upload_screen.dart
│   ├── login_screen.dart
│   ├── personal_details_screen.dart
│   ├── splash_screen.dart
│   └── verification_screen.dart
├── services/          # API services and business logic
├── theme/             # App theming and styling
│   └── app_theme.dart
├── utils/             # Utility functions and helpers
│   └── validators.dart
├── widgets/           # Reusable UI components
│   ├── buttons/       # Button widgets
│   │   └── gradient_button.dart
│   ├── cards/         # Card widgets
│   │   └── info_card.dart
│   ├── common/        # Common widgets
│   │   ├── app_logo.dart
│   │   ├── custom_app_bar.dart
│   │   └── gradient_background.dart
│   ├── inputs/        # Input field widgets
│   │   ├── custom_dropdown_field.dart
│   │   ├── custom_text_field.dart
│   │   ├── otp_input_field.dart
│   │   └── phone_input_field.dart
│   └── widgets.dart   # Barrel file for easy imports
├── firebase_options.dart
└── main.dart
```

## Widget Categories

### Common Widgets (`widgets/common/`)
- **GradientBackground**: Reusable gradient background container
- **AppLogo**: Standardized app logo with customizable dimensions
- **CustomAppBar**: Consistent app bar styling across screens

### Button Widgets (`widgets/buttons/`)
- **GradientButton**: Reusable button with gradient styling

### Input Widgets (`widgets/inputs/`)
- **CustomTextField**: Standardized text input with validation
- **OtpInputField**: Specialized OTP digit input field
- **PhoneInputField**: Phone number input with country code
- **CustomDropdownField**: Reusable dropdown selection field

### Card Widgets (`widgets/cards/`)
- **InfoCard**: Container for grouping related form sections

## Usage

Import all widgets using the barrel file:
```dart
import '../widgets/widgets.dart';
```

Or import specific widgets:
```dart
import '../widgets/common/gradient_background.dart';
import '../widgets/buttons/gradient_button.dart';
```

## Benefits

1. **Reusability**: Components can be used across multiple screens
2. **Consistency**: Uniform styling and behavior
3. **Maintainability**: Changes to widgets affect all usage instances
4. **Organization**: Clear separation of concerns
5. **Scalability**: Easy to add new widgets and features