/// SafeMate Network Reachability & Connectivity Service.
/// Universal Engineering Rule #24: Explicit network recovery; Connectivity != Server Reachability.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Network status classification.
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Abstract contract for verifying server and network reachability.
abstract class ConnectivityService {
  /// Current reachability status.
  ConnectivityStatus get currentStatus;

  /// Stream emitting connectivity transitions.
  Stream<ConnectivityStatus> get statusStream;

  /// Returns true if the service currently believes the network is reachable.
  bool get isOnline => currentStatus == ConnectivityStatus.online;

  /// Verifies live reachability to backend or DNS.
  Future<bool> checkReachability({Duration timeout = const Duration(seconds: 4)});

  /// Disposes background resources.
  void dispose();
}

/// Default implementation of [ConnectivityService] combining socket/DNS validation
/// with event-driven state emission. Avoids aggressive polling.
class DefaultConnectivityService implements ConnectivityService {
  final String _lookupHost;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _currentStatus = ConnectivityStatus.unknown;
  Timer? _heartbeatTimer;
  bool _isChecking = false;

  DefaultConnectivityService({
    this._lookupHost = 'dns.google',
    bool autoStartHeartbeat = true,
  }) {
    if (autoStartHeartbeat) {
      // Lazy low-frequency health check every 45 seconds (never aggressive polling)
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        checkReachability();
      });
    }
  }

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  @override
  bool get isOnline => _currentStatus == ConnectivityStatus.online;

  @override
  Future<bool> checkReachability({Duration timeout = const Duration(seconds: 4)}) async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    try {
      final results = await InternetAddress.lookup(_lookupHost)
          .timeout(timeout);
      final reachable = results.isNotEmpty && results.first.rawAddress.isNotEmpty;
      _updateStatus(reachable ? ConnectivityStatus.online : ConnectivityStatus.offline);
      return reachable;
    } catch (_) {
      _updateStatus(ConnectivityStatus.offline);
      return false;
    } finally {
      _isChecking = false;
    }
  }

  /// Manually override connectivity status (useful for development mode & automated chaos tests).
  void setManualStatus(ConnectivityStatus status) {
    _updateStatus(status);
  }

  void _updateStatus(ConnectivityStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
      debugPrint('[SafeMate ConnectivityService] Network status transition -> $newStatus');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _statusController.close();
  }
}
