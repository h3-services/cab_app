# iOS Configuration for Background Location

Since this project doesn't have an iOS folder, here's the required Info.plist configuration for iOS background location tracking:

## Add to ios/Runner/Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Location is required to track trips and ensure driver safety</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is required to track trips and find nearby passengers</string>
```

## Important iOS Notes:

- iOS background location is OS-controlled (no guaranteed 15-minute intervals)
- iOS may stop location updates if user force-kills the app
- iOS provides best-effort background location tracking
- Android is the primary platform for reliable background location tracking