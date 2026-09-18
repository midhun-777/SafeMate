import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:safemate/core/config/app_config.dart';
import 'package:safemate/core/errors/app_exception.dart';
import 'package:safemate/features/auth/domain/models/user_profile.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/profile/domain/repositories/profile_repository.dart';

/// Production implementation of ProfileRepository backed by Supabase PostgreSQL and Supabase Storage.
/// Universal Engineering Rule #7: Client only accesses permitted rows and storage paths.
/// Universal Engineering Rule #24: Explicit development limitation notifications when offline.
class SupabaseProfileRepository implements ProfileRepository {
  final sb.SupabaseClient? _client;

  // In-memory cache for local development/testing without hosted Supabase
  final Map<String, UserProfile> _devProfiles = {};
  final Map<String, TravelPreferences> _devPreferences = {};
  final Map<String, List<int>> _devAvatars = {};

  SupabaseProfileRepository({sb.SupabaseClient? client})
      : _client = client; // ignore: prefer_initializing_formals

  sb.SupabaseClient? get _activeClient =>
      _client ?? (AppConfig.hasValidSupabaseConfig ? sb.Supabase.instance.client : null);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final client = _activeClient;
    if (client == null) {
      return _devProfiles[userId] ??
          UserProfile(
            id: userId,
            displayName: 'Traveler',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    }

    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } on sb.PostgrestException catch (e) {
      throw AppException('Database error reading profile: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('Failed to load profile. Please check your network.');
    }
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final client = _activeClient;
    if (client == null) {
      _devProfiles[profile.id] = profile;
      return profile;
    }

    try {
      final data = await client
          .from('profiles')
          .upsert(profile.toJson())
          .select()
          .single();

      return UserProfile.fromJson(data);
    } on sb.PostgrestException catch (e) {
      throw AppException('Failed to save profile: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('An unexpected error occurred while saving profile.');
    }
  }

  @override
  Future<TravelPreferences?> getTravelPreferences(String userId) async {
    final client = _activeClient;
    if (client == null) {
      return _devPreferences[userId] ?? TravelPreferences.empty(userId);
    }

    try {
      final data = await client
          .from('travel_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return TravelPreferences.fromJson(data);
    } on sb.PostgrestException catch (e) {
      throw AppException('Database error reading preferences: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('Failed to load travel preferences.');
    }
  }

  @override
  Future<TravelPreferences> saveTravelPreferences(TravelPreferences preferences) async {
    final client = _activeClient;
    if (client == null) {
      _devPreferences[preferences.userId] = preferences;
      return preferences;
    }

    try {
      final data = await client
          .from('travel_preferences')
          .upsert(
            preferences.toJson(),
            onConflict: 'user_id',
          )
          .select()
          .single();

      return TravelPreferences.fromJson(data);
    } on sb.PostgrestException catch (e) {
      throw AppException('Failed to save travel preferences: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('An unexpected error occurred while saving preferences.');
    }
  }

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required List<int> bytes,
    required String filename,
  }) async {
    // 1. Client-side size validation: max 2MB (2 * 1024 * 1024 bytes)
    const maxSizeBytes = 2 * 1024 * 1024;
    if (bytes.length > maxSizeBytes) {
      throw const AppException('Image exceeds maximum allowed size of 2MB.');
    }

    // 2. MIME / Extension validation
    final ext = filename.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      throw const AppException('Unsupported format. Please upload JPG, PNG, or WebP images.');
    }

    final client = _activeClient;
    if (client == null) {
      debugPrint('[Dev Limitation] Running in development mode without live Supabase storage.');
      _devAvatars[userId] = bytes;
      return 'https://mock.safemate.local/avatars/$userId/avatar.jpg';
    }

    try {
      final path = '$userId/avatar.$ext';
      final uint8List = Uint8List.fromList(bytes);

      await client.storage.from('avatars').uploadBinary(
            path,
            uint8List,
            fileOptions: sb.FileOptions(
              upsert: true,
              contentType: 'image/$ext',
            ),
          );

      final publicUrl = client.storage.from('avatars').getPublicUrl(path);
      return publicUrl;
    } on sb.StorageException catch (e) {
      throw AppException('Storage error uploading photo: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw const AppException('Failed to upload photo. Please verify storage permissions.');
    }
  }

  @override
  Future<void> deleteProfilePhoto(String userId) async {
    final client = _activeClient;
    if (client == null) {
      _devAvatars.remove(userId);
      return;
    }

    try {
      await client.storage.from('avatars').remove([
        '$userId/avatar.jpg',
        '$userId/avatar.jpeg',
        '$userId/avatar.png',
        '$userId/avatar.webp',
      ]);
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Error removing avatar: $e');
    }
  }
}
