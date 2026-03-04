package com.example.cap_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.cap_app/audio"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playAlarmSound") {
                playAlarmSound()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        
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

    private fun playAlarmSound() {
        try {
            mediaPlayer?.release()
            mediaPlayer = null
            
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
            
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                setDataSource(applicationContext, Uri.parse("android.resource://" + packageName + "/" + R.raw.chola_cabs))
                setVolume(1.0f, 1.0f)
                prepare()
                setOnCompletionListener {
                    it.release()
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
                }
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }
}
