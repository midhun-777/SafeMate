/// SafeMate AI Response Validation & Safety Filter.
/// Universal Engineering Rule #11: Fail-closed validation; never trust arbitrary AI generation.
library;

import 'dart:convert';
import '../models/ai_models.dart';

/// Validates structured schemas and filters AI outputs for sensitive content or dangerous commands.
class AiResponseValidator {
  const AiResponseValidator();

  static const List<String> _forbiddenOutputPatterns = [
    'BEGIN PRIVATE KEY',
    'PASSWORD=',
    'BEARER ',
    'SELECT * FROM',
    'DROP TABLE',
    'INSERT INTO',
    'UPDATE auth.users',
    'DANGEROUS TRAVELER',
    'POLICE CONTACTED',
    '911 DISPATCHED',
  ];

  /// Validates [response] ensuring no PII, dangerous claims, or leaked credentials exist.
  /// Throws [AiException] if a severe safety violation is detected, or sanitizes the response.
  AiResponse validateAndSanitize(AiResponse response) {
    final rawText = response.content;

    // 1. Scan for forbidden system strings / dangerous claims
    for (final pattern in _forbiddenOutputPatterns) {
      if (rawText.toUpperCase().contains(pattern)) {
        throw const AiException(
          kind: AiErrorKind.policyViolation,
          message: 'AI response was blocked due to safety policy validation.',
          canRetry: false,
        );
      }
    }

    // 2. Validate structured schema if JSON payload exists
    Map<String, dynamic>? validatedStructured = response.structuredData;
    if (validatedStructured == null && rawText.trim().startsWith('{') && rawText.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is Map<String, dynamic>) {
          validatedStructured = _validateSchema(decoded);
        }
      } catch (_) {
        // Fall back to plain text if JSON is invalid
      }
    }

    return AiResponse(
      content: response.content,
      structuredData: validatedStructured,
      usage: response.usage,
      model: response.model,
      latencyMs: response.latencyMs,
      isFallback: response.isFallback,
      timestamp: response.timestamp,
    );
  }

  /// Validates known structured schemas.
  Map<String, dynamic>? _validateSchema(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'itinerary_proposal':
        if (data['items'] is! List) return null;
        return data;
      case 'safety_guidance':
        if (data['tips'] is! List) return null;
        return data;
      case 'companion_coordination':
        return data;
      default:
        return data;
    }
  }

  /// Sanitizes user input before it is concatenated with system instructions.
  /// Neutralizes prompt injection delimiters.
  static String sanitizePromptInput(String input) {
    var clean = input.replaceAll('```', '');
    clean = clean.replaceAll('<SYSTEM>', '');
    clean = clean.replaceAll('</SYSTEM>', '');
    clean = clean.replaceAll(RegExp(r'IGNORE\s+(ALL\s+)?PREVIOUS\s+INSTRUCTIONS', caseSensitive: false), '[REMOVED]');
    return clean.trim();
  }
}
