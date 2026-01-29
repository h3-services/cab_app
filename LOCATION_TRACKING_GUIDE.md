# 📍 Background Location Tracking - Complete Guide

## ✅ Implementation Status

Your app is fully implemented and ready to use. Location is captured every 15 minutes and sent to:

```
POST /api/v1/drivers/{driver_id}/location
```

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Save driver_id After Login
```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('auth_token', token);
await prefs.setString('driver_id', driverId.toString());
await prefs.setString('backend_url', 'https://your-backend.com');
```

### Step 2: Create Backend Endpoint
```
POST /api/v1/drivers/{driver_id}/location
Authorization: Bearer <token>
Content-Type: application/json

{
  "latitude": 12.9716,
  "longitude": 77.5946,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Step 3: Create Database Table
```sql
CREATE TABLE locations (
  id INT PRIMARY KEY AUTO_INCREMENT,
  driver_id INT NOT NULL,
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,
  timestamp DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (driver_id) REFERENCES drivers(id),
  INDEX idx_driver_timestamp (driver_id, timestamp)
);
```

---

## 📱 Testing

### Change Timer to 30 Seconds (for quick testing)
Edit `lib/services/background_service.dart` line ~60:
```dart
// Change from:
Timer.periodic(const Duration(minutes: 15), (timer) async {

// To:
Timer.periodic(const Duration(seconds: 30), (timer) async {
```

### View Logs
**Android**:
```bash
flutter run
# In another terminal:
adb logcat | grep "LOCATION CAPTURED"
```

**iOS**:
```bash
flutter run
# Logs appear automatically
```

### Expected Output
```
═══════════════════════════════════════════════════════════
📍 LOCATION CAPTURED
═══════════════════════════════════════════════════════════
⏰ Time: 2024-01-15T10:30:00.123456Z
📍 Latitude: 12.9716
📍 Longitude: 77.5946
🎯 Accuracy: 15.5m
═══════════════════════════════════════════════════════════

📤 Sending location to backend...
✅ Location sent successfully to backend
```

---

## 🔧 Code Files

### Core Implementation
- **lib/services/background_service.dart** - Background location service
- **lib/services/location_tracking_manager.dart** - Tracking state management
- **lib/widgets/location_permission_handler.dart** - Permission handling
- **lib/widgets/location_tracking_status.dart** - Status UI widget

### Configuration
- **pubspec.yaml** - Dependencies (geolocator, flutter_background_service, flutter_local_notifications)
- **android/app/src/main/AndroidManifest.xml** - Android permissions & service
- **lib/main.dart** - Service initialization

---

## ⚠️ Critical Requirements

### Android
- ⚠️ **Battery optimization MUST be disabled**
  - Settings → Battery → App power management → Chola Cabs → Unrestricted
- Location permission must be "Allow all the time"

### iOS
- Background Modes capability must be enabled in Xcode
- Location descriptions must be in Info.plist
- Location permission must be "Always"

---

## 📊 What Gets Sent Every 15 Minutes

```json
POST https://your-backend.com/api/v1/drivers/123/location
Authorization: Bearer <token>
Content-Type: application/json

{
  "latitude": 12.9716,
  "longitude": 77.5946,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

---

## 💾 What Gets Stored in Database

```sql
INSERT INTO locations (driver_id, latitude, longitude, timestamp)
VALUES (123, 12.9716, 77.5946, '2024-01-15T10:30:00.000Z');
```

---

## ✅ Verification Checklist

- [ ] driver_id saved after login
- [ ] Backend endpoint created
- [ ] Database table created
- [ ] Terminal shows "LOCATION CAPTURED" every 30 seconds (test)
- [ ] "Location sent successfully" message appears
- [ ] Works when app is closed
- [ ] Database has location entries

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| "No driver_id found" | Save driver_id after login |
| "Backend error: 404" | Create endpoint /api/v1/drivers/{driver_id}/location |
| "Backend error: 403" | Verify driver belongs to user |
| "No auth token found" | Save token after login |
| Service stops after 15 min | Disable battery optimization (Android) |
| No location updates | Grant location permission |

---

## 🎯 Features

✅ Captures location every 15 minutes
✅ Works when app is closed or killed
✅ Android foreground service with notification
✅ iOS background location updates
✅ Automatic restart after device reboot
✅ Secure HTTPS communication
✅ Bearer token authentication
✅ Terminal logging for debugging
✅ Play Store & App Store compliant

---

## 📝 Backend Example (Node.js)

```javascript
router.post('/api/v1/drivers/:driver_id/location', authenticateToken, async (req, res) => {
  try {
    const { driver_id } = req.params;
    const { latitude, longitude, timestamp } = req.body;
    const userId = req.user.id;

    // Verify driver belongs to user
    const driver = await Driver.findOne({ id: driver_id, user_id: userId });
    if (!driver) return res.status(403).json({ error: 'Unauthorized' });

    // Validate coordinates
    if (!latitude || !longitude || typeof latitude !== 'number' || typeof longitude !== 'number') {
      return res.status(400).json({ error: 'Invalid coordinates' });
    }

    // Save location
    const location = await Location.create({
      driver_id,
      latitude,
      longitude,
      timestamp: new Date(timestamp),
      created_at: new Date(),
    });

    // Update driver's current location
    await Driver.update(
      { id: driver_id },
      {
        current_latitude: latitude,
        current_longitude: longitude,
        last_location_update: new Date(),
      }
    );

    res.json({
      success: true,
      message: 'Location updated successfully',
      data: {
        id: location.id,
        driver_id: location.driver_id,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: location.timestamp,
      },
    });
  } catch (error) {
    console.error('Location update error:', error);
    res.status(500).json({ error: 'Failed to update location' });
  }
});
```

---

## 🚀 Next Steps

1. Save driver_id after login
2. Create backend endpoint
3. Create database table
4. Test with 30-second interval
5. Verify terminal logs
6. Change back to 15 minutes
7. Deploy to app stores

---

**Your location tracking system is ready! 🎯**
