# Location Tracking - All States Solution

## Overview
Location tracking now works in **ALL app states**:
- ✅ **Foreground** (app open)
- ✅ **Background** (app minimized)
- ✅ **Terminated** (app closed/killed)
- ✅ **Locked** (screen locked)

## Implementation

### 1. Multiple Tracking Mechanisms
The app uses **3 redundant systems** to ensure location is always captured:

#### A. Foreground Timer (2 minutes)
- Active when app is open
- Uses `Timer.periodic` in `LocationTrackingService`
- Captures location every 2 minutes

#### B. Background Service (2 minutes)
- Uses `flutter_background_service`
- Runs as foreground service with persistent notification
- Captures location every 2 minutes when app is minimized

#### C. WorkManager (15 minutes)
- Uses `workmanager` package
- Most reliable for terminated state
- Survives app kills and device reboots
- Runs every 15 minutes (Android limitation for periodic tasks)

#### D. Alarm Manager (2 minutes)
- Uses `android_alarm_manager_plus`
- Backup system for terminated state
- Exact alarms with wake lock
- Runs every 2 minutes

### 2. Notifications
Every location capture triggers a notification showing:
- 📍 Timestamp
- 📌 Latitude & Longitude
- 🎯 Accuracy

### 3. Battery Optimization
- Requests exemption from battery optimization
- Ensures background execution is not restricted
- Critical for terminated state tracking

## Files Modified

### New Files
- `lib/services/workmanager_location_service.dart` - WorkManager implementation

### Updated Files
- `lib/services/location_tracking_service.dart` - Added WorkManager integration
- `lib/services/background_location_service.dart` - Changed interval to 2 minutes
- `lib/services/alarm_manager_location_service.dart` - Changed interval to 2 minutes
- `lib/services/permission_service.dart` - Added battery optimization request
- `pubspec.yaml` - Added workmanager package

## Permissions Required

### AndroidManifest.xml (Already configured)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

## How It Works

### When App is Open (Foreground)
1. Timer runs every 2 minutes
2. Captures location using Geolocator
3. Sends to backend API
4. Shows notification

### When App is Minimized (Background)
1. Background service continues running
2. Foreground notification keeps service alive
3. Captures location every 2 minutes
4. Shows notification for each capture

### When App is Closed/Killed (Terminated)
1. WorkManager wakes up every 15 minutes
2. Alarm Manager wakes up every 2 minutes
3. Both capture location independently
4. Both send to backend API
5. Both show notifications

### When Screen is Locked
- All mechanisms continue working
- Wake locks ensure device wakes for location capture
- Notifications appear on lock screen

## Testing

### Test Foreground Tracking
1. Open app
2. Toggle "Ready for Trip" ON
3. Wait 2 minutes
4. Check notification

### Test Background Tracking
1. Open app, toggle ON
2. Press home button (minimize app)
3. Wait 2 minutes
4. Check notification

### Test Terminated Tracking
1. Open app, toggle ON
2. Force close app (swipe away from recent apps)
3. Wait 2-15 minutes
4. Check notifications

### Test Locked Screen
1. Open app, toggle ON
2. Lock screen
3. Wait 2 minutes
4. Unlock and check notifications

## Troubleshooting

### No location in terminated state
1. Check battery optimization is disabled
2. Verify background location permission granted
3. Check device manufacturer restrictions (Xiaomi, Oppo, etc.)
4. Enable "Autostart" permission on some devices

### Notifications not showing
1. Check notification permission granted
2. Verify notification channels created
3. Check Do Not Disturb settings

### Location not accurate
1. Ensure GPS is enabled
2. Check location mode is "High accuracy"
3. Wait for GPS fix (may take 30 seconds)

## API Endpoint
```
POST /api/drivers/{driver_id}/location
{
  "latitude": 10.0817618,
  "longitude": 78.7463452,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "accuracy": 15.5
}
```

## Intervals Summary
- **Foreground**: Every 2 minutes
- **Background**: Every 2 minutes
- **Alarm Manager**: Every 2 minutes
- **WorkManager**: Every 15 minutes (Android limitation)

## Notes
- WorkManager 15-minute interval is Android's minimum for periodic tasks
- Alarm Manager provides 2-minute backup for terminated state
- Multiple systems ensure redundancy if one fails
- Battery optimization exemption is critical for reliability
