import 'package:flutter/material.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/bottom_navigation.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import 'trip_start_screen.dart';

class TripDetailsInputScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String startingKm;
  final String endingKm;

  const TripDetailsInputScreen({
    super.key,
    required this.tripData,
    required this.startingKm,
    required this.endingKm,
  });

  @override
  State<TripDetailsInputScreen> createState() => _TripDetailsInputScreenState();
}

class _TripDetailsInputScreenState extends State<TripDetailsInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _distanceController;
  final _timeController = TextEditingController();
  final _tariffController = TextEditingController(text: 'MUV-Innova');
  final _actualFareController = TextEditingController();
  final _waitingChargesController = TextEditingController();
  final _interStatePermitController = TextEditingController();
  final _driverAllowanceController = TextEditingController();
  final _luggageCostController = TextEditingController();
  final _petCostController = TextEditingController();
  final _tollChargeController = TextEditingController();
  final _nightAllowanceController = TextEditingController();
  bool _isLoadingFare = true;

  @override
  void initState() {
    super.initState();
    // Calculate distance from starting and ending KM
    final startKm = double.tryParse(widget.startingKm) ?? 0;
    final endKm = double.tryParse(widget.endingKm) ?? 0;
    final distance = (endKm - startKm).abs();
    _distanceController = TextEditingController(text: distance.toString());
    _fetchTripFare();
  }

  Future<void> _fetchTripFare() async {
    final tripId = widget.tripData['trip_id']?.toString() ?? widget.tripData['id']?.toString();
    if (tripId == null || tripId.isEmpty) {
      setState(() => _isLoadingFare = false);
      return;
    }

    try {
      final tripDetails = await ApiService.getTripDetails(tripId);
      final fare = tripDetails['fare']?.toString() ?? tripDetails['total_fare']?.toString() ?? '';
      if (fare.isNotEmpty && mounted) {
        setState(() {
          _actualFareController.text = fare;
          _isLoadingFare = false;
        });
      } else {
        setState(() => _isLoadingFare = false);
      }
    } catch (e) {
      setState(() => _isLoadingFare = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Trip Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField('Distance Traveled (km)', _distanceController),
                      _buildInputField('Time Taken in Hrs', _timeController),
                      _buildInputField('Tariff Type', _tariffController),
                      _buildInputField('Total Actual Fare (₹)', _actualFareController),
                      _buildInputField('Waiting Charges (₹)', _waitingChargesController),
                      _buildInputField('Inter State Permit (₹)', _interStatePermitController),
                      _buildInputField('Driver Allowance (₹)', _driverAllowanceController),
                      _buildInputField('Luggage Cost (₹)', _luggageCostController),
                      _buildInputField('Pet Cost (₹)', _petCostController),
                      _buildInputField('Toll Charge (₹)', _tollChargeController),
                      _buildInputField('Night Allowance (₹)', _nightAllowanceController),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    onPressed: _onCalculatePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Calculate Total',
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
              ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    final isActualFare = label.contains('Actual Fare');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
              suffixIcon: isActualFare && _isLoadingFare
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              // Only distance and actual fare are required
              if (label.contains('Distance') || label.contains('Actual Fare')) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  void _onCalculatePressed() async {
    if (_formKey.currentState!.validate()) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final tripId = widget.tripData['trip_id']?.toString() ?? widget.tripData['id']?.toString();
        final endingKm = num.tryParse(widget.endingKm);
        
        if (tripId != null && endingKm != null) {
          await ApiService.updateOdometerEnd(tripId, endingKm);
        }
        
        if (mounted) Navigator.pop(context);
        
        final tripDetailsMap = {
          'distance': _distanceController.text,
          'time': _timeController.text.isEmpty ? '0' : _timeController.text,
          'tariffType': _tariffController.text,
          'actualFare': _actualFareController.text,
          'waitingCharges': _waitingChargesController.text.isEmpty ? '0' : _waitingChargesController.text,
          'interStatePermit': _interStatePermitController.text.isEmpty ? '0' : _interStatePermitController.text,
          'driverAllowance': _driverAllowanceController.text.isEmpty ? '0' : _driverAllowanceController.text,
          'luggageCost': _luggageCostController.text.isEmpty ? '0' : _luggageCostController.text,
          'petCost': _petCostController.text.isEmpty ? '0' : _petCostController.text,
          'tollCharge': _tollChargeController.text.isEmpty ? '0' : _tollChargeController.text,
          'nightAllowance': _nightAllowanceController.text.isEmpty ? '0' : _nightAllowanceController.text,
        };

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TripSummaryScreen(
                tripData: widget.tripData,
                startingKm: widget.startingKm,
                endingKm: widget.endingKm,
                tripDetails: tripDetailsMap,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _timeController.dispose();
    _tariffController.dispose();
    _actualFareController.dispose();
    _waitingChargesController.dispose();
    _interStatePermitController.dispose();
    _driverAllowanceController.dispose();
    _luggageCostController.dispose();
    _petCostController.dispose();
    _tollChargeController.dispose();
    _nightAllowanceController.dispose();
    super.dispose();
  }
}