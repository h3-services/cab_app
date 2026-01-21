class TripStateService {
  static final TripStateService _instance = TripStateService._internal();
  factory TripStateService() => _instance;
  TripStateService._internal();

  bool _isReadyForTrip = false;

  bool get isReadyForTrip => _isReadyForTrip;

  void setReadyForTrip(bool value) {
    _isReadyForTrip = value;
  }
}