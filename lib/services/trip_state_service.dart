import 'package:shared_preferences/shared_preferences.dart';

class TripStateService {
  static final TripStateService _instance = TripStateService._internal();
  factory TripStateService() => _instance;
  TripStateService._internal() {
    _loadState();
  }

  bool _isReadyForTrip = false;

  bool get isReadyForTrip => _isReadyForTrip;

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _isReadyForTrip = prefs.getBool('is_available') ?? false;
  }

  Future<void> setReadyForTrip(bool value) async {
    _isReadyForTrip = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_available', value);
  }
}