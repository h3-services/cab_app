# Location Tracking - All States Solution

## Overview
Comprehensive location tracking that works in **ALL** states:
- ✅ Foreground (app open)
- ✅ Background (app minimized)
- ✅ Locked Screen
- ✅ Terminated (app killed)
- ✅ After Device Reboot

## Implementation

### 1. Flutter Background Service
**Purpose**: Handles foreground, background, and locked screen states
**Interval**: 15 minutes
**Features**:
- Runs as foreground service with persistent notification
- High priority prevents Android from killing it
- Auto-starts on boot
- Updates location every 15 minutes

### 2. Android Alarm Manager Plus
**Purpose**: Handles terminated state and ensures execution
**Interval**: 15 minutes
**Features**:
- Exact alarms that wake up the device
- Survives app termination
- Reschedules on device reboot
- Independent of app lifecycle

## How It Works

### State: Foreground/Background/Locked
- Flutter Background Service runs continuously
- Timer triggers every 15 minutes
- Sends location to backend
- Shows notification with coordinates

### State: Terminated
- Android Alarm Manager triggers callback
- Wakes up device if needed
- Gets current location
- Sends to backend
- Goes back to sleep

### State: After Reboot
- Both services auto-restart
- Alarm Manager reschedules alarms
- Background Service starts automatically
- Location tracking resumes

## Permissions Required

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

## Battery Optimization
- App requests battery optimization exemption
- Critical for reliable background execution
- User must approve in settings

## Testing

### Test Foreground/Background
1. Open app and enable location tracking
2. Minimize app
3. Check logs every 15 minutes
4. Verify location updates in backend

### Test Locked Screen
1. Enable location tracking
2. Lock device
3. Wait 15 minutes
4. Unlock and check logs
5. Verify location was sent

### Test Terminated State
1. Enable location tracking
2. Force stop app from settings
3. Wait 15 minutes
4. Check backend for location updates
5. Alarm Manager should have sent location

### Test After Reboot
1. Enable location tracking
2. Reboot device
3. Wait 15 minutes after boot
4. Check backend for location updates
5. Both services should auto-restart

## Device-Specific Settings

### Xiaomi/MIUI
- Settings → Apps → Manage apps → [App] → Battery saver → No restrictions
- Settings → Apps → Manage apps → [App] → Autostart → Enable
- Settings → Battery & performance → App battery saver → [App] → No restrictions

### Huawei/EMUI
- Settings → Apps → [App] → Battery → App launch → Manage manually
- Enable all three options (Auto-launch, Secondary launch, Run in background)

### Samsung/One UI
- Settings → Apps → [App] → Battery → Optimize battery usage → All → [App] → Don't optimize
- Settings → Device care → Battery → Background usage limits → Never sleeping apps → Add [App]

### OnePlus/OxygenOS
- Settings → Apps → [App] → Battery → Battery optimization → Don't optimize
- Settings → Apps → [App] → Advanced → Battery optimization → Don't optimize

## Troubleshooting

### Location not updating in terminated state
1. Check battery optimization is disabled
2. Verify SCHEDULE_EXACT_ALARM permission granted
3. Check device manufacturer restrictions
4. Review alarm manager logs

### Service stops after some time
1. Disable battery optimization
2. Add app to "Never sleeping apps" list
3. Enable autostart permission
4. Check foreground service notification is visible

### No location after reboot
1. Verify RECEIVE_BOOT_COMPLETED permission
2. Check autostart is enabled
3. Review boot receiver logs
4. Ensure services are registered in manifest

## Files Modified
- `pubspec.yaml` - Added android_alarm_manager_plus
- `lib/services/alarm_manager_location_service.dart` - New service for terminated state
- `lib/services/background_location_service.dart` - Enhanced with alarm manager
- `android/app/src/main/AndroidManifest.xml` - Added alarm manager configuration

## Success Criteria
✅ Location updates every 15 minutes in all states
✅ Survives app termination
✅ Survives device reboot
✅ Works with screen locked
✅ Battery optimization handled
✅ Device manufacturer restrictions documented
