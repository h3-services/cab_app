import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource('sounds/notification_sound.mp3'));
      await _player.resume();
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
