import 'package:flutter/material.dart';
import 'trip_start_screen.dart';
import 'dart:math' as math;
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/app_drawer.dart';
import '../widgets/bottom_navigation.dart';
import '../constants/app_colors.dart';
import '../services/trip_state_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

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
      final trips = results[0] as List<dynamic>;
      final requests = results[1] as List<dynamic>;

      // 2. Filter available trips (Exclude ones already requested)
      final requestedTripIds = requests
          .where((r) =>
              (r['status'] ?? '').toString().toUpperCase() != 'CANCELLED')
          .map((r) => r['trip_id'].toString())
          .toSet();
      final filteredTrips = trips
          .where((t) => !requestedTripIds.contains(t['trip_id'].toString()))
          .toList();

      if (mounted) {
        setState(() {
          _availableTrips = filteredTrips;
          _driverRequests = requests;
          _isLoadingTrips = false;
        });
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
      _fetchAvailableTrips();
    }
  }

  Future<void> _showCancelConfirmation(String requestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Request'),
          content:
              const Text('Are you sure you want to cancel this trip request?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _cancelRequest(requestId);
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
    if (_tripStateService.isReadyForTrip) {
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

    return Column(
      children: [
        // Logo and message
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                child: Image.asset(
                  'assets/images/chola_cabs_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'TAXI SERVICES',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Travel with us',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB8860B),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Availability is turned off. You won\'t receive\nnew trip requests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You\'re currently offline.\nTurn on availability to see trips.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
            color: Colors.black.withOpacity(0.1),
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
          return _buildRequestCard(pendingRequests[index]);
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
            color: Colors.black.withOpacity(0.1),
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

  Widget _buildPendingCard({
    required String headerText,
    required Color headerColor,
    required String customerName,
    required bool isDelete,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDCDCDC),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              headerText,
              style: TextStyle(
                color: headerColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.green, size: 24),
                        Container(
                            width: 2, height: 20, color: Colors.grey.shade400),
                        const Icon(Icons.location_on,
                            color: Colors.red, size: 24),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Airport Terminal 1',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'City Center Mall',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'One-way',
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.bold),
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
                        const Text(
                          'Pickup at 6:30 PM ( 12 Mar )',
                          style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'customer : $customerName',
                          style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Flexible(
                      child: ElevatedButton(
                        onPressed: () {
                          if (!isDelete) {
                            _showPendingCancelDialog(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDelete ? Colors.black : const Color(0xFFD32F2F),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isDelete ? Icons.delete : Icons.cancel,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isDelete ? 'Delete' : 'Cancel',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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
    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The trip has been approved and is ready to start',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          _buildApprovedCard(
            pickup: 'Karaikudi',
            drop: 'Chennai',
            type: 'One-way',
            isCompleted: true,
            customer: 'Sham',
            phone: '+91 9876543210',
            odometer: '1200',
          ),
          const SizedBox(height: 16),
          _buildApprovedCard(
            pickup: 'kanyakumari',
            drop: 'Chennai',
            type: 'Round',
            isCompleted: false,
            customer: 'Sham',
            phone: '+91 9876543210',
            odometer: '',
          ),
          const SizedBox(height: 16),
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
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFDCDCDC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 22),
                  const SizedBox(height: 12),
                  const Icon(Icons.location_on, color: Colors.red, size: 22),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      drop,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildActionIcon(Icons.close, Colors.red,
                          onTap: () => _showApprovedCancelDialog(context)),
                      const SizedBox(width: 8),
                      _buildActionIcon(Icons.navigation, Colors.blue,
                          onTap: () {
                        // Add navigation logic here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Opening navigation...')),
                        );
                      }),
                      const SizedBox(width: 8),
                      _buildActionIcon(Icons.call, Colors.green, onTap: () {
                        // Add call logic here
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling $customer...')),
                        );
                      }),
                    ],
                  ),
                ],
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
                    const Text(
                      'Pickup at 6:30 PM ( 12 Mar )',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'customer : $customer',
                      style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Starting Odometer Km : ',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white70,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  odometer,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_note,
                                    size: 18, color: Colors.grey),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 6,
              ),
              ElevatedButton(
                onPressed: isCompleted
                    ? null
                    : () {
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
                              },
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted
                      ? AppColors.greenLight
                      : const Color(0xFF2962FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      isCompleted ? 'Complete Trip' : 'Start Trip',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
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

  Widget _buildActionIcon(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _showPendingCancelDialog(BuildContext context) {
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
                  const Text(
                    'Cancel Trip ?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'You are about to cancel this trip. This action cannot be undone. Please confirm only if you are unable to continue the trip.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.4,
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
                              content: Text('Trip cancelled successfully')),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completed Trips Here',
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
                      'History Filter',
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
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(2),
                  3: FlexColumnWidth(3),
                },
                border: TableBorder.all(color: Colors.white70),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFF9E9E9E)),
                    children: [
                      _buildTableHeader('No'),
                      _buildTableHeader('Trip ID'),
                      _buildTableHeader('Trip Date'),
                      _buildTableHeader('Pickup Point'),
                    ],
                  ),
                  ...List.generate(
                      15,
                      (index) => TableRow(
                            decoration: BoxDecoration(
                              color: index % 2 == 0
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFBDBDBD),
                            ),
                            children: [
                              _buildTableCell('${index + 1}'),
                              _buildTableCell('TRP-10245'),
                              _buildTableCell('12 Feb 2025'),
                              _buildTableCell('Koviloor'),
                            ],
                          )),
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

  Widget _buildDrawer() {
    return const AppDrawer();
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
