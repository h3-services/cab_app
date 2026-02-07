import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class BatteryOptimizationService {
  static Future<bool> isIgnoringBatteryOptimizations() async {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<void> requestIgnoreBatteryOptimizations(BuildContext context) async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    
    if (!status.isGranted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'To ensure continuous location tracking in background, '
            'please disable battery optimization for this app.\n\n'
            'This is required for trip assignments and tracking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  static Future<void> ensureBatteryOptimizationDisabled(BuildContext context) async {
    final isIgnoring = await isIgnoringBatteryOptimizations();
    if (!isIgnoring) {
      await requestIgnoreBatteryOptimizations(context);
    }
  }
}
