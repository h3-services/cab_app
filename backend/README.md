# WhatsApp OTP Backend

Production-ready Node.js backend for WhatsApp OTP authentication.

## Setup

1. Install dependencies:
```bash
cd backend
npm install
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Configure WhatsApp credentials in `.env`:
- Get PHONE_NUMBER_ID from Meta Business Suite
- Get permanent ACCESS_TOKEN from Meta Developer Console
- Create and approve AUTHENTICATION template

4. Start server:
```bash
npm start
```

## API Endpoints

- `POST /api/send-otp` - Send OTP
- `POST /api/verify-otp` - Verify OTP
- `POST /api/resend-otp` - Resend OTP

## Security Features

✅ Crypto-secure OTP generation
✅ SHA-256 hashing
✅ Rate limiting (3 OTPs/10 min)
✅ Max 3 verification attempts
✅ 5-minute OTP expiry
✅ JWT authentication
