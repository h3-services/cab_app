package com.example.cap_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            
            val locationChannel = NotificationChannel(
                "location_updates",
                "Location Updates",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when location is captured"
                enableVibration(true)
                setShowBadge(true)
            }
            
            val trackingChannel = NotificationChannel(
                "location_tracking",
                "Location Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background location tracking service"
            }
            
            notificationManager.createNotificationChannel(locationChannel)
            notificationManager.createNotificationChannel(trackingChannel)
        }
    }
}
