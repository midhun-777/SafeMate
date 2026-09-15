import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/utils/geohash_helper.dart';

void main() {
  group('GeohashHelper Tests', () {
    test('Encodes standard coordinates accurately', () {
      // Tokyo coordinates: 35.6762, 139.6503 -> prefix 'xn76'
      final hash = GeohashHelper.encode(35.6762, 139.6503, precision: 6);
      expect(hash.length, equals(6));
      expect(hash.startsWith('xn76'), isTrue);
    });

    test('Encodes Paris coordinates accurately', () {
      // Paris coordinates: 48.8566, 2.3522 -> prefix 'u09t'
      final hash = GeohashHelper.encode(48.8566, 2.3522, precision: 6);
      expect(hash.length, equals(6));
      expect(hash.startsWith('u09t'), isTrue);
    });

    test('Throws ArgumentError on invalid latitude', () {
      expect(
        () => GeohashHelper.encode(95.0, 0.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => GeohashHelper.encode(-91.0, 0.0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Throws ArgumentError on invalid longitude', () {
      expect(
        () => GeohashHelper.encode(0.0, 185.0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => GeohashHelper.encode(0.0, -181.0),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
