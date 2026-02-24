import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';

class AudioService {
  static AudioPlayer? _player;
  static double? _originalVolume;

  static AudioPlayer _getPlayer() {
    _player ??= AudioPlayer();
    return _player!;
  }

  static Future<void> playNotificationSound() async {
    try {
      debugPrint('[AudioService] Starting notification sound');
      
      final player = _getPlayer();
      final VolumeController volumeController = VolumeController();
      
      try {
        _originalVolume = await volumeController.getVolume();
        volumeController.setVolume(1.0, showSystemUI: false);
      } catch (e) {
        debugPrint('[AudioService] Volume control error: $e');
      }
      
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1.0);
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      
      await player.setAudioContext(
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
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      
      await player.play(AssetSource('sounds/notification_sound.mp3'));
      debugPrint('[AudioService] ✅ Sound playing');
      
      // Restore volume after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_originalVolume != null) {
          try {
            volumeController.setVolume(_originalVolume!);
          } catch (e) {
            debugPrint('[AudioService] Volume restore error: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('[AudioService] ❌ Audio play error: $e');
      // Try fallback
      try {
        final player = _getPlayer();
        await player.play(AssetSource('notification_sound.mp3'));
        debugPrint('[AudioService] ✅ Fallback sound playing');
      } catch (e2) {
        debugPrint('[AudioService] ❌ Fallback error: $e2');
      }
    }
  }
  
  static Future<void> stopSound() async {
    try {
      await _player?.stop();
      if (_originalVolume != null) {
        final VolumeController volumeController = VolumeController();
        volumeController.setVolume(_originalVolume!);
      }
    } catch (e) {
      debugPrint('[AudioService] Audio stop error: $e');
    }
  }
}