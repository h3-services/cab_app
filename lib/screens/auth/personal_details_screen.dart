import 'package:flutter/material.dart';
import '../../widgets/widgets.dart';
import '../../constants/app_colors.dart';
import '../../services/device_service.dart';
import '../../services/api_service.dart';
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
  // Logic from KYC screen: track which fields are valid/modified
  // false = Error/Rejection, true = Correct/Modified
  final Map<String, bool> _fieldStatuses = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;

    debugPrint("\n=== PERSONAL DETAILS: didChangeDependencies ===");
    debugPrint("Args Type: ${args.runtimeType}");
    debugPrint("Args Content: $args");

    if (args is Map && args['isEditing'] == true) {
      if (!_isDataLoaded) {
        debugPrint("First time load: Calling _loadSavedData");
        _loadSavedData();
        _isDataLoaded = true;
      }

      if (args['errorFields'] != null) {
        final List<String> incomingErrors =
            List<String>.from(args['errorFields']);
        debugPrint("Informing Error Fields to Highlight: $incomingErrors");

        // Populate field statuses
        for (var field in incomingErrors) {
          final normalized = field.toLowerCase().trim();
          // Only set to false if it hasn't been modified yet
          if (!_fieldStatuses.containsKey(normalized) ||
              _fieldStatuses[normalized] == false) {
            _fieldStatuses[normalized] = false;
            debugPrint("Marked for RED highlight: '$normalized'");
          }
        }
      }
    } else if (args is String) {
      phoneNumber = args;
    }

    _ensurePhoneNumber();
    debugPrint("==============================================\n");
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
    if (!mounted) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> data =
        (args is Map<String, dynamic>) ? args : {};

    setState(() {
      // Prioritize args, then Prefs
      phoneNumber = data['phoneNumber'] ?? prefs.getString('phoneNumber');
      _nameController.text = data['name'] ?? prefs.getString('name') ?? '';
      _emailController.text = data['email'] ?? prefs.getString('email') ?? '';
      _primaryLocationController.text =
          data['primaryLocation'] ?? prefs.getString('primaryLocation') ?? '';
      _licenseController.text =
          data['licenceNumber'] ?? prefs.getString('licenseNumber') ?? '';
      _aadharController.text =
          data['aadharNumber'] ?? prefs.getString('aadhaarNumber') ?? '';

      _vehicleMakeController.text =
          data['vehicleBrand'] ?? prefs.getString('vehicleBrand') ?? '';
      _vehicleModelController.text =
          data['vehicleModel'] ?? prefs.getString('vehicleModel') ?? '';
      _vehicleNumberController.text =
          data['vehicleNumber'] ?? prefs.getString('vehicleNumber') ?? '';
      _vehicleColorController.text =
          data['vehicleColor'] ?? prefs.getString('vehicleColor') ?? '';

      String? rawVehicleType =
          data['vehicleType'] ?? prefs.getString('vehicleType');
      if (['SUV', 'Innova', 'Sedan'].contains(rawVehicleType)) {
        _selectedVehicleType = rawVehicleType;
      } else {
        _selectedVehicleType = null;
      }

      String? rawSeating =
          data['seatingCapacity'] ?? prefs.getString('seatingCapacity');
      if (['4', '6', '7'].contains(rawSeating)) {
        _selectedSeatingCapacity = rawSeating;
      } else {
        _selectedSeatingCapacity = '4'; // Default safe fallback
      }

      _drivingLicenseExpiryController.text = _formatDateForDisplay(
          data['licenceExpiry'] ?? prefs.getString('licenceExpiry'));
      _rcExpiryController.text = _formatDateForDisplay(
          data['rcExpiryDate'] ?? prefs.getString('rcExpiryDate'));
      _fcExpiryController.text = _formatDateForDisplay(
          data['fcExpiryDate'] ?? prefs.getString('fcExpiryDate'));
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
        showBackButton: false,
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
                                'FC Permit Date*', _fcExpiryController, true),
                            const SizedBox(height: 16),
                            _buildDateField(
                                'Permit Expiry Date*', _rcExpiryController, true),
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
                                ['4', '6', '7'], (value) {
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
                                if (!context.mounted) return;
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

                                // Save ALL user data to SharedPreferences for persistence
                                await prefs.setString(
                                    'name', _nameController.text);
                                await prefs.setString(
                                    'email', _emailController.text);
                                await prefs.setString('primaryLocation',
                                    _primaryLocationController.text);
                                await prefs.setString(
                                    'licenseNumber', _licenseController.text);
                                await prefs.setString(
                                    'aadhaarNumber', _aadharController.text);
                                await prefs.setString(
                                    'licenceExpiry', licenseDate);
                                await prefs.setString(
                                    'vehicleType', _selectedVehicleType ?? '');
                                await prefs.setString('vehicleBrand',
                                    _vehicleMakeController.text);
                                await prefs.setString('vehicleModel',
                                    _vehicleModelController.text);
                                await prefs.setString('vehicleNumber',
                                    _vehicleNumberController.text);
                                await prefs.setString('vehicleColor',
                                    _vehicleColorController.text);
                                await prefs.setString('seatingCapacity',
                                    _selectedSeatingCapacity ?? '4');
                                await prefs.setString('rcExpiryDate', rcDate);
                                await prefs.setString('fcExpiryDate', fcDate);
                                
                                // Set login state for new registrations
                                if (!isEditing) {
                                  await prefs.setBool('isLoggedIn', true);
                                }
                                
                                debugPrint(
                                    "=== Saved all user data to SharedPreferences ===");

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

    // Logic from KYC: Check if this specific field has an active error
    final normalizedLabel = cleanLabel.toLowerCase().trim();
    bool hasError = _fieldStatuses[normalizedLabel] == false;

    // Fallback for slight naming inconsistencies
    if (!hasError) {
      if (normalizedLabel == 'license number')
        hasError = _fieldStatuses['licence number'] == false;
      if (normalizedLabel == 'licence number')
        hasError = _fieldStatuses['license number'] == false;
    }

    if (hasError) {
      debugPrint("BUILDING: '$normalizedLabel' is RED");
    }

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, child) {
        bool isFilled = controller.text.isNotEmpty;
        Color borderColor = hasError
            ? Colors.red
            : (isFilled ? AppColors.greenLight : Colors.grey);
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
                    TextSpan(
                      text: ' *',
                      style: const TextStyle(
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
              onChanged: (val) {
                if (_fieldStatuses[cleanLabel.toLowerCase()] == false) {
                  setState(() {
                    _fieldStatuses[cleanLabel.toLowerCase()] = true;
                  });
                }
              },
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
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateField(String label, TextEditingController controller,
      [bool isRequired = false]) {
    bool hasAsterisk = label.contains('*');
    String cleanLabel = label.replaceAll('*', '').trim();

    // Logic from KYC screen
    final normalizedLabel = cleanLabel.toLowerCase().trim();
    bool hasError = _fieldStatuses[normalizedLabel] == false;

    // Fallback for common date label variations
    if (!hasError) {
      if (normalizedLabel.contains('license') || normalizedLabel.contains('licence'))
        hasError = _fieldStatuses['driving license expiry date'] == false ||
                   _fieldStatuses['driving license'] == false;
      if (normalizedLabel == 'rc expiry date')
        hasError = _fieldStatuses['rc book'] == false ||
                   _fieldStatuses['rc expiry date'] == false;
      if (normalizedLabel == 'fc expiry date')
        hasError = _fieldStatuses['fc certificate'] == false ||
                   _fieldStatuses['fc expiry date'] == false;
    }

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, child) {
        bool isFilled = controller.text.isNotEmpty;
        Color borderColor = hasError
            ? Colors.red
            : (isFilled ? AppColors.greenLight : Colors.grey);
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
                    : Icon(Icons.calendar_today,
                        size: 20,
                        color: isFilled ? AppColors.greenLight : Colors.grey),
              ),
              onTap: () async {
                // Clear error status for all possible field name variations
                final possibleKeys = [
                  cleanLabel.toLowerCase(),
                  normalizedLabel,
                  'rc book',
                  'fc certificate',
                  'driving license expiry date',
                  'driving license',
                  'licence expiry date',
                  'license expiry date'
                ];
                
                bool hadError = false;
                for (String key in possibleKeys) {
                  if (_fieldStatuses[key] == false) {
                    hadError = true;
                    _fieldStatuses[key] = true;
                  }
                }
                
                if (hadError) {
                  setState(() {});
                }
                
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  controller.text =
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  
                  // Ensure all possible field variations are marked as fixed
                  setState(() {
                    for (String key in possibleKeys) {
                      _fieldStatuses[key] = true;
                    }
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    bool isRequired = label.contains('*');
    String cleanLabel = label.replaceAll('*', '').trim();
    bool isFilled = value != null && value.isNotEmpty;

    // Logic from KYC Screen
    final normalizedLabel = cleanLabel.toLowerCase().trim();
    bool hasError = _fieldStatuses[normalizedLabel] == false;

    if (!hasError) {
      if (normalizedLabel.contains('vehicle type'))
        hasError = _fieldStatuses['vehicle type'] == false;
      if (normalizedLabel.contains('seating'))
        hasError = _fieldStatuses['seating capacity'] == false;
    }

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
          onChanged: (val) {
            if (_fieldStatuses[cleanLabel.toLowerCase()] == false) {
              setState(() {
                _fieldStatuses[cleanLabel.toLowerCase()] = true;
              });
            }
            onChanged(val);
          },
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
