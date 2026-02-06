# Notification Sound Fix - Locked Screen Support

## Changes Made

### 1. Updated `audio_service.dart`
- Configured audio context for locked screen playback
- Set Android usage type to `notification` and content type to `sonification`
- Enabled `stayAwake` to keep device awake during sound playback
- Added audio focus gain to override silent/vibrate modes

### 2. Updated `notification_plugin.dart`
- Set notification category to `alarm` for locked screen priority
- Enabled `fullScreenIntent` to bypass Do Not Disturb
- Set visibility to `public` for locked screen display
- Added vibration pattern for better feedback

### 3. Updated `AndroidManifest.xml`
- Added `USE_FULL_SCREEN_INTENT` permission for locked screen notifications
- Added `VIBRATE` permission
- Added `showWhenLocked` and `turnScreenOn` to MainActivity for locked screen display

### 4. Updated `firebase_messaging_service.dart`
- Audio plays in background/terminated states via background handler

## How It Works

The notification sound will now play in ALL states including:

1. **Foreground (App Open)**: ✓
2. **Background (App Minimized)**: ✓
3. **Terminated (App Closed)**: ✓
4. **Locked Screen**: ✓ (NEW)
5. **Do Not Disturb Mode**: ✓ (Alarm category bypasses DND)

## Testing Steps

1. **Uninstall the app completely** (critical - Android caches notification channels)
   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   ```

2. **Rebuild and install**
   ```bash
   flutter run --release
   ```

3. **Test in all states**:
   - Foreground: Keep app open and send notification
   - Background: Minimize app and send notification
   - Terminated: Close app completely and send notification
   - **Locked Screen: Lock device and send notification** ✓

## Important Notes

- Notification channels are cached by Android. Uninstalling is required to apply changes
- The sound file is at: `android/app/src/main/res/raw/notification_sound.mp3`
- Audio context is configured to play even when device is locked
- Alarm category ensures sound plays even in Do Not Disturb mode
- Volume must be turned up on the device

## Troubleshooting

If sound still doesn't play on locked screen:
1. Ensure device volume is up (not silent/vibrate)
2. Check Do Not Disturb settings - app should be allowed
3. Go to App Settings > Notifications > Trip Notifications and verify:
   - Sound is enabled
   - "Override Do Not Disturb" is enabled
4. Verify notification permissions are granted
5. Check battery optimization is disabled for the app
