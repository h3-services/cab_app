import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionHandler extends StatefulWidget {
  final Widget child;

  const LocationPermissionHandler({
    required this.child,
    super.key,
  });

  @override
  State<LocationPermissionHandler> createState() =>
      _LocationPermissionHandlerState();
}

class _LocationPermissionHandlerState extends State<LocationPermissionHandler> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      if (mounted) {
        _showLocationServiceDialog();
      }
      return;
    }

    final permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Step 1: Request basic location permission
      final result = await Geolocator.requestPermission();
      
      if (result == LocationPermission.whileInUse) {
        // Step 2: Now request background permission
        await _requestBackgroundPermission();
      }
    } else if (permission == LocationPermission.whileInUse) {
      // Already have foreground, request background
      await _requestBackgroundPermission();
    } else if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  Future<void> _requestBackgroundPermission() async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Required'),
          content: const Text(
            'For driver safety and trip tracking, this app needs to access your location even when closed.\n\nPlease select "Allow all the time" in the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Service Disabled'),
        content: const Text(
          'Location services are disabled. Please enable them to use background tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app collects location data to enable live tracking even when the app is closed, for safety and operational purposes. Please enable location permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
