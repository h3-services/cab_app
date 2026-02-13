import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      // Save current volume
      final VolumeController volumeController = VolumeController();
      final double currentVolume = await volumeController.getVolume();
      
      // Set volume to maximum
      await volumeController.setVolume(1.0);
      
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: [
              AVAudioSessionOptions.mixWithOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _player.setSource(AssetSource('sounds/notification_sound.mp3'));
      await _player.resume();
      
      // Restore volume after 5 seconds
      Future.delayed(const Duration(seconds: 5), () async {
        await volumeController.setVolume(currentVolume);
      });
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }
}
