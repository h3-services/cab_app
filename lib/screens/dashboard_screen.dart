import '../services/permission_service.dart';
import '../services/network_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'trip/trip_start_screen.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/common/app_drawer.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/dialogs/trip_details_dialog.dart';
import '../services/trip_state_service.dart';
import '../services/api_service.dart';
import '../services/location_service_manager.dart';
import '../services/battery_optimization_service.dart';
import '../services/background_service.dart';
import '../constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final TripStateService _tripStateService = TripStateService();
  int selectedTab = 0; // 0: Available, 1: Pending, 2: Approved, 3: History
  String? _driverId;
  bool _isCheckingStatus = true; // Block UI until verified
  List<dynamic> _availableTrips = [];
  List<dynamic> _driverRequests = [];
  List<dynamic> _allTrips = [];
  bool _isLoadingTrips = false;
  Timer? _autoRefreshTimer;
  String _historyFilter = 'All'; // Filter state for history
  String _approvedFilter = 'All'; // Filter state for approved trips
  double _walletBalance = 0.0; // Wallet balance
  List<dynamic>? _cachedHistoryTrips; // Cache for history trips
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _shakeController!, curve: Curves.elasticIn),
    );
    _loadDriverId();
    _requestLocationPermissions();
    
    // Initialize network monitoring
    NetworkService().initialize((isConnected) {
      if (!isConnected && mounted) {
        NetworkService.showNoNetworkDialog(context);
      }
    });
    
    // Listen for foreground FCM messages to handle rejection
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;
      if (type == 'REGISTRATION_REJECTED') {
        Navigator.pushReplacementNamed(context, '/approval-pending');
      }
    });
  }

  Future<void> _requestLocationPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if permissions were already requested in this app session
      final permissionsRequested = prefs.getBool('permissions_requested_once') ?? false;
      if (permissionsRequested) {
        debugPrint('Permissions already requested, skipping...');
        return;
      }
      
      final lastPermissionCheck = prefs.getInt('last_permission_check') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Only check permissions once per day to avoid repeated prompts
      if (now - lastPermissionCheck < 86400000) { // 24 hours in milliseconds
        debugPrint('Permission check skipped - checked recently');
        return;
      }
      
      final backgroundGranted = prefs.getBool('background_location_granted') ?? false;
      final dontShowAgain = prefs.getBool('dont_show_permission_dialog') ?? false;
      
      // If background permission was granted and user chose not to see dialog again, skip
      if (backgroundGranted && dontShowAgain) {
        debugPrint('Background permission already granted, skipping dialog');
        return;
      }
      
      // Check current permission status
      bool hasPermissions = await PermissionService.checkLocationPermissions();
      if (hasPermissions) {
        // Update stored status and skip dialog
        await prefs.setBool('background_location_granted', true);
        await prefs.setBool('dont_show_permission_dialog', true);
        await prefs.setInt('last_permission_check', now);
        await prefs.setBool('permissions_requested_once', true);
        debugPrint('All permissions already granted');
        return;
      }
      
      // Only show dialog if we don't have permissions and user hasn't opted out
      if (!dontShowAgain) {
        await prefs.setInt('last_permission_check', now);
        await PermissionService.showPermissionDialog(context);
      }
    } catch (e) {
      debugPrint('Permission error: $e');
    }
    
    // Request battery optimization exemption
    if (mounted) {
      await BatteryOptimizationService.ensureBatteryOptimizationDisabled(context);
    }
  }


  void _showBackgroundPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Background Location Required'),
        content: const Text(
          'For driver safety and continuous trip tracking, this app needs to access your location even when closed or minimized.\n\nPlease select "Allow all the time" in the next screen to enable background location tracking.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && selectedTab != 3) {
        _fetchAvailableTrips(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    _autoRefreshTimer?.cancel();
    NetworkService().dispose();
    // Don't stop location tracking when leaving dashboard - it should run continuously
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getString('driverId');
    });

    // Check if we already have cached data (returning from another screen)
    final cachedDriverData = prefs.getString('driver_data');
    final isAvailable = prefs.getBool('is_available') ?? false;
    
    if (_driverId != null && cachedDriverData != null) {
      // Skip full approval check, show UI immediately and load trips with loading indicator
      _tripStateService.setReadyForTrip(isAvailable);
      setState(() => _isCheckingStatus = false);
      _startAutoRefresh();
      // Start location tracking
      await LocationServiceManager.initializeAllServices();
      // Load trips with loading indicator so user knows to wait
      _fetchAvailableTrips(showLoading: true);
    } else if (_driverId != null) {
      // First time load, do full check
      _checkApprovalStatus(_driverId!);
    } else {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _checkApprovalStatus(String driverId) async {
    try {
      final driverData = await ApiService.getDriverDetails(driverId);

      // Cache all vehicles data on app start
      await ApiService.getAllVehicles(forceRefresh: true);

      // Store driver data for immediate access in other screens (like Wallet)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_data', jsonEncode(driverData));

      // Store individual fields for Profile and Drawer screens
      await prefs.setString('name', driverData['name'] ?? 'Driver');
      await prefs.setString('phoneNumber', driverData['phone_number'] ?? '');
      await prefs.setString('email', driverData['email'] ?? '');
      await prefs.setString(
          'primaryLocation', driverData['primary_location'] ?? '');
      await prefs.setString(
          'licenseNumber', driverData['licence_number'] ?? '');
      await prefs.setString('aadhaarNumber', driverData['aadhar_number'] ?? '');

      // Store vehicle details from cached data
      final vehicleData = await ApiService.getVehicleByDriverId(driverId);
      if (vehicleData != null) {
        await prefs.setString('vehicleType', vehicleData['vehicle_type'] ?? '');
        await prefs.setString('vehicleBrand', vehicleData['vehicle_brand'] ?? '');
        await prefs.setString('vehicleModel', vehicleData['vehicle_model'] ?? '');
        await prefs.setString('vehicleNumber', vehicleData['vehicle_number'] ?? '');
        await prefs.setString('vehicleColor', vehicleData['vehicle_color'] ?? '');
        await prefs.setString(
            'seatingCapacity', (vehicleData['seating_capacity'] ?? '').toString());
      }

      // Photo handling fallback (if needed)
      if (driverData['photo_url'] != null) {
        await prefs.setString('profile_photo_url', driverData['photo_url']);
      }

      final bool isApproved = driverData['is_approved'] == true;
      final String kycVerified =
          (driverData['kyc_verified'] ?? '').toString().toLowerCase();
      
      // Get locally stored availability preference (user's last choice)
      final isAvailable = prefs.getBool('is_available') ?? false;

      // Check if rejected
      if (kycVerified == 'rejected') {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/approval-pending');
        }
        return;
      }

      if (!isApproved ||
          (kycVerified != 'verified' && kycVerified != 'approved')) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/approval-pending');
        }
      } else {
        // Approved! Start location tracking and load trips
        await LocationServiceManager.initializeAllServices();
        
        if (mounted) {
          _tripStateService.setReadyForTrip(isAvailable);

          debugPrint('Main Loading: Fetching initial trips...');
          await _fetchAvailableTrips();

          if (mounted) {
            setState(() => _isCheckingStatus = false);
            _startAutoRefresh();
          }
        }
      }
    } catch (e) {
      debugPrint('Approval check error: $e');
      // On network error, allow user to continue but show offline state
      if (mounted) {
        setState(() => _isCheckingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Working in offline mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _fetchAvailableTrips({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _isLoadingTrips = true);
    }

    try {
      // Always fetch fresh driver data to get latest wallet balance
      if (_driverId != null) {
        final driverData = await ApiService.getDriverDetails(_driverId!);
        _walletBalance = (driverData['wallet_balance'] ?? 0.0).toDouble();
        
        // Update cached driver data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('driver_data', jsonEncode(driverData));
      }

      // Fetch only essential data in parallel
      final results = await Future.wait([
        ApiService.getAvailableTrips(),
        _driverId != null ? ApiService.getDriverRequests(_driverId!) : Future.value([]),
      ]);
      
      final trips = results[0] as List<dynamic>;
      final requests = results[1] as List<dynamic>;

      // Enhance requests with latest trip status
      final enhancedRequests = await Future.wait(requests.map((request) async {
        final tripId = request['trip_id']?.toString();
        if (tripId != null) {
          try {
            final tripDetails = await ApiService.getTripDetails(tripId);
            final enhanced = Map<String, dynamic>.from(request);
            
            // CRITICAL: Update assigned_driver_id from latest trip details
            enhanced['assigned_driver_id'] = tripDetails['assigned_driver_id'] ?? tripDetails['driver_id'] ?? request['assigned_driver_id'];
            
            enhanced['trip_status'] = tripDetails['trip_status'] ?? tripDetails['status'] ?? request['trip_status'];
            enhanced['odo_start'] = tripDetails['odo_start'] ?? request['odo_start'];
            enhanced['vehicle_type'] = tripDetails['vehicle_type'] ?? tripDetails['trip']?['vehicle_type'] ?? request['vehicle_type'] ?? request['trip']?['vehicle_type'];
            debugPrint('Enhanced vehicle_type: ${enhanced['vehicle_type']} (tripDetails: ${tripDetails['vehicle_type']}, tripDetails.trip: ${tripDetails['trip']?['vehicle_type']}, request: ${request['vehicle_type']}, request.trip: ${request['trip']?['vehicle_type']})');
            
            enhanced['trip_type'] = tripDetails['trip_type'] ?? tripDetails['trip']?['trip_type'] ?? request['trip_type'] ?? request['trip']?['trip_type'];
            
            enhanced['customer_phone'] = tripDetails['customer_phone'] ?? tripDetails['phone'] ?? request['customer_phone'] ?? request['phone'];
            enhanced['phone'] = enhanced['customer_phone'];
            
            debugPrint('[Trip $tripId] Assigned to driver: ${enhanced['assigned_driver_id']}, Current driver: $_driverId');
            return enhanced;
          } catch (e) {
            return Map<String, dynamic>.from(request);
          }
        }
        return Map<String, dynamic>.from(request);
      }));

      // Filter available trips
      final requestedTripIds = enhancedRequests
          .where((r) => (r['status'] ?? '').toString().toUpperCase() != 'CANCELLED')
          .map((r) => r['trip_id'].toString())
          .toSet();

      final openTrips = trips.where((t) {
        final status = (t['trip_status'] ?? t['status'] ?? '').toString();
        return status.trim().toUpperCase() == 'OPEN';
      }).toList();

      final filteredTrips = openTrips
          .where((t) => !requestedTripIds.contains(t['trip_id'].toString()))
          .toList();

      if (mounted) {
        setState(() {
          _allTrips = openTrips;
          _availableTrips = filteredTrips;
          _driverRequests = enhancedRequests;
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

  void _showCancelTripDialog(String requestId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/chola_cabs_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Cancel Trip',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'You are about to cancel this trip .This action cannot be undone. Please confirm only if you are unable to continue the trip.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'No, Go Back',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _performCancelRequest(requestId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Future<void> _performCancelRequest(String requestId) async {
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
          .showSnackBar(const SnackBar(content: Text("Trip cancelled")));
      
      await _fetchAvailableTrips();
      
      if (!mounted) return;
      setState(() {
        selectedTab = 0;
      });
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

      _fetchAvailableTrips();
    } catch (e) {
      if (e.toString().contains("Request already exists")) {
        final existingIndex = _driverRequests.indexWhere(
          (r) => r['trip_id'].toString() == tripId,
        );

        if (existingIndex != -1) {
          final existingRequest = _driverRequests[existingIndex];
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

    if (!_tripStateService.isReadyForTrip) {
      return Scaffold(
        backgroundColor: const Color(0xFFB0B0B0),
        appBar: const CustomAppBar(),
        endDrawer: const AppDrawer(),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
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
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.red,
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
                      value: false,
                      onChanged: (value) async {
                        if (_driverId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Driver ID not found. Please re-login.')),
                          );
                          return;
                        }
                        setState(() {
                          _tripStateService.setReadyForTrip(value);
                        });
                        try {
                          await ApiService.updateDriverAvailability(
                              _driverId!, value);
                        } catch (e) {
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
                      activeTrackColor: AppColors.greenPrimary,
                      inactiveThumbColor: Colors.grey.shade600,
                      inactiveTrackColor: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFC0C0C0),
              child: Row(
                children: [
                  _buildTabButton('Available (${_availableTrips.length})', 0,
                      const Color(0xFF757575)),
                  const SizedBox(width: 8),
                  _buildTabButton(
                      'Pending (${_driverRequests.where((r) {
                        final status = (r['status'] ?? '').toString().toUpperCase();
                        final tripStatus = (r['trip_status'] ?? '').toString().toUpperCase();
                        return status == 'PENDING' && 
                               tripStatus != 'COMPLETED' && 
                               tripStatus != 'CANCELLED' &&
                               tripStatus != 'ASSIGNED' &&
                               tripStatus != 'STARTED' &&
                               tripStatus != 'ON_TRIP' &&
                               tripStatus != 'ONWAY' &&
                               tripStatus != 'IN_PROGRESS';
                      }).length})',
                      1,
                      AppColors.orangeDark),
                  const SizedBox(width: 8),
                  _buildTabButton(
                      'Approved (${_driverRequests.where((r) {
                        final status =
                            (r['status'] ?? '').toString().toUpperCase();
                        final tripStatus =
                            (r['trip_status'] ?? '').toString().toUpperCase();
                        return (status == 'APPROVED' ||
                                status == 'ACCEPTED' ||
                                status == 'STARTED' ||
                                status == 'ON_TRIP' ||
                                status == 'ON-TRIP' ||
                                status == 'IN_PROGRESS' ||
                                status == 'IN-PROGRESS' ||
                                status == 'ONWAY' ||
                                status == 'ASSIGNED' ||
                                tripStatus == 'ASSIGNED' ||
                                tripStatus == 'STARTED' ||
                                tripStatus == 'ON_TRIP' ||
                                tripStatus == 'ON-TRIP' ||
                                tripStatus == 'IN_PROGRESS' ||
                                tripStatus == 'IN-PROGRESS' ||
                                tripStatus == 'ONWAY') &&
                            tripStatus != 'COMPLETED' &&
                            status != 'COMPLETED';
                      }).length})',
                      2,
                      const Color(0xFF1E88E5)),
                  const SizedBox(width: 8),
                  _buildHistoryButton(),
                ],
              ),
            ),
            Expanded(
              child: selectedTab == 0
                  ? SingleChildScrollView(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Image.asset(
                              'assets/images/chola_cabs_logo.png',
                              width: 100,
                              height: 100,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Availability is turned off. You won\'t receive\nnew trip requests.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'You\'re currently offline.\nTurn on availability to see trips.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    )
                  : _buildTabContent(),
            ),
            BottomNavigation(currentRoute: '/dashboard'),
          ],
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
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
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
                                ? AppColors.greenPrimary
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
                                ? AppColors.greenPrimary
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
                    activeTrackColor: AppColors.greenPrimary,
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
                    'Pending (${_driverRequests.where((r) {
                      final status = (r['status'] ?? '').toString().toUpperCase();
                      final tripStatus = (r['trip_status'] ?? '').toString().toUpperCase();
                      return status == 'PENDING' && 
                             tripStatus != 'COMPLETED' && 
                             tripStatus != 'CANCELLED' &&
                             tripStatus != 'ASSIGNED' &&
                             tripStatus != 'STARTED' &&
                             tripStatus != 'ON_TRIP' &&
                             tripStatus != 'ONWAY' &&
                             tripStatus != 'IN_PROGRESS';
                    }).length})',
                    1,
                    AppColors.orangeDark),
                const SizedBox(width: 8),
                _buildTabButton(
                    'Approved (${_driverRequests.where((r) {
                      final status =
                          (r['status'] ?? '').toString().toUpperCase();
                      final tripStatus =
                          (r['trip_status'] ?? '').toString().toUpperCase();
                      final assignedDriverId = r['assigned_driver_id']?.toString();
                      final isAssignedToMe = assignedDriverId == null || assignedDriverId == _driverId;

                      return isAssignedToMe &&
                          (status == 'APPROVED' ||
                              status == 'ACCEPTED' ||
                              status == 'STARTED' ||
                              status == 'ON_TRIP' ||
                              status == 'ON-TRIP' ||
                              status == 'IN_PROGRESS' ||
                              status == 'IN-PROGRESS' ||
                              status == 'ONWAY' ||
                              status == 'ASSIGNED' ||
                              tripStatus == 'ASSIGNED' ||
                              tripStatus == 'STARTED' ||
                              tripStatus == 'ON_TRIP' ||
                              tripStatus == 'ON-TRIP' ||
                              tripStatus == 'IN_PROGRESS' ||
                              tripStatus == 'IN-PROGRESS' ||
                              tripStatus == 'ONWAY') &&
                          tripStatus != 'COMPLETED' &&
                          status != 'COMPLETED';
                    }).length})',
                    2,
                    const Color(0xFF1E88E5)),
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
          BottomNavigation(currentRoute: '/dashboard'),
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
          // Refresh data when switching tabs, except History tab
          if (index != 3) {
            _fetchAvailableTrips();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: index == 0
                        ? [AppColors.grayPrimary, AppColors.black]
                        : index == 1
                            ? [AppColors.orangePrimary, AppColors.orangeDark]
                            : [AppColors.bluePrimary, AppColors.blueDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isSelected ? null : const Color(0xFF9E9E9E),
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
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppColors.greenPrimary, AppColors.greenDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : const Color(0xFF9E9E9E),
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
    // Check if wallet balance is negative
    if (_walletBalance < 0) {
      // Only allow history tab when wallet is negative
      if (selectedTab == 3) {
        return _buildHistoryContent();
      }
      return _buildWalletTopUpMessage();
    }
    
    // Show loading only when loading AND no cached data available
    if (_isLoadingTrips && _availableTrips.isEmpty && _driverRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
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

  Widget _buildWalletTopUpMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/chola_cabs_logo.png',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 24),
          const Text(
            'Wallet Balance Low',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your wallet balance is insufficient.\nPlease top up your wallet to view and accept trips.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.greenPrimary, AppColors.greenDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/wallet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Top Up Wallet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableContent() {
    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      child: _availableTrips.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                      child: Text("No trips available right now.", style: TextStyle(fontWeight: FontWeight.bold)))),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _availableTrips.length,
              itemBuilder: (context, index) {
                return _buildTripCard(_availableTrips[index]);
              },
            ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFC4C4C4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.bluePrimary, AppColors.blueDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_forward,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trip['trip_type'] ?? 'ONE WAY',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trip['vehicle_type'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.bluePrimary, AppColors.blueDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getVehicleIcon(trip['vehicle_type']),
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          trip['vehicle_type'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                    trip['pickup_address'] ?? 'Unknown Pickup',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
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
            const SizedBox(height: 4),
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
                        'Pickup Time : ${_formatPickupTime(trip['planned_start_at'])}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                '${trip['passenger_count'] ?? 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pets,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                '${trip['pet_count'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.luggage,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                '${trip['luggage_count'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ), 
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.greenPrimary, AppColors.greenDark],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    ),
                  ],
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

  String _formatPickupTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (e) {
      return '';
    }
  }

  Widget _buildPendingContent() {
    final pendingRequests = _driverRequests
        .where((r) {
          final status = (r['status'] ?? '').toString().toUpperCase();
          final tripStatus = (r['trip_status'] ?? '').toString().toUpperCase();
          
          // Only show truly pending requests, exclude completed, cancelled, assigned, and started trips
          return status == 'PENDING' && 
                 tripStatus != 'COMPLETED' && 
                 tripStatus != 'CANCELLED' &&
                 tripStatus != 'ASSIGNED' &&
                 tripStatus != 'STARTED' &&
                 tripStatus != 'ON_TRIP' &&
                 tripStatus != 'ONWAY' &&
                 tripStatus != 'IN_PROGRESS';
        })
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
                style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold),
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
          final assignedDriverId = request['assigned_driver_id'] ?? request['trip']?['assigned_driver_id'];

          // Show "assigned to other" only if explicitly assigned to different driver
          if (assignedDriverId != null && assignedDriverId != _driverId) {
            return _buildAssignedToOtherCard(request);
          }
          
          // Check if trip is still OPEN
          final tripStillOpen = _allTrips.any((t) => t['trip_id']?.toString() == tripId);
          if (!tripStillOpen) {
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
            color: const Color(0xFFC4C4C4),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenPrimary, AppColors.greenDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _formatTripType(request['trip_type'] ?? 'ONE WAY'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (request['vehicle_type'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.greenPrimary, AppColors.greenDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getVehicleIcon(request['vehicle_type']), size: 18, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            request['vehicle_type'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup Date : ${_formatTripTime(request['planned_start_at'] ?? request['created_at'])}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pickup Time : ${_formatPickupTime(request['planned_start_at'] ?? request['created_at'])}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 2),
                                Text(
                                  '${request['passenger_count'] ?? 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pets, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 2),
                                Text(
                                  '${request['pet_count'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.luggage, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 2),
                                Text(
                                  '${request['luggage_count'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFC4E4E),
                          const Color(0xFF882A2A)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (request['request_id'] != null) {
                          _showCancelTripDialog(
                              request['request_id'].toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        shadowColor: Colors.transparent,
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
          ]
        )
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
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                          _formatTripType(request['trip_type'] ?? 'One-way'),
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
                                'Pickup Time : ${_formatPickupTime((request['planned_start_at'] ?? request['created_at'])?.toString())}',
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
    var approvedRequests = _driverRequests.where((r) {
      final status = (r['status'] ?? '').toString().toUpperCase();
      final tripStatus = (r['trip_status'] ?? '').toString().toUpperCase();
      final assignedDriverId = r['assigned_driver_id']?.toString();

      // CRITICAL: Only show if assigned to THIS driver
      final isAssignedToMe = assignedDriverId == null || assignedDriverId == _driverId;

      return isAssignedToMe &&
          (status == 'APPROVED' ||
              status == 'ACCEPTED' ||
              status == 'STARTED' ||
              status == 'ON_TRIP' ||
              status == 'ON-TRIP' ||
              status == 'IN_PROGRESS' ||
              status == 'IN-PROGRESS' ||
              status == 'ONWAY' ||
              status == 'ASSIGNED' ||
              tripStatus == 'ASSIGNED' ||
              tripStatus == 'STARTED' ||
              tripStatus == 'ON_TRIP' ||
              tripStatus == 'ON-TRIP' ||
              tripStatus == 'IN_PROGRESS' ||
              tripStatus == 'IN-PROGRESS' ||
              tripStatus == 'ONWAY') &&
          tripStatus != 'COMPLETED' &&
          status != 'COMPLETED';
    }).toList();

    // Apply filter
    if (_approvedFilter != 'All') {
      approvedRequests = approvedRequests.where((r) {
        final tripStatus = (r['trip_status'] ?? '').toString().toUpperCase();
        if (_approvedFilter == 'Assigned') {
          return tripStatus == 'ASSIGNED';
        } else if (_approvedFilter == 'Started') {
          return tripStatus == 'STARTED' || 
                 tripStatus == 'ON_TRIP' || 
                 tripStatus == 'ON-TRIP' || 
                 tripStatus == 'IN_PROGRESS' || 
                 tripStatus == 'IN-PROGRESS' || 
                 tripStatus == 'ONWAY';
        }
        return true;
      }).toList();
    }

    // Sort by trip status: STARTED/ONGOING first, then ASSIGNED, then COMPLETED, CANCELLED
    approvedRequests.sort((a, b) {
      final statusA = (a['trip_status'] ?? a['status'] ?? 'ASSIGNED')
          .toString()
          .toUpperCase();
      final statusB = (b['trip_status'] ?? b['status'] ?? 'ASSIGNED')
          .toString()
          .toUpperCase();

      const statusOrder = {
        'STARTED': 0,
        'ON_TRIP': 0,
        'ON-TRIP': 0,
        'IN_PROGRESS': 0,
        'IN-PROGRESS': 0,
        'ONWAY': 0,
        'ASSIGNED': 1,
        'COMPLETED': 2,
        'CANCELLED': 3
      };
      final orderA = statusOrder[statusA] ?? 4;
      final orderB = statusOrder[statusB] ?? 4;

      return orderA.compareTo(orderB);
    });

    if (approvedRequests.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Approved Trips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: _showApprovedFilterDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF424242),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _approvedFilter,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAvailableTrips,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.black),
                        SizedBox(height: 16),
                        Text(
                          'No approved trips yet',
                          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Swipe down to refresh',
                          style: TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAvailableTrips,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Approved Trips',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showApprovedFilterDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF424242),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _approvedFilter,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...approvedRequests.map((request) {
              String tripStatus = (request['trip_status'] ?? 'ASSIGNED')
                  .toString()
                  .toUpperCase();
              final customerPhone = (request['customer_phone'] ??
                      request['phone'] ??
                      request['trip']?['customer_phone'] ??
                      request['trip']?['phone'] ??
                      '')
                  .toString()
                  .trim();
              final displayPhone =
                  customerPhone.isEmpty ? 'No Phone' : customerPhone;

              return Column(
                children: [
                  _buildApprovedCard(
                    pickup: request['pickup_address'] ?? 'Unknown Pickup',
                    drop: request['drop_address'] ?? 'Unknown Drop',
                    type: _formatTripType(request['trip_type'] ?? 'One-way'),
                    tripStatus: tripStatus,
                    customer: request['customer_name'] ?? 'Unknown Customer',
                    phone: displayPhone,
                    odometer: (request['starting_km'] ??
                            request['odo_start'] ??
                            request['trip']?['odo_start'] ??
                            request['trip']?['starting_km'] ??
                            '')
                        .toString(),
                    requestId: request['request_id']?.toString() ?? '',
                    tripId: request['trip_id']?.toString(),
                    request: request,
                    vehicleType: request['vehicle_type'],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedCard({
    required String pickup,
    required String drop,
    required String type,
    required String tripStatus,
    required String customer,
    required String phone,
    required String odometer,
    String? requestId,
    String? tripId,   
    Map<String, dynamic>? request,
    String? vehicleType,
  }) {
    // Simple status-based logic
    String buttonText;
    Color buttonColor;
    bool isEnabled;

    // Check for various started statuses
    bool isTripStarted = tripStatus == 'STARTED' ||
        tripStatus == 'IN_PROGRESS' ||
        tripStatus == 'ON_TRIP' ||
        tripStatus == 'ON-TRIP' ||
        tripStatus == 'ONWAY' ||
        tripStatus.contains('STARTED') ||
        tripStatus.contains('PROGRESS');

    // Check if trip_status is COMPLETED or CANCELLED directly
    if (tripStatus == 'COMPLETED') {
      buttonText = 'Trip Completed';
      buttonColor = Colors.green;
      isEnabled = false;
    } else if (tripStatus == 'CANCELLED') {
      buttonText = 'Trip Cancelled';
      buttonColor = Colors.red;
      isEnabled = false;
    } else if (isTripStarted) {
      buttonText = 'Complete Trip';
      buttonColor = Colors.transparent;
      isEnabled = true;
    } else {
      buttonText = 'Start Trip';
      buttonColor = const Color(0xFF1565C0);
      isEnabled = true;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFFC4C4C4),
          borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.greenPrimary, AppColors.greenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      type,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (vehicleType != null)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.greenPrimary, AppColors.greenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getVehicleIcon(vehicleType), size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        vehicleType,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.location_on,
                      color: Colors.green, size: 24),
                  Container(
                      width: 2, height: 12, color: Colors.transparent),
                  const Icon(Icons.location_on,
                      color: Color(0xFF8B0000), size: 24),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pickup,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(drop,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Pickup at ${_formatTripTime(request?['planned_start_at'] ?? request?['created_at'])}',
                        style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('customer : $customer',
                        style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Phone: $phone',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
             
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 90),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenPrimary, AppColors.greenDark],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _makePhoneCall(phone),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: const Icon(Icons.call, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    decoration: BoxDecoration(
                      gradient: tripStatus == 'CANCELLED'
                          ? LinearGradient(
                              colors: [
                                const Color(0xFFFC4E4E),
                                const Color(0xFF882A2A)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : tripStatus == 'COMPLETED'
                              ? LinearGradient(
                                  colors: [
                                    AppColors.greenPrimary,
                                    AppColors.greenDark
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : isTripStarted
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.greenPrimary,
                                        AppColors.greenDark
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        AppColors.bluePrimary,
                                        AppColors.blueDark
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: isEnabled
                          ? () async {
                              debugPrint('\n=== TRIP DATA DEBUG ===');
                              debugPrint('vehicleType parameter: $vehicleType');
                              debugPrint('type parameter: $type');
                              debugPrint('=======================\n');
                              if (isTripStarted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        TripCompletedScreen(
                                      tripData: {
                                        'pickup': pickup,
                                        'drop': drop,
                                        'type': type,
                                        'vehicle_type': vehicleType,
                                        'customer': customer,
                                        'phone': phone,
                                        'request_id': requestId,
                                        'trip_id': tripId,
                                      },
                                      startingKm: odometer,
                                    ),
                                  ),
                                ).then((_) => _fetchAvailableTrips());
                              } else {
                                if (tripId != null) {
                                  try {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TripStartScreen(
                                          tripData: {
                                            'pickup': pickup,
                                            'drop': drop,
                                            'type': type,
                                            'vehicle_type': vehicleType,
                                            'customer': customer,
                                            'phone': phone,
                                            'request_id': requestId,
                                            'trip_id': tripId,
                                          },
                                        ),
                                      ),
                                    ).then((result) {
                                      if (result != null)
                                        _fetchAvailableTrips();
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to navigate: $e'),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tripStatus == 'COMPLETED'
                                ? Icons.check_circle
                                : isTripStarted
                                    ? Icons.check_circle_outline
                                    : Icons.timer_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
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
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'No Phone') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'[^0-9+]'), ''),
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch phone call'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSquareActionButton(IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  void _showHistoryFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/chola_cabs_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select the time period for your trip history',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  _buildFilterOption('All Trips', 'All'),
                  const SizedBox(height: 12),
                  _buildFilterOption('This Week', 'Week'),
                  const SizedBox(height: 12),
                  _buildFilterOption('This Month', 'Month'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
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

  void _showApprovedFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/chola_cabs_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter Approved Trips',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Filter trips by their status',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  _buildApprovedFilterOption('All', 'All'),
                  const SizedBox(height: 12),
                  _buildApprovedFilterOption('Assigned', 'Assigned'),
                  const SizedBox(height: 12),
                  _buildApprovedFilterOption('Started', 'Started'),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
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

  Widget _buildFilterOption(String title, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _historyFilter = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _historyFilter == value ? AppColors.greenPrimary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _historyFilter == value ? AppColors.greenPrimary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _historyFilter == value ? AppColors.greenPrimary : Colors.grey.shade400,
                  width: 2,
                ),
                color: _historyFilter == value ? AppColors.greenPrimary : Colors.transparent,
              ),
              child: _historyFilter == value
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _historyFilter == value ? AppColors.greenPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedFilterOption(String title, String value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _approvedFilter = value;
        });
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _approvedFilter == value ? AppColors.greenPrimary.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _approvedFilter == value ? AppColors.greenPrimary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _approvedFilter == value ? AppColors.greenPrimary : Colors.grey.shade400,
                  width: 2,
                ),
                color: _approvedFilter == value ? AppColors.greenPrimary : Colors.transparent,
              ),
              child: _approvedFilter == value
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _approvedFilter == value ? AppColors.greenPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    // If we have cached data, show it immediately and fetch in background
    if (_cachedHistoryTrips != null) {
      // Fetch fresh data in background without blocking UI
      ApiService.getAllTrips().then((trips) {
        if (mounted) {
          setState(() {
            _cachedHistoryTrips = trips;
          });
        }
      });
      
      return _buildHistoryTable(_cachedHistoryTrips!);
    }
    
    // First load - show loading indicator
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getAllTrips(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading trip history',
                style: TextStyle(color: Colors.red)),
          );
        }

        final trips = snapshot.data ?? [];
        _cachedHistoryTrips = trips;
        return _buildHistoryTable(trips);
      },
    );
  }
  
  Widget _buildHistoryTable(List<dynamic> allTrips) {

        // Filter for completed trips assigned to this driver
        var completedTrips = allTrips.where((trip) {
          final status = (trip['trip_status'] ?? trip['status'] ?? '')
              .toString()
              .toUpperCase();
          final assignedDriverId = trip['assigned_driver_id']?.toString();
          return status == 'COMPLETED' && assignedDriverId == _driverId;
        }).toList();

        // Apply date filter
        if (_historyFilter != 'All') {
          final now = DateTime.now();
          completedTrips = completedTrips.where((trip) {
            final dateStr = trip['completed_at'] ?? trip['created_at'];
            if (dateStr == null) return false;
            
            try {
              final tripDate = DateTime.parse(dateStr.toString());
              if (_historyFilter == 'Week') {
                final weekAgo = now.subtract(const Duration(days: 7));
                return tripDate.isAfter(weekAgo);
              } else if (_historyFilter == 'Month') {
                final monthAgo = DateTime(now.year, now.month - 1, now.day);
                return tripDate.isAfter(monthAgo);
              }
            } catch (e) {
              return false;
            }
            return true;
          }).toList();
        }

        // Sort by completion date (most recent first)
        completedTrips.sort((a, b) {
          final dateA =
              a['completed_at'] ?? a['updated_at'] ?? a['created_at'] ?? '';
          final dateB =
              b['completed_at'] ?? b['updated_at'] ?? b['created_at'] ?? '';
          return dateB.toString().compareTo(dateA.toString());
        });

        if (completedTrips.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed trips yet',
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
                    'Completed Trips Here',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: _showHistoryFilterDialog,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF424242),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'History Filter',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 20),
                        ],
                      ),
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width),
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(50),
                          1: FixedColumnWidth(100),
                          2: FixedColumnWidth(150),
                          3: FixedColumnWidth(150),
                          4: FixedColumnWidth(80),
                          5: FixedColumnWidth(80),
                          6: FixedColumnWidth(100),
                          7: FixedColumnWidth(100),
                          8: FixedColumnWidth(100),
                          9: FixedColumnWidth(100),
                        },
                        border: TableBorder.all(color: Colors.white70),
                        children: [
                          TableRow(
                            decoration:
                                const BoxDecoration(color: Color(0xFF9E9E9E)),
                            children: [
                              _buildTableHeader('No'),
                              _buildTableHeader('Date'),
                              _buildTableHeader('Pickup'),
                              _buildTableHeader('Drop'),
                              _buildTableHeader('Start KM'),
                              _buildTableHeader('End KM'),
                              _buildTableHeader('Distance'),
                              _buildTableHeader('Total Trip Cost'),
                              _buildTableHeader('Service Fee (10%)'),
                              _buildTableHeader('Status'),
                            ],
                          ),
                          ...completedTrips.asMap().entries.map((entry) {
                            final index = entry.key;
                            final trip = entry.value;

                            // Original fields
                            final dateStr =
                                trip['completed_at'] ?? trip['created_at'];
                            final formattedDate = dateStr != null
                                ? _formatTripTime(dateStr.toString())
                                : '-';
                            final pickup = trip['pickup_address'] ?? '-';
                            final drop = trip['drop_address'] ?? '-';
                            final status = (trip['trip_status'] ??
                                    trip['status'] ??
                                    'COMPLETED')
                                .toString()
                                .toUpperCase();

                            // Odometer readings
                            final startKm =
                                trip['odo_start'] ?? trip['starting_km'] ?? '0';
                            final endKm =
                                trip['odo_end'] ?? trip['ending_km'] ?? '0';

                            // New/Calculated values
                            final totalCost = (trip['fare'] ??
                                    trip['total_fare'] ??
                                    trip['total_amount'] ??
                                    trip['amount'] ??
                                    800.0)
                                .toDouble();
                            final serviceFee = totalCost * 0.10;
                            final distance =
                                trip['distance'] ?? trip['distance_km'] ?? 5;

                            return TableRow(
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? const Color(0xFFC0C0C0)
                                    : const Color(0xFFBDBDBD),
                              ),
                              children: [
                                _buildTableCell('${index + 1}'),
                                _buildTableCell(formattedDate),
                                _buildTableCell(pickup),
                                _buildTableCell(drop),
                                _buildTableCell('$startKm'),
                                _buildTableCell('$endKm'),
                                _buildTableCell('$distance km'),
                                _buildTableCell(
                                    '₹${totalCost.toStringAsFixed(2)}'),
                                _buildTableCell(
                                    '₹${serviceFee.toStringAsFixed(2)}'),
                                _buildTableCell(status),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
  }

  void _showApprovedCancelDialog(BuildContext context, String tripId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/chola_cabs_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cancel Approved Trip?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Are you sure you want to cancel this approved trip? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'No, Go Back',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ApiService.updateTripStatus(tripId, 'CANCELLED');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Trip cancelled successfully')),
                          );
                          _fetchAvailableTrips();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to cancel trip: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  IconData _getVehicleIcon(String vehicleType) {
    final type = vehicleType.toUpperCase();
    if (type.contains('SUV')) return Icons.directions_car;
    if (type.contains('SEDAN')) return Icons.directions_car_outlined;
    if (type.contains('HATCHBACK')) return Icons.directions_car_filled;
    if (type.contains('TEMPO')) return Icons.local_shipping;
    if (type.contains('TRUCK')) return Icons.local_shipping_outlined;
    if (type.contains('VAN')) return Icons.airport_shuttle;
    if (type.contains('BUS')) return Icons.directions_bus;
    if (type.contains('BIKE') || type.contains('MOTORCYCLE')) return Icons.two_wheeler;
    return Icons.directions_car;
  }

  String _formatTripType(String? tripType) {
    if (tripType == null || tripType.isEmpty) return 'One-way';
    final type = tripType.toUpperCase();
    if (type.contains('ROUND') || type == 'ROUND_TRIP' || type == 'ROUNDTRIP') return 'Round-trip';
    if (type.contains('ONE') || type == 'ONE_WAY' || type == 'ONEWAY') return 'One-way';
    return tripType;
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
