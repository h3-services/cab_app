import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PermissionDebugScreen extends StatefulWidget {
  const PermissionDebugScreen({super.key});

  @override
  State<PermissionDebugScreen> createState() => _PermissionDebugScreenState();
}

class _PermissionDebugScreenState extends State<PermissionDebugScreen> {
  String _permissionStatus = 'Checking...';
  String _serviceStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final permission = await Geolocator.checkPermission();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    setState(() {
      _permissionStatus = permission.toString();
      _serviceStatus = serviceEnabled ? 'Enabled' : 'Disabled';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permission Debug')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location Service: $_serviceStatus'),
            const SizedBox(height: 16),
            Text('Permission Status: $_permissionStatus'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final result = await Geolocator.requestPermission();
                setState(() {
                  _permissionStatus = result.toString();
                });
              },
              child: const Text('Request Permission'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('Open App Settings'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPermissions,
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }
}