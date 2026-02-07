# Background Location Tracking Fix Guide

## Issues Fixed

Your background location tracking was failing in these states:
1. **App in Background** - When user switches to another app
2. **App Terminated** - When user closes/kills the app
3. **Screen Locked** - When device screen is off/locked

## Root Causes Identified

1. **Missing WorkManager** - Android 12+ requires WorkManager for reliable background tasks
2. **No WakeLock** - Device was sleeping and killing timers
3. **Timer-based approach unreliable** - Timers don't survive app termination
4. **No battery optimization handling** - Android was killing the service to save battery
5. **Missing permissions** - Needed additional background execution permissions

## Solutions Implemented

### 1. Added WorkManager Service
- **File**: `lib/services/workmanager_location_service.dart`
- **Purpose**: Ensures location updates even when app is completely terminated
- **Frequency**: Every 15 minutes (Android's minimum for periodic tasks)
- **Survives**: App termination, device reboot, screen lock

### 2. Implemented WakeLock
- **Package**: `wakelock_plus: ^1.2.8`
- **Purpose**: Prevents device from sleeping during location updates
- **Usage**: Enabled during foreground service, disabled when service stops

### 3. Battery Optimization Handler
- **File**: `lib/services/battery_optimization_service.dart`
- **Purpose**: Requests user to disable battery optimization for the app
- **Result**: Prevents Android from killing background services

### 4. Updated Permissions
Added to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.REQUEST_COMPANION_RUN_IN_BACKGROUND" />
<uses-permission android:name="android.permission.REQUEST_COMPANION_USE_DATA_IN_BACKGROUND" />
```

### 5. Enhanced Background Service
- **File**: `lib/services/background_location_service.dart`
- **Changes**:
  - Added WakeLock integration
  - Integrated WorkManager for terminated state
  - Re-enables wakelock on each timer tick
  - Better error handling

## How It Works Now

### When App is Running (Foreground)
- **Frequency**: Every 2 minutes
- **Service**: `LocationTrackingService`
- **Method**: Direct GPS polling with high accuracy

### When App is in Background
- **Frequency**: Every 15 minutes
- **Service**: `BackgroundLocationService` (Foreground Service)
- **Method**: Timer-based with WakeLock
- **Notification**: Persistent notification showing location updates

### When App is Terminated/Killed
- **Frequency**: Every 15 minutes
- **Service**: `WorkManager`
- **Method**: Android WorkManager periodic task
- **Survives**: App termination, device reboot

### When Screen is Locked
- **All services continue working**
- **WakeLock**: Keeps CPU awake during location updates
- **Foreground Service**: Prevents Android from killing the process

## Installation Steps

1. **Update dependencies**:
   ```bash
   flutter pub get
   ```

2. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Grant permissions** (on first run):
   - Location permission: "Allow all the time"
   - Battery optimization: "Don't optimize"
   - Notification permission: "Allow"

## Testing the Fix

### Test 1: Background State
1. Open the app and go online
2. Press home button (don't close app)
3. Wait 15 minutes
4. Check backend logs for location updates
5. ✅ Should receive updates every 15 minutes

### Test 2: Terminated State
1. Open the app and go online
2. Force close the app (swipe away from recent apps)
3. Wait 15 minutes
4. Check backend logs for location updates
5. ✅ Should receive updates every 15 minutes via WorkManager

### Test 3: Locked Screen
1. Open the app and go online
2. Lock the device screen
3. Wait 15 minutes
4. Unlock and check logs
5. ✅ Should receive updates every 15 minutes

### Test 4: Device Reboot
1. Open the app and go online
2. Reboot the device
3. Don't open the app after reboot
4. Wait 15 minutes
5. ✅ Should auto-start and send location updates

## Monitoring Location Updates

### Check Logs
```dart
// In your backend, you should see:
{
  "latitude": 10.0817618,
  "longitude": 78.7463452,
  "timestamp": "2024-01-15T10:30:00Z",
  "accuracy": 15.5,
  "source": "workmanager" // or "background_service" or "foreground"
}
```

### Check SharedPreferences
The app stores:
- `last_location_update`: Last successful backend sync
- `last_workmanager_update`: Last WorkManager execution
- `location_update_count`: Total updates sent

## Important Notes

### Battery Optimization
- **Critical**: User MUST disable battery optimization
- **Why**: Android will kill background services otherwise
- **How**: App will prompt automatically on first run

### Location Permission
- **Required**: "Allow all the time"
- **Why**: Needed for background location access
- **How**: App will request during onboarding

### Notification
- **Persistent**: Shows "Chola Cabs Driver - Online"
- **Cannot be dismissed**: Required for foreground service
- **Updates**: Shows last location update time

### Frequency Limitations
- **Foreground**: Can be any frequency (currently 2 min)
- **Background**: 15 minutes minimum (Android restriction)
- **WorkManager**: 15 minutes minimum (Android restriction)

## Troubleshooting

### Location not updating in background
1. Check battery optimization is disabled
2. Verify "Allow all the time" location permission
3. Check if foreground notification is visible
4. Review device manufacturer restrictions (Xiaomi, Oppo, etc.)

### WorkManager not running after termination
1. Ensure app was opened at least once
2. Check battery optimization is disabled
3. Verify device allows background execution
4. Some manufacturers require additional settings

### High battery drain
1. This is expected for continuous location tracking
2. Foreground service prevents app from being killed
3. User should keep device charged during trips
4. Consider increasing update frequency to 20-30 minutes if needed

## Device-Specific Settings

### Xiaomi/MIUI
1. Settings → Apps → Chola Cabs
2. Battery saver → No restrictions
3. Autostart → Enable
4. Battery optimization → Don't optimize

### Oppo/ColorOS
1. Settings → Battery → App Battery Management
2. Find Chola Cabs → Disable optimization
3. Settings → Privacy → App Permissions → Autostart
4. Enable for Chola Cabs

### Samsung/One UI
1. Settings → Apps → Chola Cabs
2. Battery → Optimize battery usage → All apps
3. Find Chola Cabs → Disable
4. Settings → Device care → Battery → Background usage limits
5. Add Chola Cabs to "Never sleeping apps"

### Huawei/EMUI
1. Settings → Battery → App launch
2. Find Chola Cabs → Manage manually
3. Enable: Auto-launch, Secondary launch, Run in background

## Performance Impact

- **Battery**: Moderate to high (expected for GPS tracking)
- **Data**: ~1-2 KB per location update
- **CPU**: Minimal (only during location capture)
- **Memory**: ~50-100 MB for foreground service

## Future Improvements

1. **Adaptive frequency**: Reduce frequency when driver is offline
2. **Geofencing**: Only track when near pickup/drop locations
3. **Motion detection**: Only update when device is moving
4. **Battery-aware**: Reduce frequency on low battery

## Support

If location tracking still fails after implementing these fixes:
1. Check device logs: `flutter logs`
2. Verify backend is receiving requests
3. Test on different Android versions
4. Check manufacturer-specific restrictions
5. Consider using a different device for testing

## Summary

The fix implements a **three-tier approach**:
1. **Foreground Service** (app running) - Every 2 minutes
2. **Background Service** (app backgrounded) - Every 15 minutes with WakeLock
3. **WorkManager** (app terminated) - Every 15 minutes, survives reboot

This ensures **continuous location tracking** in all app states, even when the device is locked or the app is completely closed.
