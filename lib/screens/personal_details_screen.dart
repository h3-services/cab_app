import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final _aadharController = TextEditingController();
  final _drivingLicenseExpiryController = TextEditingController();
  final _primaryLocationController = TextEditingController();
  final _fcExpiryController = TextEditingController();
  final _rcExpiryController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();

  String? _selectedVehicleType;
  String? _selectedSeatingCapacity;
  String? phoneNumber;
  String? _testDeviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    phoneNumber = ModalRoute.of(context)!.settings.arguments as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: false,
        showMenuIcon: false,
        actions: [
          TextButton(
            onPressed: _fillSampleData,
            child: const Text(
              'Test Data',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.appGradientStart,
              AppColors.appGradientEnd,
            ],
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Personal Information Card
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField('Name*', _nameController),
                            const SizedBox(height: 16),
                            _buildTextField('Email', _emailController),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'License Number*', _licenseController),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'Aadhaar Number*', _aadharController),
                            const SizedBox(height: 16),
                            _buildTextField('Primary Location*',
                                _primaryLocationController),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Vehicle Details Card
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vehicle Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDateField('Driving License Expiry Date*',
                                _drivingLicenseExpiryController, true),
                            const SizedBox(height: 16),
                            _buildDateField(
                                'FC Expiry Date*', _fcExpiryController, true),
                            const SizedBox(height: 16),
                            _buildDateField(
                                'RC Expiry Date*', _rcExpiryController, true),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                                'Vehicle Type*',
                                _selectedVehicleType,
                                ['SUV', 'Innova', 'Sedan'], (value) {
                              setState(() {
                                _selectedVehicleType = value;
                              });
                            }),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'Vehicle Number*', _vehicleNumberController),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'Vehicle Make*', _vehicleMakeController),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'Vehicle model*', _vehicleModelController),
                            const SizedBox(height: 16),
                            _buildTextField(
                                'Vehicle Color*', _vehicleColorController),
                            const SizedBox(height: 16),
                            _buildDropdownField(
                                'Seating Capacity',
                                _selectedSeatingCapacity,
                                ['2', '4', '6', '8'], (value) {
                              setState(() {
                                _selectedSeatingCapacity = value;
                              });
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Save & Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate() &&
                                _selectedVehicleType != null &&
                                _drivingLicenseExpiryController
                                    .text.isNotEmpty &&
                                _fcExpiryController.text.isNotEmpty &&
                                _rcExpiryController.text.isNotEmpty &&
                                _primaryLocationController.text.isNotEmpty) {
                              // Show loading
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                    child: CircularProgressIndicator()),
                              );

                              try {
                                String licenseDate = _formatDateForApi(
                                    _drivingLicenseExpiryController.text);
                                String fcDate =
                                    _formatDateForApi(_fcExpiryController.text);
                                String rcDate =
                                    _formatDateForApi(_rcExpiryController.text);

                                // Get Device ID
                                String deviceId = _testDeviceId ??
                                    await DeviceService.getDeviceId();

                                // 1. Register Driver
                                final driverResponse =
                                    await ApiService.registerDriver(
                                  name: _nameController.text,
                                  phoneNumber: phoneNumber ?? '',
                                  email: _emailController.text,
                                  primaryLocation:
                                      _primaryLocationController.text,
                                  licenceNumber: _licenseController.text,
                                  aadharNumber: _aadharController.text,
                                  licenceExpiry: licenseDate,
                                  deviceId: deviceId,
                                );

                                // Extract driver_id from response
                                // Assuming response structure has 'id' or 'driver_id'
                                final String driverId = driverResponse['id']
                                        ?.toString() ??
                                    driverResponse['driver_id']?.toString() ??
                                    '';

                                if (driverId.isEmpty) {
                                  throw Exception(
                                      'Driver ID not found in response');
                                }

                                // 2. Register Vehicle
                                final vehicleResponse =
                                    await ApiService.registerVehicle(
                                  vehicleType: _selectedVehicleType!,
                                  vehicleBrand: _vehicleMakeController.text,
                                  vehicleModel: _vehicleModelController.text,
                                  vehicleNumber: _vehicleNumberController.text,
                                  vehicleColor: _vehicleColorController.text,
                                  seatingCapacity: int.tryParse(
                                          _selectedSeatingCapacity ?? '4') ??
                                      4,
                                  driverId: driverId,
                                  rcExpiryDate: _formatDateForApi(
                                      _rcExpiryController.text),
                                  fcExpiryDate: _formatDateForApi(
                                      _fcExpiryController.text),
                                );

                                final String vehicleId = vehicleResponse['id']
                                        ?.toString() ??
                                    vehicleResponse['vehicle_id']?.toString() ??
                                    '';

                                // Save IDs to SharedPreferences for Dashboard use
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString('driverId', driverId);
                                await prefs.setString('vehicleId', vehicleId);

                                // Hide loading
                                if (context.mounted) Navigator.pop(context);

                                if (!context.mounted) return;

                                // Proceed to next screen
                                Map<String, dynamic> userData = {
                                  'phoneNumber': phoneNumber,
                                  'name': _nameController.text,
                                  'email': _emailController.text,
                                  'licenseNumber': _licenseController.text,
                                  'aadhaarNumber': _aadharController.text,
                                  'primaryLocation':
                                      _primaryLocationController.text,
                                  'vehicleType': _selectedVehicleType,
                                  'vehicleNumber':
                                      _vehicleNumberController.text,
                                  'vehicleBrand': _vehicleMakeController.text,
                                  'vehicleModel': _vehicleModelController.text,
                                  'vehicleColor': _vehicleColorController.text,
                                  'numberOfSeats': int.tryParse(
                                          _selectedSeatingCapacity ?? '4') ??
                                      4,
                                  'driverId': driverId,
                                  'vehicleId': vehicleId, // Added vehicleId
                                };

                                Navigator.pushNamed(
                                  context,
                                  '/kyc_upload',
                                  arguments: userData,
                                );
                              } catch (e) {
                                // Hide loading
                                if (context.mounted) Navigator.pop(context);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Registration failed: ${e.toString().replaceAll("Exception:", "")}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please fill all required fields')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.greenLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save & Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fillSampleData() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix = random.substring(random.length - 6);

    setState(() {
      _testDeviceId = "test_device_$randomSuffix";

      // Set the phone number that is required for the API
      phoneNumber = "9823$randomSuffix";

      _nameController.text = "Driver $randomSuffix";
      _emailController.text = "driver$randomSuffix@test.com";
      _licenseController.text = "DL$randomSuffix";

      // Ensure 12 digits for Aadhaar
      _aadharController.text = "123456$randomSuffix";

      _primaryLocationController.text = "Chennai, India";

      _drivingLicenseExpiryController.text = "19/01/2030";
      _fcExpiryController.text = "19/01/2030";
      _rcExpiryController.text = "19/01/2030";

      _selectedVehicleType = "Sedan";

      _vehicleNumberController.text = "TN01$randomSuffix";
      _vehicleMakeController.text = "Toyota";
      _vehicleModelController.text = "Etios";
      _vehicleColorController.text = "White";

      _selectedSeatingCapacity = "4";
    });
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    bool isRequired = label.contains('*');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label.replaceAll('*', ''),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  if (label.contains('Email') && value.isNotEmpty) {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                  }
                  if (label.contains('Aadhaar') && value.length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller,
      [bool isRequired = false]) {
    bool hasAsterisk = label.contains('*');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label.replaceAll('*', ''),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (hasAsterisk)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              controller.text = '${date.day}/${date.month}/${date.year}';
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    bool isRequired = label.contains('*');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label.replaceAll('*', ''),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.black),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _formatDateForApi(String dateText) {
    try {
      final dateParts = dateText.split('/');
      if (dateParts.length == 3) {
        // Assuming input is DD/MM/YYYY
        final day = dateParts[0].padLeft(2, '0');
        final month = dateParts[1].padLeft(2, '0');
        final year = dateParts[2];
        return '$year-$month-$day';
      }
    } catch (_) {}
    return DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _aadharController.dispose();
    _drivingLicenseExpiryController.dispose();
    _fcExpiryController.dispose();
    _rcExpiryController.dispose();
    _vehicleNumberController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _primaryLocationController.dispose();
    super.dispose();
  }
}
