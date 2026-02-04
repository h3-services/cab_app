import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import '../widgets/bottom_navigation.dart';
import '../services/background_location_service.dart';
import 'package:geolocator/geolocator.dart';

class LocationDebugScreen extends StatefulWidget {
  const LocationDebugScreen({super.key});

  @override
  State<LocationDebugScreen> createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _lastLocation;
  String? _lastUpdatedTime;
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStream;
  bool _isListeningToLocation = false;
  String _currentAppState = 'foreground';
  int _updateCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocationData();
    _startLocationTracking();
    // Faster refresh for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _loadLocationData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    String newAppState;
    switch (state) {
      case AppLifecycleState.resumed:
        newAppState = 'foreground';
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        newAppState = 'background';
        break;
      case AppLifecycleState.detached:
        newAppState = 'terminated';
        break;
      default:
        newAppState = 'unknown';
    }
    
    if (mounted && newAppState != _currentAppState) {
      setState(() {
        _currentAppState = newAppState;
      });
      debugPrint('App state changed to: $newAppState');
    }
  }

  Future<void> _loadLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString('last_location');

    if (locationStr != null && mounted) {
      try {
        final data = jsonDecode(locationStr);
        setState(() {
          _lastLocation = data;
          _updateCount++;
          // Parse timestamp if available, or just show raw string
          if (data['timestamp'] != null) {
            final parsedTime = DateTime.parse(data['timestamp']).toLocal();
            _lastUpdatedTime =
                "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}:${parsedTime.second.toString().padLeft(2, '0')}";
          }
          // Update app state from stored data
          _currentAppState = data['app_state'] ?? 'unknown';
        });
      } catch (e) {
        debugPrint("Error parsing location data: $e");
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        return;
      }

      // Start listening to position changes for foreground updates
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _updateLocationData(position, 'foreground');
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );

      setState(() {
        _isListeningToLocation = true;
      });
      
      debugPrint('✅ Location tracking started for foreground updates');
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
    }
  }

  Future<void> _updateLocationData(Position position, String appState) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy': position.accuracy,
        'app_state': appState,
      };
      
      await prefs.setString('last_location', jsonEncode(locationData));
      
      if (mounted) {
        setState(() {
          _lastLocation = locationData;
          _currentAppState = appState;
          _updateCount++;
          final now = DateTime.now();
          _lastUpdatedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        });
      }
      
      debugPrint('📍 Location updated in $appState state: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Error updating location data: $e');
    }
  }

  Future<void> _openInMaps() async {
    if (_lastLocation != null) {
      final lat = _lastLocation!['latitude'];
      final lng = _lastLocation!['longitude'];
      final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps')),
          );
        }
      }
    }
  }

  String _getAppStateDisplay() {
    final storedAppState = _lastLocation?['app_state']?.toString();
    final displayState = storedAppState ?? _currentAppState;
    
    switch (displayState) {
      case 'foreground':
        return 'Foreground (App Active)';
      case 'background':
        return 'Background (App Minimized)';
      case 'terminated':
        return 'Terminated (App Closed)';
      default:
        return 'Unknown State';
    }
  }

  IconData _getAppStateIcon() {
    final storedAppState = _lastLocation?['app_state']?.toString();
    final displayState = storedAppState ?? _currentAppState;
    
    switch (displayState) {
      case 'foreground':
        return Icons.smartphone;
      case 'background':
        return Icons.minimize;
      case 'terminated':
        return Icons.power_off;
      default:
        return Icons.help_outline;
    }
  }

  Color _getAppStateColor() {
    final storedAppState = _lastLocation?['app_state']?.toString();
    final displayState = storedAppState ?? _currentAppState;
    
    switch (displayState) {
      case 'foreground':
        return Colors.green;
      case 'background':
        return Colors.orange;
      case 'terminated':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Debugger'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocationData,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoCard(
                    title: "Real-time Status",
                    content: _isListeningToLocation 
                        ? "Active (Updates: $_updateCount)"
                        : "Inactive",
                    icon: _isListeningToLocation ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: _isListeningToLocation ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: "Last Known Status",
                    content: _lastUpdatedTime != null
                        ? "Updated at $_lastUpdatedTime"
                        : "No updates yet",
                    icon: Icons.access_time,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: "Latitude",
                    content:
                        _lastLocation?['latitude']?.toString() ?? "Waiting...",
                    icon: Icons.north,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: "Longitude",
                    content:
                        _lastLocation?['longitude']?.toString() ?? "Waiting...",
                    icon: Icons.east,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: "App State",
                    content: _getAppStateDisplay(),
                    icon: _getAppStateIcon(),
                    color: _getAppStateColor(),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: "Accuracy",
                    content: _lastLocation?['accuracy'] != null 
                        ? "${_lastLocation!['accuracy'].toStringAsFixed(1)}m"
                        : "Unknown",
                    icon: Icons.gps_fixed,
                    color: Colors.green,
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _lastLocation != null ? _openInMaps : null,
                    icon: const Icon(Icons.map),
                    label: const Text("View on Google Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomNavigation(currentRoute: '/location-debug'),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    bool isSmall = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: isSmall
                      ? const TextStyle(fontSize: 12, fontFamily: 'Courier')
                      : const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
