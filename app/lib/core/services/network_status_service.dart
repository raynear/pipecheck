import 'dart:async';

import 'package:boilerplate/config/app_feature_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utils/utils.dart';

/// Network connection status
enum NetworkStatus {
  online,
  offline,
}

/// Service that monitors network connectivity changes
class NetworkStatusService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _statusController = StreamController<NetworkStatus>.broadcast();

  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Start monitoring network status
  Future<NetworkStatus> initialize() async {
    final results = await _connectivity.checkConnectivity();
    final status = _mapResultsToStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final newStatus = _mapResultsToStatus(results);
      logger.d('NetworkStatus: $newStatus');
      _statusController.add(newStatus);
    });

    return status;
  }

  NetworkStatus _mapResultsToStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _statusController.close();
  }
}

/// Provider for network status stream
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider that exposes current network status as a stream
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  if (!AppFeatureConfig.isNetworkMonitoringEnabled) {
    yield NetworkStatus.online;
    return;
  }

  final service = ref.watch(networkStatusServiceProvider);
  final initial = await service.initialize();
  yield initial;
  yield* service.statusStream;
});

/// Simple boolean provider for quick connectivity checks
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkStatusProvider);
  return status.when(
    data: (s) => s == NetworkStatus.online,
    loading: () => true, // Assume online during loading
    error: (_, __) => true, // Assume online on error
  );
});
