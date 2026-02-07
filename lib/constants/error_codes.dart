class ErrorCodes {
  static const Map<int, String> errors = {
    // Document Verification (1000 Series)
    1001: 'Driving License is blurry or unclear',
    1002: 'Driving License has expired',
    1003: 'Driving License information doesn\'t match profile',
    1004: 'Aadhaar Card is blurry or unclear',
    1005: 'Aadhaar Card information doesn\'t match profile',
    1006: 'Profile Photo is not clear or visible',
    1007: 'RC Book is blurry or unclear',
    1008: 'RC Book has expired',
    1009: 'FC Certificate is blurry or unclear',
    1010: 'FC Certificate has expired',
    1011: 'Car Front Photo is blurry or unclear',
    1012: 'Wrong document uploaded',
    1013: 'Car Back Photo is blurry or unclear',
    1014: 'Car Left Photo is blurry or unclear',
    1015: 'Car Right Photo is blurry or unclear',
    1016: 'Car Inside Photo is blurry or unclear',
    1017: 'Police Verification is blurry or unclear',
    1018: 'Police Verification has expired',
    1019: 'Police Verification information doesn\'t match profile',
    // Personal Information (2000 Series)
    2001: 'Mobile Number is invalid or verification failed',
    2002: 'Email Address is invalid or verification failed',
    2003: 'Name mismatch or invalid',
    2004: 'License Number mismatch or invalid',
    2005: 'Aadhaar Number mismatch or invalid',
    2006: 'Primary Location mismatch or invalid',
    2007: 'Device ID mismatch or invalid',
    2008: 'License expiry date mismatch or expired',
    // Vehicle Information (3000 Series)
    3001: 'Vehicle Registration Number mismatch or invalid',
    3002: 'Vehicle Type not supported',
    3003: 'Vehicle Model mismatch',
    3004: 'Vehicle Brand mismatch',
    3005: 'Vehicle Color mismatch',
    3006: 'Seating Capacity mismatch or invalid',
    3007: 'RC expiry date mismatch or expired',
    3008: 'FC expiry date mismatch or expired',
  };

  static String getMessage(int code) => errors[code] ?? 'Unknown error';
}
