/// SafeMate AI Domain Models & Gateway Contracts.
/// Universal Engineering Rule #11: Type-safe, deterministic contracts with zero secret leakage.
library;

/// Distinct AI feature categories within SafeMate.
enum AiFeatureType {
  copilot('copilot', 'Journey Copilot'),
  itinerary('itinerary', 'Itinerary Assistance'),
  adaptivePlanning('adaptive_planning', 'Adaptive Journey Planning'),
  safetyAssist('safety_assist', 'Safety & Privacy Assist'),
  companionCoord('companion_coord', 'Companion Coordination'),
  matchExplanation('match_explanation', 'Match Compatibility Explanation'),
  trustExplanation('trust_explanation', 'Trust & Reputation Explanation'),
  disruptionHelp('disruption_help', 'Disruption Assistance');

  final String code;
  final String label;

  const AiFeatureType(this.code, this.label);
}

/// Token and quota accounting information.
class AiUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const AiUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  factory AiUsage.fromJson(Map<String, dynamic> json) {
    return AiUsage(
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };
}

/// Standardized AI request payload.
class AiRequest {
  final AiFeatureType feature;
  final String systemPrompt;
  final String userPrompt;
  final Map<String, dynamic> context;
  final int maxTokens;
  final double temperature;
  final Duration timeout;

  const AiRequest({
    required this.feature,
    required this.systemPrompt,
    required this.userPrompt,
    this.context = const {},
    this.maxTokens = 1024,
    this.temperature = 0.4,
    this.timeout = const Duration(seconds: 15),
  });

  Map<String, dynamic> toJson() => {
        'feature': feature.code,
        'system_prompt': systemPrompt,
        'user_prompt': userPrompt,
        'context': context,
        'max_tokens': maxTokens,
        'temperature': temperature,
      };
}

/// Standardized AI response payload.
class AiResponse {
  final String content;
  final Map<String, dynamic>? structuredData;
  final AiUsage usage;
  final String model;
  final int latencyMs;
  final bool isFallback;
  final DateTime timestamp;

  AiResponse({
    required this.content,
    this.structuredData,
    this.usage = const AiUsage(),
    required this.model,
    required this.latencyMs,
    this.isFallback = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory AiResponse.fallback({
    required String message,
    String model = 'system-fallback',
  }) {
    return AiResponse(
      content: message,
      model: model,
      latencyMs: 0,
      isFallback: true,
    );
  }
}

/// Standardized AI error taxonomy.
enum AiErrorKind {
  network('network', 'Network connectivity failure.'),
  rateLimited('rate_limited', 'Usage rate limit reached. Please wait a moment.'),
  timeout('timeout', 'AI request timed out.'),
  policyViolation('policy_violation', 'Request blocked by safety or privacy policy.'),
  serverError('server_error', 'Remote AI service encountered an error.'),
  unavailable('unavailable', 'Journey AI is temporarily unavailable.'),
  invalidResponse('invalid_response', 'Malformed or unparseable AI response.');

  final String code;
  final String userMessage;

  const AiErrorKind(this.code, this.userMessage);
}

/// Exception class for SafeMate AI errors.
class AiException implements Exception {
  final AiErrorKind kind;
  final String message;
  final int? statusCode;
  final bool canRetry;

  const AiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.canRetry = false,
  });

  @override
  String toString() => 'AiException($kind, $message, status: $statusCode)';
}
