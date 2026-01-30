import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import '../widgets/bottom_navigation.dart';

class LocationDebugScreen extends StatefulWidget {
  const LocationDebugScreen({super.key});

  @override
  State<LocationDebugScreen> createState() => _LocationDebugScreenState();
}

class _LocationDebugScreenState extends State<LocationDebugScreen> {
  Map<String, dynamic>? _lastLocation;
  String? _lastUpdatedTime;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLocationData();
    // Auto-refresh every 5 seconds for convenience
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadLocationData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocationData() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString('last_location');

    if (locationStr != null && mounted) {
      try {
        final data = jsonDecode(locationStr);
        setState(() {
          _lastLocation = data;
          // Parse timestamp if available, or just show raw string
          if (data['timestamp'] != null) {
            final parsedTime = DateTime.parse(data['timestamp']).toLocal();
            _lastUpdatedTime =
                "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}:${parsedTime.second.toString().padLeft(2, '0')}";
          }
        });
      } catch (e) {
        debugPrint("Error parsing location data: $e");
      }
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
                    title: "Raw Data",
                    content: _lastLocation.toString(),
                    icon: Icons.data_object,
                    color: Colors.grey,
                    isSmall: true,
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
