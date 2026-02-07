# Location Tracking - Every 15 Minutes with Notifications

## Features
✅ Location captured every 15 minutes WITHOUT FAIL
✅ Notification shown every time location is captured
✅ Works in ALL states: Foreground, Background, Locked, Terminated, After Reboot

## How It Works

### Every 15 Minutes:
1. **Alarm Manager wakes up** (even if app is killed)
2. **Gets current location** (GPS coordinates)
3. **Sends to backend API** (driver location endpoint)
4. **Shows notification** with time and coordinates
5. **Goes back to sleep** until next 15-minute interval

### Dual Service Architecture:
- **Flutter Background Service**: Runs when app is active/background
- **Android Alarm Manager**: Runs when app is terminated

### Notification Details:
- **Title**: 📍 Location Captured
- **Content**: Time: HH:MM | Lat: XX.XXXX, Lng: YY.YYYY
- **Channel**: Location Updates (High Priority)
- **Sound**: Default notification sound
- **Visibility**: Always visible

## Testing

### Test Every 15 Minutes:
1. Enable location tracking
2. Note current time
3. Wait 15 minutes
4. Check notification appears
5. Verify location in backend
6. Repeat to confirm consistency

### Test in Terminated State:
1. Enable location tracking
2. Force stop app
3. Wait 15 minutes
4. Notification should still appear
5. Check backend for location update

### Test After Reboot:
1. Enable location tracking
2. Reboot device
3. Wait 15 minutes after boot
4. Notification should appear
5. Verify location in backend

## Notification Channels

### Location Updates Channel:
- **ID**: location_updates
- **Name**: Location Updates
- **Importance**: High
- **Priority**: High
- **Description**: Notifications when location is captured every 15 minutes

## Guaranteed Execution

### Why It Won't Fail:
1. **Exact Alarms**: Uses SCHEDULE_EXACT_ALARM permission
2. **Wake Lock**: Wakes device from sleep
3. **Boot Receiver**: Restarts after reboot
4. **Battery Exemption**: Prevents Android from killing service
5. **Dual Services**: Backup if one fails

### Failure Prevention:
- If GPS fails → Uses last known location
- If API fails → Logs error, continues next cycle
- If notification fails → Logs error, location still sent
- If one service fails → Other service continues

## Logs to Monitor

```
[Alarm] 📍 Location callback triggered at 2024-01-15 10:15:00
[Alarm] ✅ Location sent: 12.9716, 77.5946
[Alarm] 🔔 Notification shown
```

## Success Indicators:
✅ Notification appears every 15 minutes
✅ Notification shows current time
✅ Notification shows GPS coordinates
✅ Backend receives location update
✅ Works even when app is killed
✅ Works after device reboot
