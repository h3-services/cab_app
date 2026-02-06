const otpService = require('../services/otpService');
const whatsappService = require('../services/whatsappService');
const jwt = require('jsonwebtoken');

const otpStore = new Map();
const rateLimitStore = new Map();

exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone || !phone.startsWith('+91') || phone.length !== 13) {
      return res.status(400).json({ error: 'Invalid phone number format' });
    }

    if (!otpService.checkRateLimit(phone, rateLimitStore)) {
      return res.status(429).json({ error: 'Too many OTP requests. Please try after 10 minutes' });
    }

    const otp = otpService.generateOtp();
    const otpHash = otpService.hashOtp(otp);

    otpService.storeOtp(phone, otpHash, otpStore);

    await whatsappService.sendWhatsappOtp(phone, otp);

    res.json({ success: true, message: 'OTP sent successfully on WhatsApp' });
  } catch (error) {
    console.error('Send OTP error:', error);
    res.status(500).json({ error: error.message || 'Failed to send OTP' });
  }
};

exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone and OTP are required' });
    }

    const result = otpService.verifyOtp(phone, otp, otpStore);

    if (!result.valid) {
      return res.status(400).json({ error: result.error });
    }

    otpService.invalidateOtp(phone, otpStore);

    const token = jwt.sign(
      { phone, timestamp: Date.now() },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({ success: true, message: 'OTP verified successfully', token });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ error: 'Failed to verify OTP' });
  }
};

exports.resendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const stored = otpStore.get(phone);
    if (stored && stored.resendCount >= 3) {
      return res.status(429).json({ error: 'Maximum resend limit reached' });
    }

    if (!otpService.checkRateLimit(phone, rateLimitStore)) {
      return res.status(429).json({ error: 'Too many OTP requests. Please try after 10 minutes' });
    }

    const otp = otpService.generateOtp();
    const otpHash = otpService.hashOtp(otp);

    otpService.storeOtp(phone, otpHash, otpStore, stored?.resendCount || 0);

    await whatsappService.sendWhatsappOtp(phone, otp);

    res.json({ success: true, message: 'OTP resent successfully on WhatsApp' });
  } catch (error) {
    console.error('Resend OTP error:', error);
    res.status(500).json({ error: 'Failed to resend OTP' });
  }
};
