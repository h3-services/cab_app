import 'package:flutter/material.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/bottom_navigation.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'trip_details_input_screen.dart';

class TripStartScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripStartScreen({super.key, required this.tripData});

  @override
  State<TripStartScreen> createState() => _TripStartScreenState();
}

class _TripStartScreenState extends State<TripStartScreen> {
  final TextEditingController _startingKmController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: _buildDrawer(context),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Text(
              'Starting KM',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Starting Odometer Reading',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                const SizedBox(height: 20),
                const Text('Starting KM *',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _startingKmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon:
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back to Trip page',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenPrimary, AppColors.greenDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_startingKmController.text.isNotEmpty) {
                          final tripId = widget.tripData['trip_id'];
                          final requestId = widget.tripData['request_id'];

                          try {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (c) => const Center(
                                  child: CircularProgressIndicator()),
                            );

                            if (tripId != null) {
                              await ApiService.updateOdometerStart(
                                  tripId.toString(),
                                  int.parse(_startingKmController.text));

                              if (requestId != null) {
                                try {
                                  await ApiService.updateRequestStatus(
                                      requestId.toString(), "STARTED");
                                } catch (e) {
                                  debugPrint(
                                      "Syncing request status failed: $e");
                                }
                              }
                            } else {
                              throw Exception(
                                  "Missing Trip Information: trip_id is required");
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.pop(context, tripId?.toString());
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Trip started successfully!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);

                              if (e.toString().contains(
                                  "Cannot start trip with status STARTED")) {
                                if (requestId != null) {
                                  try {
                                    await ApiService.updateRequestStatus(
                                        requestId.toString(), "STARTED");
                                  } catch (_) {}
                                }
                                Navigator.pop(context, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Trip is already in progress')),
                                );
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to start trip: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Start Ride',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chola_cabs_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade400,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tom Holland',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDrawerMenuItem(context, Icons.person_outline, 'Profile',
                      'View and edit your personal details'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      'App preferences, notifications, and privacy'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.help_outline, 'Help',
                      'Get help and contact the admin for support'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.logout, 'Sign out',
                      'Log out of your account safely',
                      isSignOut: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
      BuildContext context, IconData icon, String title, String subtitle,
      {bool isSignOut = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (title == 'Profile') {
            Navigator.pushNamed(context, '/profile');
          } else if (title == 'Sign out') {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignOut ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSignOut ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripCompletedScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String startingKm;

  const TripCompletedScreen(
      {super.key, required this.tripData, required this.startingKm});

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  final TextEditingController _endingKmController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: _buildDrawer(context),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Completion Details',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                const SizedBox(height: 20),
                const Text('Ending KM *',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _endingKmController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      suffixIcon:
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Back to Trip page',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenPrimary, AppColors.greenDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_endingKmController.text.isNotEmpty) {
                          try {
                            final endingKm =
                                num.tryParse(_endingKmController.text);
                            if (endingKm == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Invalid ending KM')),
                              );
                              return;
                            }

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (c) => const Center(
                                  child: CircularProgressIndicator()),
                            );

                            final tripId = widget.tripData['trip_id'];
                            if (tripId != null) {
                              final result = await ApiService.updateOdometerEnd(
                                  tripId.toString(), endingKm);

                              if (!context.mounted) return;
                              Navigator.pop(context);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TripDetailsInputScreen(
                                    tripData: widget.tripData,
                                    startingKm: widget.startingKm,
                                    endingKm: _endingKmController.text,
                                  ),
                                ),
                              );
                            } else {
                              if (!context.mounted) return;
                              Navigator.pop(context);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TripDetailsInputScreen(
                                    tripData: widget.tripData,
                                    startingKm: widget.startingKm,
                                    endingKm: _endingKmController.text,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Calculate Cost',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chola_cabs_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade400,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tom Holland',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDrawerMenuItem(context, Icons.person_outline, 'Profile',
                      'View and edit your personal details'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      'App preferences, notifications, and privacy'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.help_outline, 'Help',
                      'Get help and contact the admin for support'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.logout, 'Sign out',
                      'Log out of your account safely',
                      isSignOut: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
      BuildContext context, IconData icon, String title, String subtitle,
      {bool isSignOut = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (title == 'Profile') {
            Navigator.pushNamed(context, '/profile');
          } else if (title == 'Sign out') {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignOut ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSignOut ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TripSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String startingKm;
  final String endingKm;
  final Map<String, dynamic>? tripDetails;
  final num? distance;
  final num? fare;

  const TripSummaryScreen({
    super.key,
    required this.tripData,
    required this.startingKm,
    required this.endingKm,
    this.tripDetails,
    this.distance,
    this.fare,
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  num? actualFare;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTripFare();
  }

  Future<void> _fetchTripFare() async {
    final tripId = widget.tripData['trip_id'];
    if (tripId == null) {
      setState(() {
        actualFare = widget.fare ?? 500;
        isLoading = false;
      });
      return;
    }

    try {
      final tripDetails = await ApiService.getTripDetails(tripId.toString());
      setState(() {
        actualFare = tripDetails['fare'] ??
            tripDetails['total_fare'] ??
            tripDetails['total_cost'] ??
            tripDetails['amount'] ??
            widget.fare ??
            500;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        actualFare = widget.fare ?? 500;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFB0B0B0),
        appBar: const CustomAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final startKm = num.tryParse(widget.startingKm) ?? 0;
    final endKm = num.tryParse(widget.endingKm) ?? 0;
    final dist = widget.distance ?? (endKm - startKm).abs();
    final ratePerKm = 12.0;

    // Use actualFare from API, fallback to calculation
    final totalCost = (actualFare != null && actualFare! > 0)
        ? actualFare!.toDouble()
        : (dist * ratePerKm * 1.10);
    final walletFee =
        (actualFare != null && actualFare! > 0) ? 0 : (dist * ratePerKm * 0.10);

    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: _buildDrawer(context),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Text(
              'Trip Summary',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Summary',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Distance Traveled', '${widget.tripDetails?['distance'] ?? dist} km'),
                _buildSummaryRow('Time Taken in Hrs', widget.tripDetails?['time'] ?? '10.7900'),
                _buildSummaryRow('Tariff Type', widget.tripDetails?['tariffType'] ?? 'MUV-Innova'),
                const SizedBox(height: 8),
                _buildSummaryRow('Total Actual Fare(Inclusive of Taxes)', '₹ ${widget.tripDetails?['actualFare'] ?? '7353'}'),
                _buildSummaryRow('Waiting Charges(Rs)', '₹ ${widget.tripDetails?['waitingCharges'] ?? '225'}'),
                _buildSummaryRow('Inter State Permit(Rs)', '₹ ${widget.tripDetails?['interStatePermit'] ?? '0'}'),
                _buildSummaryRow('Driver Allowance(Rs)', '₹ ${widget.tripDetails?['driverAllowance'] ?? '400'}'),
                _buildSummaryRow('Luggage Cost(Rs)', '₹ ${widget.tripDetails?['luggageCost'] ?? '300'}'),
                _buildSummaryRow('Pet Cost(Rs)', '₹ ${widget.tripDetails?['petCost'] ?? '0'}'),
                _buildSummaryRow('Toll charge(Rs)', '₹ ${widget.tripDetails?['tollCharge'] ?? '430.00'}'),
                _buildSummaryRow('Night Allowance(Rs)', '₹ ${widget.tripDetails?['nightAllowance'] ?? '200'}'),
                const SizedBox(height: 12),
                const Divider(thickness: 1, color: Colors.grey),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Cost(Rs)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      '₹ ${_calculateTotalCost()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripDetailsInputScreen(
                            tripData: widget.tripData,
                            startingKm: widget.startingKm,
                            endingKm: widget.endingKm,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Back to Calculate',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.greenPrimary, AppColors.greenDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showCloseTripDialog(context, _calculateTotalCost()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Close Trip',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
    );
  }

  double _calculateTotalCost() {
    if (widget.tripDetails != null) {
      // Only show the actual fare as total cost - don't add other charges
      final actualFare = double.tryParse(widget.tripDetails!['actualFare'] ?? '0') ?? 0;
      return actualFare;
    }
    return 8908.0; // Default total
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey.shade300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chola_cabs_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade400,
                  child: const Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tom Holland',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDrawerMenuItem(context, Icons.person_outline, 'Profile',
                      'View and edit your personal details'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(
                      context,
                      Icons.settings_outlined,
                      'Settings',
                      'App preferences, notifications, and privacy'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.help_outline, 'Help',
                      'Get help and contact the admin for support'),
                  const SizedBox(height: 16),
                  _buildDrawerMenuItem(context, Icons.logout, 'Sign out',
                      'Log out of your account safely',
                      isSignOut: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem(
      BuildContext context, IconData icon, String title, String subtitle,
      {bool isSignOut = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (title == 'Profile') {
            Navigator.pushNamed(context, '/profile');
          } else if (title == 'Sign out') {
            Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false);
          }
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSignOut ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : Colors.grey.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSignOut ? Colors.red : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseTripDialog(BuildContext context, double totalCost) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                'Are you sure to close this trip?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Once you close this trip, you will not be able to modify any trip details. Please review the final amount before confirming.',
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Final Amount: ₹${totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade600, Colors.red.shade800],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.greenPrimary, AppColors.greenDark],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final tripId = widget.tripData['trip_id'];
                          if (tripId != null) {
                            try {
                              await ApiService.completeTripStatus(
                                  tripId.toString());
                            } catch (e) {
                              debugPrint(
                                  'Failed to mark trip as completed: $e');
                            }
                          }
                          Navigator.popUntil(
                              context, ModalRoute.withName('/dashboard'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Trip closed successfully!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close Trip',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
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
}
