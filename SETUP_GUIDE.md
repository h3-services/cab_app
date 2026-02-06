# WhatsApp OTP Authentication - Setup Guide

## 📱 Flutter App Setup

1. **Add http dependency** (already in pubspec.yaml):
```yaml
dependencies:
  http: ^1.1.0
```

2. **Run**:
```bash
flutter pub get
```

3. **Update main.dart** to start with PhoneInputScreen:
```dart
import 'package:flutter/material.dart';
import 'screens/phone_input_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTP Auth',
      home: const PhoneInputScreen(),
    );
  }
}
```

## 🖥️ Backend Setup

1. **Navigate to backend folder**:
```bash
cd backend
```

2. **Install dependencies**:
```bash
npm install
```

3. **Create .env file**:
```bash
copy .env.example .env
```

4. **Configure WhatsApp credentials in .env**:

### Get WhatsApp Credentials:

**Step 1: Meta Business Account**
- Go to https://business.facebook.com
- Create/Select Business Account

**Step 2: WhatsApp Business API**
- Go to https://developers.facebook.com
- Create App → Business → WhatsApp
- Add WhatsApp Product

**Step 3: Get Phone Number ID**
- Go to WhatsApp → API Setup
- Copy "Phone number ID"
- Add to .env: `WHATSAPP_PHONE_NUMBER_ID=your_id`

**Step 4: Get Access Token**
- Go to WhatsApp → API Setup
- Generate Permanent Token
- Add to .env: `WHATSAPP_ACCESS_TOKEN=your_token`

**Step 5: Create OTP Template**
- Go to WhatsApp → Message Templates
- Create new template:
  - Category: AUTHENTICATION
  - Name: otp_template
  - Body: "Your OTP is {{1}}. Valid for 5 minutes."
  - Button: Copy code (autofill)
- Wait for approval (usually instant for AUTHENTICATION)
- Add to .env: `WHATSAPP_TEMPLATE_NAME=otp_template`

5. **Start server**:
```bash
npm start
```

Server runs on http://localhost:3000

## 🧪 Testing

1. Start backend server
2. Run Flutter app
3. Enter phone: +91XXXXXXXXXX
4. Check WhatsApp for OTP
5. Enter OTP in app

## ✅ Features Implemented

### Flutter App:
- ✅ Phone input with +91 validation
- ✅ OTP verification screen (6 digits)
- ✅ Auto-focus & paste support
- ✅ 60-second countdown timer
- ✅ Resend OTP (max 3 times)
- ✅ Error handling (expired, wrong, too many attempts)
- ✅ Success navigation to dashboard

### Backend:
- ✅ Crypto-secure OTP generation
- ✅ SHA-256 hashing
- ✅ 5-minute expiry
- ✅ Max 3 verification attempts
- ✅ Rate limiting (3 OTPs/10 min)
- ✅ WhatsApp Cloud API integration
- ✅ JWT token generation
- ✅ Clean error messages

## 🔒 Security

- OTP never stored in plain text
- SHA-256 hashing
- Rate limiting prevents abuse
- JWT for session management
- Environment variables for secrets

## 📝 API Contract

### POST /api/send-otp
```json
Request: { "phone": "+91XXXXXXXXXX" }
Response: { "success": true, "message": "OTP sent successfully on WhatsApp" }
```

### POST /api/verify-otp
```json
Request: { "phone": "+91XXXXXXXXXX", "otp": "123456" }
Response: { "success": true, "message": "OTP verified successfully", "token": "jwt_token" }
```

### POST /api/resend-otp
```json
Request: { "phone": "+91XXXXXXXXXX" }
Response: { "success": true, "message": "OTP resent successfully on WhatsApp" }
```

## 🚀 Production Checklist

- [ ] Use production WhatsApp Business Account
- [ ] Get approved AUTHENTICATION template
- [ ] Use permanent access token
- [ ] Set strong JWT_SECRET
- [ ] Use database instead of Map (Redis/MongoDB)
- [ ] Add logging & monitoring
- [ ] Deploy backend (AWS/Heroku/Railway)
- [ ] Update Flutter baseUrl to production URL
- [ ] Enable HTTPS
- [ ] Add phone number verification
