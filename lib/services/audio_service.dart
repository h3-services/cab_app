import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static double? _originalVolume;

  static Future<void> playNotificationSound() async {
    try {
      final VolumeController volumeController = VolumeController();
      _originalVolume = await volumeController.getVolume();
      
      // Force maximum volume
      volumeController.setVolume(1.0);
      volumeController.showSystemUI = false;
      
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      
      await _player.setSource(AssetSource('sounds/notification_sound.mp3'));
      await _player.resume();
      
      // Restore volume after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_originalVolume != null) {
          volumeController.setVolume(_originalVolume!);
        }
      });
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }
  
  static Future<void> stopSound() async {
    try {
      await _player.stop();
      if (_originalVolume != null) {
        final VolumeController volumeController = VolumeController();
        volumeController.setVolume(_originalVolume!);
      }
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }
}