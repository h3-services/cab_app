import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNotificationSound() async {
    try {
      await _player.play(AssetSource('sounds/notification_sound.mpeg'));
      print('[Audio Service] Playing notification sound');
    } catch (e) {
      print('[Audio Service] Error playing sound: $e');
    }
  }
}
