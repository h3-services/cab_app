import 'package:flutter/material.dart';
import '../widgets/common/custom_app_bar.dart';
import '../widgets/bottom_navigation.dart';
import '../constants/app_colors.dart';
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
  final _distanceController = TextEditingController(text: '387');
  final _timeController = TextEditingController(text: '10.7900');
  final _tariffController = TextEditingController(text: 'MUV-Innova');
  final _actualFareController = TextEditingController(text: '7353');
  final _waitingChargesController = TextEditingController(text: '225');
  final _interStatePermitController = TextEditingController(text: '0');
  final _driverAllowanceController = TextEditingController(text: '400');
  final _luggageCostController = TextEditingController(text: '300');
  final _petCostController = TextEditingController(text: '0');
  final _tollChargeController = TextEditingController(text: '430.00');
  final _nightAllowanceController = TextEditingController(text: '200');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB0B0B0),
      appBar: const CustomAppBar(),
      body: Column(
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
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
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
            ),
          ),
          Padding(
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
      bottomNavigationBar: const BottomNavigation(currentRoute: '/dashboard'),
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
              if (value == null || value.isEmpty) {
                return 'This field is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  void _onCalculatePressed() {
    if (_formKey.currentState!.validate()) {
      final tripDetails = {
        'distance': _distanceController.text,
        'time': _timeController.text,
        'tariffType': _tariffController.text,
        'actualFare': _actualFareController.text,
        'waitingCharges': _waitingChargesController.text,
        'interStatePermit': _interStatePermitController.text,
        'driverAllowance': _driverAllowanceController.text,
        'luggageCost': _luggageCostController.text,
        'petCost': _petCostController.text,
        'tollCharge': _tollChargeController.text,
        'nightAllowance': _nightAllowanceController.text,
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripSummaryScreen(
            tripData: widget.tripData,
            startingKm: widget.startingKm,
            endingKm: widget.endingKm,
            tripDetails: tripDetails,
          ),
        ),
      );
    }
  }
}