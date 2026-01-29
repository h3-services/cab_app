import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '../constants/app_colors.dart';
import '../services/device_service.dart';
import '../services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  bool _isDataLoaded = false;
  List<String> _errorFields = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final args = ModalRoute.of(context)!.settings.arguments;
    debugPrint('DEBUG _loadData: args=$args');
    if (args is Map && args['isEditing'] == true) {
      debugPrint('DEBUG: Loading editing data');
      debugPrint('DEBUG: name=${args['name']}');
      _nameController.text = args['name'] ?? '';
      _emailController.text = args['email'] ?? '';
      _primaryLocationController.text = args['primaryLocation'] ?? '';
      _licenseController.text = args['licenceNumber'] ?? '';
      _aadharController.text = args['aadharNumber'] ?? '';
      _vehicleMakeController.text = args['vehicleBrand'] ?? '';
      _vehicleModelController.text = args['vehicleModel'] ?? '';
      _vehicleNumberController.text = args['vehicleNumber'] ?? '';
      _vehicleColorController.text = args['vehicleColor'] ?? '';
      _selectedVehicleType = args['vehicleType'];
      _selectedSeatingCapacity = args['seatingCapacity'];
      _drivingLicenseExpiryController.text = _formatDateForDisplay(args['licenceExpiry']);
      _rcExpiryController.text = _formatDateForDisplay(args['rcExpiryDate']);
      _fcExpiryController.text = _formatDateForDisplay(args['fcExpiryDate']);
      phoneNumber = args['phoneNumber'];
      if (args['errorFields'] != null) {
        _errorFields = List<String>.from(args['errorFields']);
      }
      debugPrint('DEBUG: After loading - name=${_nameController.text}');
      setState(() {});
    } else if (args is String) {
      phoneNumber = args;
    }
    _ensurePhoneNumber();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _ensurePhoneNumber() async {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('phoneNumber');
      if (stored != null && mounted) {
        setState(() {
          phoneNumber = stored;
        });
      }
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNumber = prefs.getString('phoneNumber');
      _nameController.text = prefs.getString('name') ?? '';
      _emailController.text = prefs.getString('email') ?? '';
      _primaryLocationController.text =
          prefs.getString('primaryLocation') ?? '';
      _licenseController.text = prefs.getString('licenseNumber') ?? '';
      _aadharController.text = prefs.getString('aadhaarNumber') ?? '';

      _vehicleMakeController.text = prefs.getString('vehicleBrand') ?? '';
      _vehicleModelController.text = prefs.getString('vehicleModel') ?? '';
      _vehicleNumberController.text = prefs.getString('vehicleNumber') ?? '';
      _vehicleColorController.text = prefs.getString('vehicleColor') ?? '';

      _selectedVehicleType = prefs.getString('vehicleType');
      _selectedSeatingCapacity = prefs.getString('seatingCapacity');

      _drivingLicenseExpiryController.text =
          _formatDateForDisplay(prefs.getString('licenceExpiry'));
      _rcExpiryController.text =
          _formatDateForDisplay(prefs.getString('rcExpiryDate'));
      _fcExpiryController.text =
          _formatDateForDisplay(prefs.getString('fcExpiryDate'));
    });
  }

  String _formatDateForDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return dateStr; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showBackButton: true,
        showMenuIcon: false,
        showProfileIcon: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadSavedData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Reloaded saved data'),
                    duration: Duration(seconds: 1)),
              );
            },
          ),
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
                                String rcDate =
                                    _formatDateForApi(_rcExpiryController.text);
                                String fcDate =
                                    _formatDateForApi(_fcExpiryController.text);
                                // 1. PREPARE IDENTIFIERS
                                final realDeviceId =
                                    await DeviceService.getDeviceId();
                                String? fcmToken;
                                try {
                                  fcmToken = await FirebaseMessaging.instance
                                      .getToken();
                                } catch (e) {
                                  debugPrint("Note: Token fetch error: $e");
                                }

                                // VISIBLE TERMINAL BLOCK
                                debugPrint(
                                    "\n##########################################");
                                debugPrint(
                                    "PERSONAL DETAILS - STORING TO BACKEND:");
                                debugPrint("HARDWARE DEVICE ID: $realDeviceId");
                                debugPrint("FCM TOKEN: ${fcmToken ?? 'NULL'}");
                                debugPrint(
                                    "##########################################\n");

                                // 2. PREPARE IDs
                                final prefs =
                                    await SharedPreferences.getInstance();
                                String? driverId = prefs.getString('driverId');
                                String? vehicleId =
                                    prefs.getString('vehicleId');
                                final args =
                                    ModalRoute.of(context)!.settings.arguments;
                                bool isEditing =
                                    (args is Map && args['isEditing'] == true);

                                // 3. PERFORM STORAGE (Register or Update)
                                if (!isEditing &&
                                    (driverId == null || driverId.isEmpty)) {
                                  debugPrint("Performing new Registration...");

                                  // Register Driver
                                  final driverRes =
                                      await ApiService.registerDriver(
                                    name: _nameController.text,
                                    phoneNumber: phoneNumber ?? '',
                                    email: _emailController.text,
                                    primaryLocation:
                                        _primaryLocationController.text,
                                    licenceNumber: _licenseController.text,
                                    aadharNumber: _aadharController.text,
                                    licenceExpiry: licenseDate,
                                    deviceId: realDeviceId,
                                  );

                                  driverId = driverRes['id']?.toString() ??
                                      driverRes['driver_id']?.toString();

                                  if (driverId != null) {
                                    await prefs.setString('driverId', driverId);

                                    // 4. EXPLICITLY STORE FCM TOKEN IN DEDICATED CALL
                                    // (Device ID is already stored in Step 3 above via registerDriver)
                                    if (fcmToken != null) {
                                      debugPrint(
                                          "Storing FCM Token to dedicated endpoint...");
                                      await ApiService.addFcmToken(
                                          driverId, fcmToken);
                                    }

                                    // 5. Register Vehicle
                                    final vehicleRes =
                                        await ApiService.registerVehicle(
                                      vehicleType: _selectedVehicleType!,
                                      vehicleBrand: _vehicleMakeController.text,
                                      vehicleModel:
                                          _vehicleModelController.text,
                                      vehicleNumber:
                                          _vehicleNumberController.text,
                                      vehicleColor:
                                          _vehicleColorController.text,
                                      seatingCapacity: int.tryParse(
                                              _selectedSeatingCapacity ??
                                                  '4') ??
                                          4,
                                      driverId: driverId,
                                      rcExpiryDate: rcDate,
                                      fcExpiryDate: fcDate,
                                    );

                                    vehicleId = vehicleRes['id']?.toString() ??
                                        vehicleRes['vehicle_id']?.toString();

                                    if (vehicleId != null) {
                                      await prefs.setString(
                                          'vehicleId', vehicleId);
                                    }
                                  }
                                } else if (isEditing &&
                                    driverId != null &&
                                    vehicleId != null) {
                                  debugPrint("Updating existing details...");

                                  await ApiService.updateDriver(
                                    driverId: driverId,
                                    name: _nameController.text,
                                    email: _emailController.text,
                                    primaryLocation:
                                        _primaryLocationController.text,
                                    licenceNumber: _licenseController.text,
                                    aadharNumber: _aadharController.text,
                                    licenceExpiry: licenseDate,
                                  );

                                  await ApiService.updateVehicle(
                                    vehicleId: vehicleId,
                                    vehicleType: _selectedVehicleType!,
                                    vehicleBrand: _vehicleMakeController.text,
                                    vehicleModel: _vehicleModelController.text,
                                    vehicleColor: _vehicleColorController.text,
                                    seatingCapacity: int.tryParse(
                                            _selectedSeatingCapacity ?? '4') ??
                                        4,
                                    rcExpiryDate: rcDate,
                                    fcExpiryDate: fcDate,
                                  );
                                }

                                Map<String, dynamic> userData = {
                                  'name': _nameController.text,
                                  'phoneNumber': phoneNumber ?? '',
                                  'email': _emailController.text,
                                  'primaryLocation':
                                      _primaryLocationController.text,
                                  'licenceNumber': _licenseController.text,
                                  'aadharNumber': _aadharController.text,
                                  'licenceExpiry': licenseDate,
                                  'deviceId': realDeviceId,
                                  'vehicleType': _selectedVehicleType,
                                  'vehicleBrand': _vehicleMakeController.text,
                                  'vehicleModel': _vehicleModelController.text,
                                  'vehicleNumber':
                                      _vehicleNumberController.text,
                                  'vehicleColor': _vehicleColorController.text,
                                  'seatingCapacity': int.tryParse(
                                          _selectedSeatingCapacity ?? '4') ??
                                      4,
                                  'rcExpiryDate': rcDate,
                                  'fcExpiryDate': fcDate,
                                  'driverId': driverId,
                                  'vehicleId': vehicleId,
                                  'isEditing': isEditing,
                                  'errorFields': (args is Map)
                                      ? args['errorFields']
                                      : null,
                                };

                                // Hide loading before navigating
                                if (context.mounted) {
                                  Navigator.pop(context);

                                  Navigator.pushNamed(
                                    context,
                                    '/kyc_upload',
                                    arguments: userData,
                                  );
                                }
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
      // Only set random phone if we don't have a verified one
      if (phoneNumber == null || phoneNumber!.isEmpty) {
        phoneNumber = "9823$randomSuffix";
      }

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
    String cleanLabel = label.replaceAll('*', '').trim();
    bool hasError = _errorFields.contains(cleanLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: cleanLabel,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (label.contains('Email') && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Invalid email';
                  if (label.contains('Aadhaar') && value.length != 12) return 'Must be 12 digits';
                  return null;
                }
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: hasError ? Colors.red : AppColors.greenLight)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: hasError ? const Icon(Icons.error, color: Colors.red) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, TextEditingController controller,
      [bool isRequired = false]) {
    bool hasAsterisk = label.contains('*');
    String cleanLabel = label.replaceAll('*', '').trim();
    bool hasError = _errorFields.contains(cleanLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: cleanLabel,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.normal,
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
              borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : AppColors.greenLight),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: hasError
                ? const Icon(Icons.error, color: Colors.red)
                : const Icon(Icons.calendar_today,
                    size: 20,
                    color: Colors.grey),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              controller.text =
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    bool isRequired = label.contains('*');
    String cleanLabel = label.replaceAll('*', '').trim();
    bool isFilled = value != null && value.isNotEmpty;
    bool hasError = _errorFields.contains(cleanLabel);

    Color borderColor =
        hasError ? Colors.red : (isFilled ? AppColors.greenLight : Colors.grey);
    Color labelColor = hasError
        ? Colors.red
        : (isFilled ? AppColors.greenLight : Colors.black87);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: cleanLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: labelColor,
                  fontWeight: (isFilled || hasError)
                      ? FontWeight.bold
                      : FontWeight.normal,
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
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: hasError ? Colors.red : AppColors.greenLight),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon:
                hasError ? const Icon(Icons.error, color: Colors.red) : null,
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
