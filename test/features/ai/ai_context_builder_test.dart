import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/ai/domain/models/journey_ai_context.dart';
import 'package:safemate/features/ai/domain/services/ai_context_builder.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';
import 'package:safemate/features/trips/domain/models/trip_budget.dart';
import 'package:safemate/features/trips/domain/models/trip_purpose.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';

void main() {
  group('Journey AI Context & Privacy Engine', () {
    late Trip sampleTrip;

    setUp(() {
      final now = DateTime.now();
      sampleTrip = Trip(
        id: 'trip_100',
        userId: 'user_alice',
        origin: 'Berlin',
        originCity: 'Berlin',
        destination: 'Munich',
        destinationCity: 'Munich',
        startDate: now,
        endDate: now.add(const Duration(days: 4)),
        budgetTier: TripBudgetTier.moderate,
        transportMode: TripTransport.train,
        tripPurpose: TripPurpose.vacation,
        tripStyles: const ['culture', 'sightseeing'],
        notes: 'Call me at +1 555-123-4567 or email secret@example.com! Meet near 48.1351, 11.5820.',
      );
    });

    test('strips phone numbers, emails, and exact coordinates from trip notes', () {
      final context = JourneyAiContext.fromTrip(trip: sampleTrip);

      expect(context.destination, 'Munich');
      expect(context.approximateOrigin, 'Berlin');
      expect(context.durationDays, 5);

      // Verify PII stripping
      expect(context.sanitizedNotes, isNotNull);
      expect(context.sanitizedNotes, isNot(contains('secret@example.com')));
      expect(context.sanitizedNotes, contains('[EMAIL REMOVED]'));
      expect(context.sanitizedNotes, isNot(contains('555-123-4567')));
      expect(context.sanitizedNotes, contains('[PHONE REMOVED]'));
      expect(context.sanitizedNotes, isNot(contains('48.1351, 11.5820')));
      expect(context.sanitizedNotes, contains('[COORDINATES REMOVED]'));
    });

    test('enforces user ownership authorization when building context', () {
      const builder = AiJourneyContextBuilder();

      // Authorized owner succeeds
      final context = builder.buildContext(
        trip: sampleTrip,
        requestingUserId: 'user_alice',
      );
      expect(context.tripId, 'trip_100');

      // Unauthorized third-party is strictly blocked
      expect(
        () => builder.buildContext(
          trip: sampleTrip,
          requestingUserId: 'unauthorized_attacker',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('denylist detector flags dangerous keys and PII patterns', () {
      expect(AiJourneyContextBuilder.containsSensitiveData({'aadhaar': '1234-5678-9012'}), isTrue);
      expect(AiJourneyContextBuilder.containsSensitiveData({'exact_coordinates': '48.1, 11.5'}), isTrue);
      expect(AiJourneyContextBuilder.containsSensitiveData({'auth_token': 'secret-token'}), isTrue);
      expect(AiJourneyContextBuilder.containsSensitiveData({'emergency_contact_phone': '555'}), isTrue);
      expect(AiJourneyContextBuilder.containsSensitiveData({'destination': 'Munich'}), isFalse);
    });
  });
}
