/// Candidate traveler and journey wrapper for matching evaluation.
/// Universal Engineering Rule #6: Strict domain boundaries, privacy-safe identity.
library;

import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/trips/domain/models/trip.dart';

/// Encapsulates all data required to evaluate a candidate companion for a journey.
class MatchCandidate {
  final Trip trip;
  final UserProfile profile;
  final TravelPreferences? preferences;

  const MatchCandidate({
    required this.trip,
    required this.profile,
    this.preferences,
  });

  String get candidateUserId => profile.id;
  String get candidateTripId => trip.id;
  String get displayName => profile.displayName.isNotEmpty ? profile.displayName : 'Traveler';
  String? get avatarUrl => profile.avatarUrl;
  String get homeCity => profile.homeCity ?? '';
  int get trustScore => profile.trustScore;
  bool get isIdentityVerified => profile.trustScore >= 80;
  bool get isPhoneVerified => profile.trustScore >= 50;

  String get origin => trip.origin;
  String get destination => trip.destination;
  DateTime get startDate => trip.startDate;
  DateTime get endDate => trip.endDate;
}
