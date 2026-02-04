import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/notification_sound.mp3'));
      print('[Audio Service] Playing full notification sound');
    } catch (e) {
      print('[Audio Service] Error: $e');
    }
  }
}
