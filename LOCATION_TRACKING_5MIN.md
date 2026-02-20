# Location Tracking - 5 Minute Interval Update

## Summary
Updated all location tracking services to capture and send location every **5 minutes** consistently across all app states (foreground, background, and terminated).

## Changes Made

### 1. Background Location Service
**File**: `lib/services/background_location_service.dart`
- Changed timer interval from 2 minutes to **5 minutes**
- Updated log message to reflect 5-minute intervals

### 2. Alarm Manager Location Service  
**File**: `lib/services/alarm_manager_location_service.dart`
- Changed periodic alarm from 2 minutes to **5 minutes**
- Updated initialization log message

### 3. Foreground Location Service
**File**: `lib/services/location_tracking_service.dart`
- Already configured for 5-minute intervals (no change needed)

## How It Works Now

### All App States - 5 Minute Intervals:

1. **Foreground (App Open)**
   - `LocationTrackingService` captures location every 5 minutes
   - Sends to backend API
   - Shows notification

2. **Background (App Minimized)**
   - `BackgroundLocationService` runs as foreground service
   - Captures location every 5 minutes
   - Updates persistent notification with latest location
   - Sends to backend API

3. **Terminated (App Closed)**
   - `AlarmManagerLocationService` wakes device every 5 minutes
   - Captures location even when app is completely closed
   - Sends to backend API
   - Shows notification
   - Works even after device reboot (rescheduleOnReboot: true)

## Technical Details

### Location Capture Flow:
```
Every 5 minutes:
├── Check location permissions
├── Get current GPS position (high accuracy)
├── Fallback to last known position if GPS fails
├── Send to backend API: POST /drivers/{driverId}/location
├── Store in SharedPreferences
└── Show notification to user
```

### Backend API Payload:
```json
{
  "latitude": 10.0817618,
  "longitude": 78.7463452,
  "timestamp": "2024-01-15T10:30:00.000Z",
  "accuracy": 15.5
}
```

### Permissions Required:
- ✅ Location permission (ACCESS_FINE_LOCATION)
- ✅ Background location permission (ACCESS_BACKGROUND_LOCATION)
- ✅ Foreground service permission
- ✅ Wake lock permission (for terminated state)
- ✅ Boot completed permission (for auto-restart)

## Benefits

✅ **Consistent Tracking**: Same 5-minute interval across all states  
✅ **Battery Efficient**: 5 minutes is optimal for battery vs accuracy  
✅ **Reliable**: Multiple fallback mechanisms ensure location is always captured  
✅ **Persistent**: Survives app closure and device reboot  
✅ **Transparent**: User sees notifications when location is captured  

## Testing Recommendations

1. **Foreground Test**:
   - Open app and wait 5 minutes
   - Verify notification appears with location
   - Check backend receives location update

2. **Background Test**:
   - Minimize app
   - Wait 5 minutes
   - Check persistent notification updates
   - Verify backend receives location

3. **Terminated Test**:
   - Force close app completely
   - Wait 5 minutes
   - Check notification appears
   - Verify backend receives location

4. **Reboot Test**:
   - Restart device
   - Wait 5 minutes after boot
   - Verify location tracking resumes automatically

## Notes

- All three services work independently and in parallel
- If one service fails, others continue working
- Location is always sent to backend when captured
- SharedPreferences stores last known location for offline scenarios
- High accuracy GPS is used with 30-second timeout
- Falls back to last known position if GPS fails
