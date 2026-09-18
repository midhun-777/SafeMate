import 'package:safemate/features/auth/domain/models/user_profile.dart';
import '../models/travel_preferences.dart';

/// Abstract Profile Repository contract for SafeMate.
/// Manages user application profiles, travel preferences, and secure avatar storage.
abstract class ProfileRepository {
  /// Fetches application profile details for the given user ID.
  Future<UserProfile?> getProfile(String userId);

  /// Saves updated profile details to persistent storage.
  Future<UserProfile> saveProfile(UserProfile profile);

  /// Fetches travel companion preferences for the given user ID.
  Future<TravelPreferences?> getTravelPreferences(String userId);

  /// Saves updated travel preferences to persistent storage.
  Future<TravelPreferences> saveTravelPreferences(TravelPreferences preferences);

  /// Uploads compressed profile avatar to secure storage and returns public URL.
  Future<String> uploadProfilePhoto({
    required String userId,
    required List<int> bytes,
    required String filename,
  });

  /// Removes profile avatar from storage.
  Future<void> deleteProfilePhoto(String userId);
}
