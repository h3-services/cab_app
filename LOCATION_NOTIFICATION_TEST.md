# Location Notification Test Guide

## ✅ All Services Now Show Notifications

Every location capture triggers a notification showing:
- 📍 Timestamp
- 📌 Latitude & Longitude  
- 🎯 Accuracy

## Services with Notifications

### 1. Foreground Service (2 min)
- **File**: `location_tracking_service.dart`
- **Trigger**: When app is open
- **Interval**: Every 2 minutes
- **Notification**: ✅ Added

### 2. Background Service (2 min)
- **File**: `background_location_service.dart`
- **Trigger**: When app is minimized
- **Interval**: Every 2 minutes
- **Notification**: ✅ Already present

### 3. Alarm Manager (2 min)
- **File**: `alarm_manager_location_service.dart`
- **Trigger**: When app is closed/terminated
- **Interval**: Every 2 minutes
- **Notification**: ✅ Already present

### 4. WorkManager (15 min)
- **File**: `workmanager_location_service.dart`
- **Trigger**: When app is closed/terminated
- **Interval**: Every 15 minutes
- **Notification**: ✅ Already present

## Quick Test

### Test 1: Foreground (App Open)
```
1. Open app
2. Toggle "Ready for Trip" ON
3. Wait 2 minutes
4. See notification: "📍 Location Captured"
```

### Test 2: Background (App Minimized)
```
1. Open app, toggle ON
2. Press Home button
3. Wait 2 minutes
4. See notification: "📍 Location Captured"
```

### Test 3: Terminated (App Closed)
```
1. Open app, toggle ON
2. Swipe away app from recent apps
3. Wait 2-15 minutes
4. See notification: "📍 Location Captured"
```

### Test 4: Locked Screen
```
1. Open app, toggle ON
2. Lock screen
3. Wait 2 minutes
4. Unlock and see notifications on lock screen
```

## Notification Format

```
Title: 📍 Location Captured
Body: Time: 14:30 | Lat: 10.0817, Lng: 78.7463
```

## Troubleshooting

**No notifications?**
- Check notification permission granted
- Verify "Ready for Trip" toggle is ON
- Check Do Not Disturb is OFF
- Wait full 2 minutes (don't expect instant)

**Notifications delayed?**
- Normal for terminated state (2-15 min range)
- Battery saver may delay notifications
- Disable battery optimization for app

## Expected Behavior

- **Foreground**: Notification every 2 minutes
- **Background**: Notification every 2 minutes
- **Terminated**: Notification every 2-15 minutes (multiple systems)
- **All states**: Each notification shows current location
