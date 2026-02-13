import 'package:flutter/material.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/bottom_navigation.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/common/trip_drawer.dart';
import 'trip_start_screen.dart';

class TripDetailsInputScreen extends StatefulWidget {
  final Map<String, dynamic> tripData;
  final String startingKm;
  final String endingKm;
  final Map<String, String>? previousInputs;

  const TripDetailsInputScreen({
    super.key,
    required this.tripData,
    required this.startingKm,
    required this.endingKm,
    this.previousInputs,
  });

  @override
  State<TripDetailsInputScreen> createState() => _TripDetailsInputScreenState();
}

class _TripDetailsInputScreenState extends State<TripDetailsInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _distanceController;
  final _tariffController = TextEditingController();
  final _waitingChargesController = TextEditingController();
  final _interStatePermitController = TextEditingController();
  final _driverAllowanceController = TextEditingController();
  final _luggageCostController = TextEditingController();
  final _petCostController = TextEditingController();
  final _tollChargeController = TextEditingController();
  final _nightAllowanceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    debugPrint('TripDetailsInputScreen - tripData: ${widget.tripData}');
    
    // Calculate distance from starting and ending KM
    final startKm = double.tryParse(widget.startingKm) ?? 0;
    final endKm = double.tryParse(widget.endingKm) ?? 0;
    final distance = (endKm - startKm).abs();
    _distanceController = TextEditingController(text: widget.previousInputs?['distance'] ?? distance.toString());
    
    // Set vehicle type from trip data - check multiple possible locations
    final vehicleType = widget.tripData['vehicle_type'] ?? 
                       widget.tripData['trip']?['vehicle_type'] ?? 
                       widget.tripData['type'] ?? '';
    debugPrint('Vehicle type found: $vehicleType');
    
    _tariffController.text = widget.previousInputs?['tariff'] ?? vehicleType;
    
    // Restore previous inputs if available
    _waitingChargesController.text = widget.previousInputs?['waitingCharges'] ?? '';
    _interStatePermitController.text = widget.previousInputs?['interStatePermit'] ?? '';
    _driverAllowanceController.text = widget.previousInputs?['driverAllowance'] ?? '';
    _luggageCostController.text = widget.previousInputs?['luggageCost'] ?? '';
    _petCostController.text = widget.previousInputs?['petCost'] ?? '';
    _tollChargeController.text = widget.previousInputs?['tollCharge'] ?? '';
    _nightAllowanceController.text = widget.previousInputs?['nightAllowance'] ?? '';
  }

  void _showCloseTripDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Trip First'),
        content: const Text('Please complete and close the current trip before navigating away.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
// ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        _showCloseTripDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB0B0B0),
        appBar: const CustomAppBar(),
        endDrawer: TripDrawer(onMenuItemTap: (_) => _showCloseTripDialog()),
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
                      _buildInputField('Tariff Type', _tariffController),
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
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
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
            ),
            validator: (value) {
              if (label.contains('Distance')) {
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
        
        Map<String, dynamic>? updatedTripData;
        
        if (tripId != null && endingKm != null) {
          updatedTripData = await ApiService.updateOdometerEnd(
            tripId,
            endingKm,
            waitingCharges: _waitingChargesController.text.isEmpty ? 0 : num.tryParse(_waitingChargesController.text),
            interStatePermitCharges: _interStatePermitController.text.isEmpty ? 0 : num.tryParse(_interStatePermitController.text),
            driverAllowance: _driverAllowanceController.text.isEmpty ? 0 : num.tryParse(_driverAllowanceController.text),
            luggageCost: _luggageCostController.text.isEmpty ? 0 : num.tryParse(_luggageCostController.text),
            petCost: _petCostController.text.isEmpty ? 0 : num.tryParse(_petCostController.text),
            tollCharges: _tollChargeController.text.isEmpty ? 0 : num.tryParse(_tollChargeController.text),
            nightAllowance: _nightAllowanceController.text.isEmpty ? 0 : num.tryParse(_nightAllowanceController.text),
          );
        }
        
        if (mounted) Navigator.pop(context);
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TripSummaryScreen(
                tripData: widget.tripData,
                startingKm: widget.startingKm,
                endingKm: widget.endingKm,
                tripDetails: updatedTripData,
                previousInputs: {
                  'distance': _distanceController.text,
                  'tariff': _tariffController.text,
                  'waitingCharges': _waitingChargesController.text,
                  'interStatePermit': _interStatePermitController.text,
                  'driverAllowance': _driverAllowanceController.text,
                  'luggageCost': _luggageCostController.text,
                  'petCost': _petCostController.text,
                  'tollCharge': _tollChargeController.text,
                  'nightAllowance': _nightAllowanceController.text,
                },
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
    _tariffController.dispose();
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