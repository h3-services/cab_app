# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }
-keepclassmembers class com.google.firebase.messaging.FirebaseMessagingService {
    *;
}
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep @com.google.firebase.messaging.FirebaseMessagingService class * { *; }

# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Play Core
-dontwarn com.google.android.play.core.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Background Service
-keep class id.flutter.flutter_background_service.** { *; }
-dontwarn id.flutter.flutter_background_service.**
-keep class * extends android.app.Service
-keepclassmembers class * extends android.app.Service {
    public <init>(...);
}

# Notifications
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class * extends androidx.core.app.NotificationCompat$Style { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
