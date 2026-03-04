import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _hasConnection = true;
  Timer? _pingTimer;
  Future<void> initialize() async {
    _hasConnection = await checkConnection();
    _connectionStatusController.add(_hasConnection);
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final hasConnection = await checkConnection();
      if (_hasConnection != hasConnection) {
        _hasConnection = hasConnection;
        _connectionStatusController.add(_hasConnection);
      }
    });
    _startPeriodicCheck();
  }
  void _startPeriodicCheck() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final hasConnection = await checkConnection();
      if (_hasConnection != hasConnection) {
        _hasConnection = hasConnection;
        _connectionStatusController.add(_hasConnection);
      }
    });
  }
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
        onTimeout: () => [],
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  void dispose() {
    _pingTimer?.cancel();
    _connectionStatusController.close();
  }
}
