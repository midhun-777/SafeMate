import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/network/connectivity_service.dart';

void main() {
  group('Phase 12.3 ConnectivityService Tests (12.3.4)', () {
    late DefaultConnectivityService connectivity;

    setUp(() {
      connectivity = DefaultConnectivityService(
        lookupHost: 'localhost',
        autoStartHeartbeat: false,
      );
    });

    tearDown(() {
      connectivity.dispose();
    });

    test('Initial state starts as unknown or set explicitly', () {
      expect(connectivity.currentStatus, ConnectivityStatus.unknown);
      expect(connectivity.isOnline, isFalse);
    });

    test('setManualStatus updates status and emits to stream', () async {
      final emitted = <ConnectivityStatus>[];
      final sub = connectivity.statusStream.listen(emitted.add);

      connectivity.setManualStatus(ConnectivityStatus.online);
      expect(connectivity.currentStatus, ConnectivityStatus.online);
      expect(connectivity.isOnline, isTrue);

      connectivity.setManualStatus(ConnectivityStatus.offline);
      expect(connectivity.currentStatus, ConnectivityStatus.offline);
      expect(connectivity.isOnline, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emitted, [ConnectivityStatus.online, ConnectivityStatus.offline]);
      await sub.cancel();
    });
  });
}
