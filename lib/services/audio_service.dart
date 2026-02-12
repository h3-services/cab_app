import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setSource(AssetSource('sounds/notification_sound.mp3'));
      await _player.resume();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  static Future<void> stopSound() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
