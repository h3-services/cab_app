import 'package:flutter/material.dart';
import '../services/location_tracking_manager.dart';
import '../constants/app_colors.dart';

class LocationTrackingStatus extends StatefulWidget {
  const LocationTrackingStatus({super.key});

  @override
  State<LocationTrackingStatus> createState() => _LocationTrackingStatusState();
}

class _LocationTrackingStatusState extends State<LocationTrackingStatus> {
  late Future<bool> _trackingEnabledFuture;
  late Future<String?> _lastLocationTimeFuture;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  void _refreshStatus() {
    setState(() {
      _trackingEnabledFuture = LocationTrackingManager.isTrackingEnabled();
      _lastLocationTimeFuture = LocationTrackingManager.getLastLocationTime();
    });
  }

  Future<void> _toggleTracking(bool enabled) async {
    if (enabled) {
      await LocationTrackingManager.enableTracking();
    } else {
      await LocationTrackingManager.disableTracking();
    }
    _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _trackingEnabledFuture,
      builder: (context, trackingSnapshot) {
        if (!trackingSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final isEnabled = trackingSnapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppColors.greenPrimary.withOpacity(0.1)
                : AppColors.orangePrimary.withOpacity(0.1),
            border: Border.all(
              color: isEnabled ? AppColors.greenPrimary : AppColors.orangePrimary,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEnabled ? Icons.location_on : Icons.location_off,
                        color: isEnabled
                            ? AppColors.greenPrimary
                            : AppColors.orangePrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEnabled ? 'Tracking Active' : 'Tracking Inactive',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? AppColors.greenPrimary
                              : AppColors.orangePrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: _toggleTracking,
                    activeColor: AppColors.greenPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<String?>(
                future: _lastLocationTimeFuture,
                builder: (context, timeSnapshot) {
                  if (!timeSnapshot.hasData || timeSnapshot.data == null) {
                    return Text(
                      'No location updates yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayPrimary,
                      ),
                    );
                  }

                  final lastTime = DateTime.parse(timeSnapshot.data!);
                  final now = DateTime.now();
                  final diff = now.difference(lastTime);

                  String timeAgo;
                  if (diff.inSeconds < 60) {
                    timeAgo = '${diff.inSeconds}s ago';
                  } else if (diff.inMinutes < 60) {
                    timeAgo = '${diff.inMinutes}m ago';
                  } else if (diff.inHours < 24) {
                    timeAgo = '${diff.inHours}h ago';
                  } else {
                    timeAgo = '${diff.inDays}d ago';
                  }

                  return Text(
                    'Last update: $timeAgo',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grayPrimary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Location updates every ~15 minutes',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.grayPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
