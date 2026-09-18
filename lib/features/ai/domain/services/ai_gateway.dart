/// SafeMate AI Gateway Contract & Rate Limiter.
/// Universal Engineering Rule #11: Graceful degradation, fail-closed security, and structured errors.
library;

import '../models/ai_models.dart';

/// Provider-independent contract for executing AI queries.
abstract class AiGateway {
  /// Executes an AI query and returns a validated [AiResponse].
  Future<AiResponse> execute(AiRequest request);

  /// Checks if AI services are currently available.
  Future<bool> checkAvailability();
}

/// Simple in-memory rate limiter to control costs and prevent request abuse.
class AiRateLimiter {
  final int maxRequests;
  final Duration window;
  final Map<String, List<DateTime>> _requestHistory = {};

  AiRateLimiter({
    this.maxRequests = 10,
    this.window = const Duration(minutes: 5),
  });

  /// Returns true if [userId] is permitted to make an AI request.
  bool allowRequest(String userId) {
    final now = DateTime.now();
    final timestamps = _requestHistory.putIfAbsent(userId, () => []);

    // Evict timestamps outside the window
    timestamps.removeWhere((t) => now.difference(t) > window);

    if (timestamps.length >= maxRequests) {
      return false; // Rate limit exceeded
    }

    timestamps.add(now);
    return true;
  }

  /// Resets history for testing.
  void reset() => _requestHistory.clear();
}
