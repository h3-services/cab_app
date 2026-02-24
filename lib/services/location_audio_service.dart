import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';

class LocationAudioService {
  static AudioPlayer? _audioPlayer;

  static Future<void> initialize() async {
    // No-op, kept for compatibility
  }

  static Future<void> playLocationSound() async {
    try {
      // Stop and dispose old player
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      
      // Create fresh player
      _audioPlayer = AudioPlayer();
      
      // Set system volume to maximum
      try {
        VolumeController().setVolume(1.0, showSystemUI: false);
        VolumeController().maxVolume();
      } catch (e) {
        debugPrint('[LocationAudio] Volume control error: $e');
      }
      
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.play(AssetSource('audio/notification_sound.mp3'));
      
      debugPrint('[LocationAudio] ✅ Sound played');
    } catch (e) {
      debugPrint('[LocationAudio] ❌ Play error: $e');
      try {
        await _audioPlayer?.play(AssetSource('notification_sound.mp3'));
      } catch (e2) {
        debugPrint('[LocationAudio] ❌ Fallback error: $e2');
      }
    }
  }

  static Future<void> dispose() async {
    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (e) {
      debugPrint('[LocationAudio] Dispose error: $e');
    }
  }
}
