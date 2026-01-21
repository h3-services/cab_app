import 'package:flutter/material.dart';
import 'trip_start_screen.dart';
import 'dart:math' as math;
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/app_drawer.dart';
import '../widgets/bottom_navigation.dart';
import '../services/trip_state_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TripStateService _tripStateService = TripStateService();
  int selectedTab = 0; // 0: Available, 1: Pending, 2: Approved, 3: History
  String? _driverId;
  bool _isCheckingStatus = true; // Block UI until verified
  List<dynamic> _availableTrips = [];
  List<dynamic> _driverRequests = [];
  bool _isLoadingTrips = false;

  @override
  void initState() {
    super.initState();
    _loadDriverId();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getString('driverId');
    });

    // Check approval status again to prevent unauthorized access
    if (_driverId != null) {
      _checkApprovalStatus(_driverId!);
    } else {
      // If no driverId locally, we technically shouldn't be here (Splash handles it).
      // But if we are, maybe just stop loading to let them see empty state (or login redirect).
      // For safety, let's stop loading so we don't hang forever.
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _checkApprovalStatus(String driverId) async {
    try {
      final driverData = await ApiService.getDriverDetails(driverId);
      final bool isApproved = driverData['is_approved'] == true;
      final String kycVerified =
          (driverData['kyc_verified'] ?? '').toString().toLowerCase();
      final bool isAvailable = driverData['is_available'] == true;

      if (!isApproved ||
          (kycVerified != 'verified' && kycVerified != 'approved')) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/approval-pending');
        }
      } else {
        // Approved! Unlock UI
        if (mounted) {
          _tripStateService.setReadyForTrip(isAvailable);
          setState(() => _isCheckingStatus = false);
          _fetchAvailableTrips();
        }
      }
    } catch (e) {
      // If verification fails (e.g. offline), what to do?
      // Strict Mode: Redirect to Pending.
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/approval-pending');
      }
    }
  }

  Future<void> _fetchAvailableTrips() async {
    if (!mounted) return;
    setState(() => _isLoadingTrips = true);

    try {
      // 1. Fetch data in parallel
      final tripsFuture = ApiService.getAvailableTrips();
      final requestsFuture = _driverId != null
          ? ApiService.getDriverRequests(_driverId!)
          : Future.value([]);

      final results = await Future.wait([tripsFuture, requestsFuture]);
      final trips = results[0];
      final requests = results[1];

      // 2. Filter available trips (Exclude ones already requested)
      final requestedTripIds = requests
          .where((r) =>
              (r['status'] ?? '').toString().toUpperCase() != 'CANCELLED')
          .map((r) => r['trip_id'].toString())
          .toSet();
      final filteredTrips = trips
          .where((t) => !requestedTripIds.contains(t['trip_id'].toString()))
          .where((t) {
        final status = (t['trip_status'] ?? t['status'] ?? '').toString();
        return status.trim().toUpperCase() == 'OPEN';
      }).toList();

      if (mounted) {
        setState(() {
          _availableTrips = filteredTrips;
          _driverRequests = requests;
          _isLoadingTrips = false;
        });
        // Debug: Log driver requests structure
        if (requests.isNotEmpty) {
          debugPrint('Driver Requests Keys: ${requests.first.keys}');
          debugPrint('First Request: ${requests.first}');
        }
      }
    } catch (e) {
      debugPrint("Error fetching trips: $e");
      if (mounted) {
        setState(() => _isLoadingTrips = false);
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
    setState(() {
      final index = _driverRequests
          .indexWhere((r) => r['request_id'].toString() == requestId);
      if (index != -1) {
        _driverRequests[index]['status'] = 'CANCELLED';
      }
    });

    try {
      await ApiService.updateRequestStatus(requestId, "CANCELLED");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Request Cancelled")));
      _fetchAvailableTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to cancel: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _requestTrip(String tripId) async {
    if (_driverId == null) return;

    try {
      await ApiService.createTripRequest(tripId, _driverId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Request Sent Successfully!"),
            backgroundColor: Colors.green),
      );

      _fetchAvailableTrips();
    } catch (e) {
      if (e.toString().contains("Request already exists")) {
        final existingRequest = _driverRequests.firstWhere(
          (r) => r['trip_id'].toString() == tripId,
          orElse: () => null,
        );

        if (existingRequest != null) {
          try {
            await ApiService.updateRequestStatus(
                existingRequest['request_id'].toString(), "PENDING");

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Request Resubmitted Successfully!"),
                  backgroundColor: Colors.green),
            );
            _fetchAvailableTrips();
            return;
          } catch (updateError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text("Failed to resubmit: $updateError"),
                  backgroundColor: Colors.red),
            );
            return;
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to send request: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Verifying Account Status..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: const AppDrawer(),
      body: Column(
        children: [
          // Ready for Trip Toggle Section
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ready For Trip',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _tripStateService.isReadyForTrip
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tripStateService.isReadyForTrip
                              ? 'Active'
                              : 'Inactive',
                          style: TextStyle(
                            fontSize: 15,
                            color: _tripStateService.isReadyForTrip
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: _tripStateService.isReadyForTrip,
                    onChanged: (value) async {
                      if (_driverId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Driver ID not found. Please re-login.')),
                        );
                        return;
                      }

                      // Optimistic update
                      setState(() {
                        _tripStateService.setReadyForTrip(value);
                      });

                      try {
                        await ApiService.updateDriverAvailability(
                            _driverId!, value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value
                                ? 'You are now Online'
                                : 'You are now Offline'),
                            backgroundColor: value ? Colors.green : Colors.grey,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } catch (e) {
                        // Revert on failure
                        setState(() {
                          _tripStateService.setReadyForTrip(!value);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to update status: $e')),
                        );
                      }
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: Colors.grey.shade600,
                    inactiveTrackColor: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          // Tab Buttons Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFC0C0C0),
            child: Row(
              children: [
                _buildTabButton('Available (${_availableTrips.length})', 0,
                    const Color(0xFF757575)),
                const SizedBox(width: 8),
                _buildTabButton(
                    'Pending (${_driverRequests.where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING').length})',
                    1,
                    const Color(0xFFDAA520)),
                const SizedBox(width: 8),
                _buildTabButton('Approved (2)', 2, const Color(0xFF1E88E5)),
                const SizedBox(width: 8),
                _buildHistoryButton(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Content based on selected tab
          Expanded(
            child: _buildTabContent(),
          ),

          // Bottom Navigation
          const BottomNavigation(currentRoute: '/dashboard'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, Color color) {
    bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : const Color(0xFF9E9E9E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    bool isSelected = selectedTab == 3;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = 3;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFF9E9E9E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.history,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (selectedTab) {
      case 0:
        return _buildAvailableContent();
      case 1:
        return _buildPendingContent();
      case 2:
        return _buildApprovedContent();
      case 3:
        return _buildHistoryContent();
      default:
        return _buildAvailableContent();
    }
  }

  Widget _buildAvailableContent() {
    if (_isLoadingTrips) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      child: _availableTrips.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                      child: Text("No trips available right now."))),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _availableTrips.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'New trip requests are available for you to accept',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }
                return _buildTripCard(_availableTrips[index - 1]);
              },
            ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trip['pickup_address'] ?? 'Unknown Pickup',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                trip['trip_type'] ?? 'ONE WAY',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trip['drop_address'] ?? 'Unknown Drop',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Date : ${_formatTripTime(trip['planned_start_at'])}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'customer : ${trip['customer_name'] ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (trip['trip_id'] != null) {
                    _requestTrip(trip['trip_id']);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error: Trip ID missing")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Request Ride',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTripTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildPendingContent() {
    final pendingRequests = _driverRequests
        .where((r) => (r['status'] ?? '').toString().toUpperCase() == 'PENDING')
        .toList();

    if (pendingRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAvailableTrips,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(
              child: Text(
                'No pending requests found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: pendingRequests.length,
        itemBuilder: (context, index) {
          final request = pendingRequests[index];
          final tripId = request['trip_id']?.toString();

          // Check if this trip is still in the available (OPEN) trips list
          // If not, it means the trip has been assigned to another driver
          final tripStillOpen =
              _availableTrips.any((t) => t['trip_id']?.toString() == tripId);

          // Also check explicit status fields if available
          final tripStatus =
              (request['trip_status'] ?? request['trip']?['trip_status'] ?? '')
                  .toString()
                  .toUpperCase();
          final assignedDriverId = request['assigned_driver_id'] ??
              request['trip']?['assigned_driver_id'];

          // Show "assigned to other" card if:
          // 1. Trip is not in available (OPEN) trips list, OR
          // 2. Trip status is explicitly ASSIGNED, OR
          // 3. There's an assigned driver that's not the current driver
          if (!tripStillOpen ||
              tripStatus == 'ASSIGNED' ||
              (assignedDriverId != null && assignedDriverId != _driverId)) {
            return _buildAssignedToOtherCard(request);
          }
          return _buildRequestCard(request);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Request ID: ...${(request['request_id'] ?? '').toString().substring(0, math.min((request['request_id'] ?? '').toString().length, 6))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request['status'] ?? 'PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request['pickup_address'] ?? 'Unknown Pickup',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request['drop_address'] ?? 'Unknown Drop',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer: ${request['customer_name'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (request['created_at'] != null)
                    Text(
                      'Requested: ${_formatTripTime(request['created_at'])}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (request['request_id'] != null) {
                    _cancelRequest(request['request_id'].toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedToOtherCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'The admin has assigned another driver',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.green, size: 20),
                        Container(
                          width: 2,
                          height: 20,
                          color: Colors.grey,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 20),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['pickup_address'] ?? 'Unknown Pickup',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            request['drop_address'] ?? 'Unknown Drop',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      request['trip_type'] ?? 'One-way',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup at ${_formatTripTime((request['planned_start_at'] ?? request['created_at'])?.toString())}',
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'customer : ${request['customer_name'] ?? 'Unknown'}',
                            style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedContent() {
    final approvedRequests = _driverRequests.where((r) {
      final status = (r['status'] ?? '').toString().toUpperCase();
      return status == 'APPROVED' ||
          status == 'ACCEPTED' ||
          status == 'STARTED';
    }).toList();

    if (approvedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No approved trips yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your approved trips are ready to start',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          ...approvedRequests.map((request) {
            return Column(
              children: [
                _buildApprovedCard(
                  pickup: request['pickup_address'] ?? 'Unknown Pickup',
                  drop: request['drop_address'] ?? 'Unknown Drop',
                  type: request['trip_type'] ??
                      'One-way', // Assuming trip_type exists or defaulting
                  isCompleted:
                      (request['status'] ?? '').toString().toUpperCase() ==
                          'STARTED',
                  customer: request['customer_name'] ?? 'Unknown Customer',
                  phone: request['customer_phone'] ??
                      'No Phone', // Assuming field name
                  odometer: request['starting_km']?.toString() ?? '',
                  requestId: request['request_id']?.toString() ?? '',
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildApprovedCard({
    required String pickup,
    required String drop,
    required String type,
    required bool isCompleted,
    required String customer,
    required String phone,
    required String odometer,
    String? requestId,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFC4C4C4), // Grey background from image
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Trip Type (Top Right)
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              type,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locations
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.green, size: 24),
                      Container(
                        width: 2,
                        height: 12,
                        color: Colors.transparent, // flexible spacer
                      ),
                      const Icon(Icons.location_on,
                          color: Color(0xFF8B0000), size: 24), // Dark red
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Addresses
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          right: 60.0), // Space for "Round"
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickup,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            drop,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom Section: Details + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left Side: Trip Details
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pickup at 6:30 PM ( 12 Mar )', // Placeholder - should use real data if available
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'customer : $customer',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Side: Actions
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Small Action Buttons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildSquareActionButton(
                              Icons.close,
                              Colors.red,
                              onTap: () => _showApprovedCancelDialog(context),
                            ),
                            const SizedBox(width: 8),
                            _buildSquareActionButton(
                              Icons.navigation,
                              Colors.blue,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Opening navigation...')),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildSquareActionButton(
                              Icons.call,
                              Colors.green,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Calling $customer...')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Start/Complete Trip Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (isCompleted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TripCompletedScreen(
                                      tripData: {
                                        'pickup': pickup,
                                        'drop': drop,
                                        'type': type,
                                        'customer': customer,
                                        'phone': phone,
                                        'request_id': requestId,
                                      },
                                      startingKm: odometer,
                                    ),
                                  ),
                                ).then((_) => _fetchAvailableTrips());
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TripStartScreen(
                                      tripData: {
                                        'pickup': pickup,
                                        'drop': drop,
                                        'type': type,
                                        'customer': customer,
                                        'phone': phone,
                                        'request_id': requestId,
                                      },
                                    ),
                                  ),
                                ).then((_) => _fetchAvailableTrips());
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF1565C0), // Dark Blue
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.check_circle_outline
                                      : Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCompleted ? 'Complete' : 'Start Trip',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareActionButton(IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  void _showApprovedCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFE8E8E8),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        size: 24, color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'sure you want to close this trip?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Once you close this trip, you will not be able to modify any trip details. Please review the final amount before confirming.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Final Amount: ₹800.00',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Reason for Cancelling Trip',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'No, Go Back',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Trip closed successfully')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Yes, Cancel Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    // Filter for history: completed, cancelled, rejected
    final historyRequests = _driverRequests.where((r) {
      final status = (r['status'] ?? '').toString().toUpperCase();
      return ['COMPLETED', 'CANCELLED', 'REJECTED'].contains(status);
    }).toList();

    if (historyRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No detailed history yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF424242),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Text(
                      'Filter',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFBDBDBD),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(0.8),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(1.2), // Status column
                },
                border: TableBorder.all(color: Colors.white70),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF9E9E9E)),
                    children: [
                      _buildTableHeader('No'),
                      _buildTableHeader('Date'),
                      _buildTableHeader('Pickup'),
                      _buildTableHeader('Status'),
                    ],
                  ),
                  ...historyRequests.asMap().entries.map((entry) {
                    final index = entry.key;
                    final request = entry.value;
                    final dateStr = request['created_at'] != null
                        ? _formatTripTime(request['created_at'])
                        : '-';
                    final status = request['status'] ?? '-';

                    return TableRow(
                      decoration: BoxDecoration(
                        color: index % 2 == 0
                            ? const Color(0xFFC0C0C0)
                            : const Color(0xFFBDBDBD),
                      ),
                      children: [
                        _buildTableCell('${index + 1}'),
                        _buildTableCell(dateStr),
                        _buildTableCell(request['pickup_address'] ?? '-'),
                        _buildTableCell(status),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.2, size.height * 0.3);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.65, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CircularTextPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    const textStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Color(0xFF8B4513),
    );

    _drawTextOnCircle(canvas, 'CHOLA CABS', center, radius, textStyle, -1.5);
  }

  void _drawTextOnCircle(Canvas canvas, String text, Offset center,
      double radius, TextStyle style, double startAngle) {
    final angleStep = 6.28 / text.length;

    for (int i = 0; i < text.length; i++) {
      final angle = startAngle + (i * angleStep);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + 1.57);

      final textPainter = TextPainter(
        text: TextSpan(text: text[i], style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
