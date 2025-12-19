import 'package:flutter/material.dart';
import 'kyc_upload_screen.dart';
import '../services/database_service.dart';

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
  final _fcExpiryController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _otherBrandController = TextEditingController();
  
  String? _selectedVehicleType;
  String? _selectedSeatingCapacity;
  String? _selectedVehicleBrand;
  String? _selectedVehicleYear;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF424242),
        title: const Text(
          'CHOLA CABS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8E8E8),
              Color(0xFF808080),
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
                          _buildTextField('License Number*', _licenseController),
                          const SizedBox(height: 16),
                          _buildTextField('Aadhaar Number*', _aadharController),
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
                          _buildDateField('Driving License Expiry Date*', _drivingLicenseExpiryController, true),
                          const SizedBox(height: 16),
                          _buildDateField('FC Expiry Date*', _fcExpiryController, true),
                          const SizedBox(height: 16),
                          _buildDropdownField('Vehicle Type*', _selectedVehicleType, ['sedan', 'suv', 'innova'], (value) {
                            setState(() {
                              _selectedVehicleType = value;
                            });
                          }),
                          const SizedBox(height: 16),
                          _buildTextField('Vehicle Number*', _vehicleNumberController),
                          const SizedBox(height: 16),
                          _buildVehicleBrandDropdown(),
                          const SizedBox(height: 16),
                          _buildDropdownField('Vehicle Year*', _selectedVehicleYear, List.generate(25, (index) => (DateTime.now().year - index).toString()), (value) {
                            setState(() {
                              _selectedVehicleYear = value;
                            });
                          }),
                          const SizedBox(height: 16),
                          _buildTextField('Vehicle Color*', _vehicleColorController),
                          const SizedBox(height: 16),
                          _buildDropdownField('Number of Seats', _selectedSeatingCapacity, ['2', '4', '6', '8'], (value) {
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
                          // Check all required fields
                          if (!_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields correctly')),
                            );
                            return;
                          }
                          
                          if (_selectedVehicleType == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select vehicle type')),
                            );
                            return;
                          }
                          
                          if (_selectedVehicleBrand == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select vehicle brand')),
                            );
                            return;
                          }
                          
                          if (_selectedVehicleYear == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select vehicle year')),
                            );
                            return;
                          }
                          
                          final phoneNumber = ModalRoute.of(context)?.settings.arguments as String?;
                          if (phoneNumber == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Phone number not found')),
                            );
                            return;
                          }
                          
                          try {
                            final dbService = DatabaseService();
                            final success = await dbService.createDriver(
                              phone: phoneNumber,
                              name: _nameController.text.trim(),
                              email: _emailController.text.trim(),
                              licenseNumber: _licenseController.text.trim(),
                              aadhaarNumber: _aadharController.text.trim(),
                              vehicleType: _selectedVehicleType!,
                              vehicleNumber: _vehicleNumberController.text.trim(),
                              vehicleBrand: _selectedVehicleBrand == 'Other' ? _otherBrandController.text.trim() : _selectedVehicleBrand!,
                              vehicleColor: _vehicleColorController.text.trim(),
                              vehicleYear: int.parse(_selectedVehicleYear!),
                              numberOfSeats: int.parse(_selectedSeatingCapacity ?? '4'),
                            );
                            
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Registration successful!')),
                              );
                              Navigator.pushReplacementNamed(context, '/dashboard');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to save details. Please try again.')),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
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
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            if (label.contains('Email') && value.isNotEmpty) {
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Enter a valid email';
              }
            }
            if (label.contains('Aashaar') && value.length != 12) {
              return 'Aadhar number must be 12 digits';
            }
            return null;
          } : null,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, [bool isRequired = false]) {
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
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          } : null,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildDropdownField(String label, String? value, List<String> items, Function(String?) onChanged) {
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Widget _buildVehicleBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDropdownField('Vehicle Brand*', _selectedVehicleBrand, [
          'Tata Motors',
          'Mahindra & Mahindra',
          'Maruti Suzuki',
          'Hyundai',
          'Toyota',
          'Honda',
          'Kia',
          'Other'
        ], (value) {
          setState(() {
            _selectedVehicleBrand = value;
          });
        }),
        if (_selectedVehicleBrand == 'Other')
          const SizedBox(height: 16),
        if (_selectedVehicleBrand == 'Other')
          _buildTextField('Other Brand*', _otherBrandController),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _aadharController.dispose();
    _drivingLicenseExpiryController.dispose();
    _fcExpiryController.dispose();
    _vehicleNumberController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }
}