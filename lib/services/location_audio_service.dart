import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

class LocationAudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      _isInitialized = true;
      debugPrint('[LocationAudio] ✅ Initialized');
    } catch (e) {
      debugPrint('[LocationAudio] ❌ Init error: $e');
    }
  }

  static Future<void> playLocationSound() async {
    try {
      // Set system volume to maximum
      try {
        VolumeController().setVolume(1.0, showSystemUI: false);
        VolumeController().maxVolume();
      } catch (e) {
        debugPrint('[LocationAudio] Volume control error: $e');
      }

      // Stop any currently playing sound
      await _audioPlayer.stop();
      
      // Set player to maximum volume
      await _audioPlayer.setVolume(1.0);
      
      // Play the notification sound
      await _audioPlayer.play(AssetSource('audio/notification_sound.mp3'));
      
      debugPrint('[LocationAudio] ✅ Sound played');
    } catch (e) {
      debugPrint('[LocationAudio] ❌ Play error: $e');
      // Fallback: try alternative path
      try {
        await _audioPlayer.play(AssetSource('notification_sound.mp3'));
      } catch (e2) {
        debugPrint('[LocationAudio] ❌ Fallback error: $e2');
      }
    }
  }

  static Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      _isInitialized = false;
    } catch (e) {
      debugPrint('[LocationAudio] Dispose error: $e');
    }
  }
}
