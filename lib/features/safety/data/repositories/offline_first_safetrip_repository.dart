/// SafeMate Offline-First SafeTrip Repository.
/// Universal Engineering Rule #7: Server state must be authoritative.
/// Universal Engineering Rule #18: Zero false claims of emergency dispatch or notification delivery.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/models/safetrip_models.dart';
import '../../domain/repositories/safetrip_repository.dart';

class OfflineFirstSafeTripRepository implements SafeTripRepository {
  final SafeTripRepository _remoteRepo;
  final LocalDatabaseService _localDb;
  final SyncEngine? _syncEngine;

  OfflineFirstSafeTripRepository({
    required SafeTripRepository remoteRepo,
    required LocalDatabaseService localDb,
    SyncEngine? syncEngine,
  })  : _remoteRepo = remoteRepo, // ignore: prefer_initializing_formals
        _localDb = localDb, // ignore: prefer_initializing_formals
        _syncEngine = syncEngine { // ignore: prefer_initializing_formals
    _syncEngine?.registerHandler('safetrip_checkin', _handleSyncMutation);
  }

  Future<void> _handleSyncMutation(SyncRecord record) async {
    if (record.action == 'record_checkin') {
      final payload = record.payload;
      final journeyId = payload['journey_id'] as String;
      final userId = payload['user_id'] as String;
      final idempotencyKey = payload['idempotency_key'] as String;
      final notes = payload['notes'] as String?;

      final confirmed = await _remoteRepo.recordCheckin(
        journeyId: journeyId,
        userId: userId,
        idempotencyKey: idempotencyKey,
        notes: notes,
      );
      await _localDb.saveCheckin(confirmed, syncStatus: 'synced');
    }
  }

  @override
  Future<SafeTrip?> getSafeTripByTripId(String tripId) async {
    final cached = await _localDb.getSafeTripByTripId(tripId);
    try {
      final remote = await _remoteRepo.getSafeTripByTripId(tripId);
      if (remote != null) {
        await _localDb.saveSafeTrip(remote);
        return remote;
      }
    } catch (_) {
      // Offline fallback
    }
    return cached;
  }

  @override
  Future<SafeTrip?> getSafeTripById(String journeyId) async {
    final cached = await _localDb.getSafeTrip(journeyId);
    try {
      final remote = await _remoteRepo.getSafeTripById(journeyId);
      if (remote != null) {
        await _localDb.saveSafeTrip(remote);
        return remote;
      }
    } catch (_) {
      // Offline fallback
    }
    return cached;
  }

  @override
  Future<SafeTrip> prepareSafeTrip(SafeTrip safeTrip) async {
    await _localDb.saveSafeTrip(safeTrip);
    try {
      final remote = await _remoteRepo.prepareSafeTrip(safeTrip);
      await _localDb.saveSafeTrip(remote);
      return remote;
    } catch (e) {
      debugPrint('[SafeMate OfflineSafeTrip] Saved locally, remote prep failed: $e');
      return safeTrip;
    }
  }

  @override
  Future<SafeTrip> activateSafeTrip({
    required String journeyId,
    required String idempotencyKey,
    required JourneyConsent consent,
  }) async {
    // Activation requires server authorization per Universal Rule #18
    // Cannot autonomously activate SafeTrip offline without server timestamp
    final remote = await _remoteRepo.activateSafeTrip(
      journeyId: journeyId,
      idempotencyKey: idempotencyKey,
      consent: consent,
    );
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> pauseSafeTrip(String journeyId) async {
    final remote = await _remoteRepo.pauseSafeTrip(journeyId);
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> resumeSafeTrip(String journeyId) async {
    final remote = await _remoteRepo.resumeSafeTrip(journeyId);
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> confirmArrival({
    required String journeyId,
    required String idempotencyKey,
  }) async {
    final remote = await _remoteRepo.confirmArrival(
      journeyId: journeyId,
      idempotencyKey: idempotencyKey,
    );
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> completeSafeTrip({
    required String journeyId,
    required String idempotencyKey,
  }) async {
    final remote = await _remoteRepo.completeSafeTrip(
      journeyId: journeyId,
      idempotencyKey: idempotencyKey,
    );
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> cancelSafeTrip(String journeyId, {String? reason}) async {
    final remote = await _remoteRepo.cancelSafeTrip(journeyId, reason: reason);
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<SafeTrip> expireSafeTrip(String journeyId) async {
    final remote = await _remoteRepo.expireSafeTrip(journeyId);
    await _localDb.saveSafeTrip(remote);
    return remote;
  }

  @override
  Future<JourneyCheckin> recordCheckin({
    required String journeyId,
    required String userId,
    required String idempotencyKey,
    String? notes,
  }) async {
    final now = DateTime.now();
    final localCheckin = JourneyCheckin(
      id: 'checkin_${now.millisecondsSinceEpoch}',
      journeyId: journeyId,
      userId: userId,
      checkinNumber: 1,
      status: CheckinStatus.completed,
      scheduledFor: now,
      completedAt: now,
      notes: notes != null
          ? '$notes [Offline: waiting for network confirmation]'
          : 'Check-in waiting for network confirmation.',
      idempotencyKey: idempotencyKey,
    );

    // 1. Record in local SQLite with pending sync status
    await _localDb.saveCheckin(localCheckin, syncStatus: 'pending');

    // 2. Attempt remote sync
    try {
      final remoteCheckin = await _remoteRepo.recordCheckin(
        journeyId: journeyId,
        userId: userId,
        idempotencyKey: idempotencyKey,
        notes: notes,
      );
      await _localDb.saveCheckin(remoteCheckin, syncStatus: 'synced');
      return remoteCheckin;
    } catch (e) {
      debugPrint('[SafeMate OfflineSafeTrip] Check-in logged locally awaiting network: $e');
      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          userId: userId,
          entityType: 'safetrip_checkin',
          entityId: idempotencyKey,
          action: 'record_checkin',
          payload: {
            'journey_id': journeyId,
            'user_id': userId,
            'idempotency_key': idempotencyKey,
            'notes': notes,
            'local_timestamp': now.toIso8601String(),
          },
        );
      }
      return localCheckin;
    }
  }

  @override
  Future<List<JourneyCheckin>> getCheckins(String journeyId) async {
    final localCheckins = await _localDb.getJourneyCheckins(journeyId);
    try {
      final remoteCheckins = await _remoteRepo.getCheckins(journeyId);
      for (final c in remoteCheckins) {
        await _localDb.saveCheckin(c, syncStatus: 'synced');
      }
      return remoteCheckins;
    } catch (_) {
      return localCheckins;
    }
  }

  @override
  Future<LocationShareSession> startLocationSharing({
    required String journeyId,
    required String userId,
    required LocationSharingMode mode,
    required Duration duration,
    String? approxGeohash,
  }) {
    return _remoteRepo.startLocationSharing(
      journeyId: journeyId,
      userId: userId,
      mode: mode,
      duration: duration,
      approxGeohash: approxGeohash,
    );
  }

  @override
  Future<void> stopLocationSharing({
    required String journeyId,
    required String userId,
  }) {
    return _remoteRepo.stopLocationSharing(
      journeyId: journeyId,
      userId: userId,
    );
  }

  @override
  Future<LocationShareSession?> getActiveLocationSession(String journeyId) {
    return _remoteRepo.getActiveLocationSession(journeyId);
  }

  @override
  Future<void> recordJourneyEvent({
    required String journeyId,
    required String userId,
    required String eventType,
    Map<String, dynamic>? payload,
  }) {
    return _remoteRepo.recordJourneyEvent(
      journeyId: journeyId,
      userId: userId,
      eventType: eventType,
      payload: payload,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getJourneyEvents(String journeyId) {
    return _remoteRepo.getJourneyEvents(journeyId);
  }

  @override
  Stream<SafeTrip> watchSafeTrip(String journeyId) {
    return _remoteRepo.watchSafeTrip(journeyId);
  }
}
