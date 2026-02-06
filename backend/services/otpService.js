const crypto = require('crypto');

exports.generateOtp = () => {
  return crypto.randomInt(100000, 999999).toString();
};

exports.hashOtp = (otp) => {
  return crypto.createHash('sha256').update(otp).digest('hex');
};

exports.storeOtp = (phone, otpHash, store, currentResendCount = 0) => {
  const expiresAt = Date.now() + 5 * 60 * 1000;
  
  store.set(phone, {
    otpHash,
    expiresAt,
    attempts: 0,
    resendCount: currentResendCount + 1,
    createdAt: Date.now()
  });
};

exports.verifyOtp = (phone, otp, store) => {
  const stored = store.get(phone);

  if (!stored) {
    return { valid: false, error: 'OTP not found or expired' };
  }

  if (Date.now() > stored.expiresAt) {
    store.delete(phone);
    return { valid: false, error: 'OTP expired' };
  }

  if (stored.attempts >= 3) {
    store.delete(phone);
    return { valid: false, error: 'Too many invalid attempts' };
  }

  const otpHash = this.hashOtp(otp);
  
  if (otpHash !== stored.otpHash) {
    stored.attempts++;
    store.set(phone, stored);
    return { valid: false, error: 'Invalid OTP' };
  }

  return { valid: true };
};

exports.invalidateOtp = (phone, store) => {
  store.delete(phone);
};

exports.checkRateLimit = (phone, rateLimitStore) => {
  const now = Date.now();
  const windowMs = 10 * 60 * 1000;
  
  const record = rateLimitStore.get(phone) || { count: 0, timestamps: [] };
  
  record.timestamps = record.timestamps.filter(ts => now - ts < windowMs);
  
  if (record.timestamps.length >= 3) {
    return false;
  }
  
  record.timestamps.push(now);
  record.count = record.timestamps.length;
  rateLimitStore.set(phone, record);
  
  return true;
};
