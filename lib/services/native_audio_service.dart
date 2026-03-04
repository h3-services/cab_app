import 'package:flutter/services.dart';

class NativeAudioService {
  static const platform = MethodChannel('com.example.cap_app/audio');

  static Future<void> playAlarmSound() async {
    try {
      await platform.invokeMethod('playAlarmSound');
    } catch (e) {
      // Silent fail
    }
  }
}
