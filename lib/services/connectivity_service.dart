import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _hasConnection = true;

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
  }

  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
