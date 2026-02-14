import 'package:flutter/material.dart';
import 'dart:io';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/trip_drawer.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/bottom_navigation.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/image_picker_service.dart';
import 'trip_details_input_screen.dart';

class TripStartScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;

  const TripStartScreen({super.key, required this.tripData});

  @override
  State<TripStartScreen> createState() => _TripStartScreenState();
}

class _TripStartScreenState extends State<TripStartScreen> {
  final TextEditingController _startingKmController = TextEditingController();
  File? _odometerImage;

  Widget _buildOdometerUpload() {
    return GestureDetector(
      onTap: () async {
        final image = await ImagePickerService.showImageSourceDialog(context);
        if (image != null) {
          setState(() => _odometerImage = image);
        }
      },
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _odometerImage != null ? AppColors.greenLight : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: _odometerImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _odometerImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _odometerImage = null),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload odometer photo',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
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
                const SizedBox(height: 20),
                const Text('Odometer Photo *',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                _buildOdometerUpload(),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                        if (_startingKmController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter starting KM')),
                          );
                          return;
                        }
                        if (_odometerImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please upload odometer photo')),
                          );
                          return;
                        }

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

                            await ApiService.uploadOdometerStart(
                                tripId.toString(), _odometerImage!);

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
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
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
  File? _odometerImage;

  Widget _buildOdometerUpload() {
    return GestureDetector(
      onTap: () async {
        final image = await ImagePickerService.showImageSourceDialog(context);
        if (image != null) {
          setState(() => _odometerImage = image);
        }
      },
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _odometerImage != null ? AppColors.greenLight : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: _odometerImage != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _odometerImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _odometerImage = null),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to upload odometer photo',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      endDrawer: AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
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
                const SizedBox(height: 20),
                const Text('Odometer Photo *',
                    style: TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                _buildOdometerUpload(),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                        if (_endingKmController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter ending KM')),
                          );
                          return;
                        }
                        if (_odometerImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please upload odometer photo')),
                          );
                          return;
                        }

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
                              await ApiService.updateOdometerEnd(
                                  tripId.toString(), endingKm);

                              await ApiService.uploadOdometerEnd(
                                  tripId.toString(), _odometerImage!);

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
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
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
  final Map<String, String>? previousInputs;

  const TripSummaryScreen({
    super.key,
    required this.tripData,
    required this.startingKm,
    required this.endingKm,
    this.tripDetails,
    this.distance,
    this.fare,
    this.previousInputs,
  });

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  num? fare;
  num? totalAmount;
  bool isLoading = true;
  Map<String, dynamic>? tripDetails;

  @override
  void initState() {
    super.initState();
    debugPrint('\n========== TRIP SUMMARY INIT ==========');
    debugPrint('tripDetails provided: ${widget.tripDetails != null}');
    if (widget.tripDetails != null) {
      debugPrint('Using provided tripDetails');
      debugPrint('Data: ${widget.tripDetails}');
    }
    debugPrint('=======================================\n');
    _fetchTripData();
  }

  Future<void> _fetchTripData() async {
    final tripId = widget.tripData['trip_id'];
    
    debugPrint('\n========== FETCH TRIP DATA ==========');
    debugPrint('Trip ID: $tripId');
    debugPrint('widget.tripDetails: ${widget.tripDetails}');
    debugPrint('widget.tripData: ${widget.tripData}');
    
    if (tripId == null) {
      debugPrint('No trip_id, using fallback');
      setState(() {
        fare = widget.fare ?? 0;
        totalAmount = widget.fare ?? 0;
        isLoading = false;
      });
      return;
    }

    if (widget.tripDetails != null) {
      debugPrint('Using provided tripDetails (skipping API call)');
      debugPrint('Full tripDetails: ${widget.tripDetails}');
      setState(() {
        tripDetails = widget.tripDetails;
        fare = tripDetails?['fare'] ?? 0;
        totalAmount = tripDetails?['total_amount'] ?? 0;
        isLoading = false;
      });
      debugPrint('Fare: $fare, Total: $totalAmount');
      debugPrint('Waiting Charges: ${tripDetails?['waiting_charges']}');
      debugPrint('Toll Charges: ${tripDetails?['toll_charges']}');
      debugPrint('=====================================\n');
      return;
    }

    try {
      debugPrint('Calling API: getTripDetails($tripId)');
      final details = await ApiService.getTripDetails(tripId.toString());
      debugPrint('API Response: $details');
      setState(() {
        tripDetails = details;
        fare = details['fare'] ?? 0;
        totalAmount = details['total_amount'] ?? 0;
        isLoading = false;
      });
      debugPrint('Fare: $fare, Total: $totalAmount');
    } catch (e) {
      debugPrint('API Error: $e');
      setState(() {
        fare = widget.fare ?? 0;
        totalAmount = widget.fare ?? 0;
        isLoading = false;
      });
    }
    debugPrint('=====================================\n');
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

    return WillPopScope(
      onWillPop: () async {
        _showCloseTripDialog(context, _calculateTotalCost());
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB0B0B0),
        appBar: const CustomAppBar(),
        endDrawer: TripDrawer(blockNavigation: true, onMenuItemTap: () => _showCloseTripDialog(context, _calculateTotalCost())),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
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
                        _buildSummaryRow('Distance Traveled', '${tripDetails?['distance_km'] ?? dist} km'),
                        _buildSummaryRow('Tariff Type', tripDetails?['vehicle_type'] ?? widget.tripData['vehicle_type'] ?? 'MUV-Innova'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Total Actual Fare(Inclusive of Taxes)', '₹ ${(tripDetails?['fare'] ?? 0).toStringAsFixed(2)}'),
                        _buildSummaryRow('Waiting Charges(Rs)', '₹ ${_getChargeValue('waiting_charges', 'waitingCharges')}'),
                        _buildSummaryRow('Inter State Permit(Rs)', '₹ ${_getChargeValue('inter_state_permit_charges', 'interStatePermit')}'),
                        _buildSummaryRow('Driver Allowance(Rs)', '₹ ${_getChargeValue('driver_allowance', 'driverAllowance')}'),
                        _buildSummaryRow('Luggage Cost(Rs)', '₹ ${_getChargeValue('luggage_cost', 'luggageCost')}'),
                        _buildSummaryRow('Pet Cost(Rs)', '₹ ${_getChargeValue('pet_cost', 'petCost')}'),
                        _buildSummaryRow('Toll charge(Rs)', '₹ ${_getChargeValue('toll_charges', 'tollCharge')}'),
                        _buildSummaryRow('Night Allowance(Rs)', '₹ ${_getChargeValue('night_allowance', 'nightAllowance')}'),
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
                  const SizedBox(height: 24),
                ],
              ),
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
                            previousInputs: widget.previousInputs,
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
      bottomNavigationBar: BottomNavigation(
        currentRoute: '/dashboard',
        onTap: (route) => _showCloseTripDialog(context, _calculateTotalCost()),
      ),
      ),
    );
  }

  double _calculateTotalCost() {
    debugPrint('\n========== CALCULATE TOTAL ==========');
    debugPrint('tripDetails: $tripDetails');
    
    final backendTotal = (tripDetails?['total_amount'] ?? 0).toDouble();
    final fare = (tripDetails?['fare'] ?? 0).toDouble();
    
    final calculatedTotal = (
      (tripDetails?['fare'] ?? 0) +
      _getChargeNumValue('waiting_charges', 'waitingCharges') +
      _getChargeNumValue('inter_state_permit_charges', 'interStatePermit') +
      _getChargeNumValue('driver_allowance', 'driverAllowance') +
      _getChargeNumValue('luggage_cost', 'luggageCost') +
      _getChargeNumValue('pet_cost', 'petCost') +
      _getChargeNumValue('toll_charges', 'tollCharge') +
      _getChargeNumValue('night_allowance', 'nightAllowance')
    ).toDouble();
    
    debugPrint('Backend total_amount: $backendTotal');
    debugPrint('Fare: $fare');
    debugPrint('Calculated total: $calculatedTotal');
    
    if (backendTotal == fare && calculatedTotal > fare) {
      debugPrint('Using calculated total (backend bug)');
      debugPrint('=====================================\n');
      return calculatedTotal;
    }
    
    debugPrint('Using backend total');
    debugPrint('=====================================\n');
    return backendTotal > 0 ? backendTotal : calculatedTotal;
  }

  String _getChargeValue(String apiKey, String inputKey) {
    final apiValue = tripDetails?[apiKey];
    if (apiValue != null && apiValue != 0) {
      return apiValue.toStringAsFixed(2);
    }
    final inputValue = widget.previousInputs?[inputKey];
    if (inputValue != null && inputValue.isNotEmpty) {
      return (num.tryParse(inputValue) ?? 0).toStringAsFixed(2);
    }
    return '0.00';
  }

  num _getChargeNumValue(String apiKey, String inputKey) {
    final apiValue = tripDetails?[apiKey];
    if (apiValue != null && apiValue != 0) {
      return apiValue;
    }
    final inputValue = widget.previousInputs?[inputKey];
    if (inputValue != null && inputValue.isNotEmpty) {
      return num.tryParse(inputValue) ?? 0;
    }
    return 0;
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