import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AudioService {
  static AudioPlayer? _player;
  static double? _originalVolume;

  static Future<void> playNotificationSound() async {
    try {
      debugPrint('[AudioService] Starting notification sound');
      
      // Dispose any existing player
      await _player?.dispose();
      _player = null;
      
      // Create completely fresh player
      _player = AudioPlayer();
      final player = _player!;
      
      final VolumeController volumeController = VolumeController();
      
      try {
        _originalVolume = await volumeController.getVolume();
        // Force maximum volume immediately
        await volumeController.setVolume(1.0);
        debugPrint('[AudioService] Volume forced to 100% (was: $_originalVolume)');
      } catch (e) {
        debugPrint('[AudioService] Volume control error: $e');
      }
      
      // Copy asset to temp file to bypass cache
      final ByteData data = await rootBundle.load('assets/sounds/chola_cabs.mp3');
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/chola_notification_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      
      debugPrint('[AudioService] Temp audio file created: $tempPath');
      
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      
      // Set audio context BEFORE setting volume for better control
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
      
      // Boost system volume to 100%
      try {
        await volumeController.setVolume(1.0);
        debugPrint('[AudioService] System volume boosted to 100%');
      } catch (e) {
        debugPrint('[AudioService] Volume boost error: $e');
      }
      
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
      
      // Play from temp file (bypasses all caching)
      await player.play(DeviceFileSource(tempPath));
      debugPrint('[AudioService] ✅ NEW AUDIO PLAYING at MAXIMUM VOLUME from temp file');
      
      // Restore volume and cleanup after 10 seconds
      Future.delayed(const Duration(seconds: 10), () async {
        if (_originalVolume != null) {
          try {
            volumeController.setVolume(_originalVolume!);
          } catch (e) {
            debugPrint('[AudioService] Volume restore error: $e');
          }
        }
        // Delete temp file
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            debugPrint('[AudioService] Temp file deleted');
          }
        } catch (e) {
          debugPrint('[AudioService] Temp file delete error: $e');
        }
      });
    } catch (e) {
      debugPrint('[AudioService] ❌ Audio play error: $e');
    }
  }
  
  static Future<void> stopSound() async {
    try {
      await _player?.stop();
      await _player?.dispose();
      _player = null;
      if (_originalVolume != null) {
        final VolumeController volumeController = VolumeController();
        volumeController.setVolume(_originalVolume!);
      }
    } catch (e) {
      debugPrint('[AudioService] Audio stop error: $e');
    }
  }
}