/// SafeMate Client-Side AI Safety Rule Engine.
/// Analyzes communication content locally and provides privacy-preserving safety advisories.
/// Universal Engineering Rule #11: Safety is a core product capability.
/// Universal Engineering Rule #10: Privacy and consent are first-class design constraints.
library;

enum SafetyWarningSeverity {
  info,
  warning,
  critical,
}

class SafetyWarning {
  final SafetyWarningSeverity severity;
  final String title;
  final String message;
  final List<String> suggestedReplies;

  const SafetyWarning({
    required this.severity,
    required this.title,
    required this.message,
    this.suggestedReplies = const [],
  });
}

class AiSafetyRuleEngine {
  static const List<String> _financialKeywords = [
    'send money',
    'wire money',
    'transfer money',
    'gpay me',
    'paytm me',
    'phonepe me',
    'crypto',
    'bitcoin',
    'advance payment',
    'advance deposit',
    'booking deposit',
    'bank transfer',
    'western union',
    'upi id',
    'send cash',
  ];

  static const List<String> _credentialKeywords = [
    'otp',
    'verification code',
    'password',
    'login pin',
    'secret code',
    'security question',
  ];

  static const List<String> _offPlatformKeywords = [
    'whatsapp me at',
    'text me on whatsapp',
    'telegram me',
    'delete safemate',
    'leave this app',
    'switch to whatsapp',
    'contact me outside',
  ];

  /// Analyzes incoming or outgoing message text deterministically.
  static SafetyWarning? analyzeMessage(String message) {
    final lower = message.toLowerCase();

    // 1. Check for credential extraction (CRITICAL)
    for (final kw in _credentialKeywords) {
      if (lower.contains(kw)) {
        return const SafetyWarning(
          severity: SafetyWarningSeverity.critical,
          title: 'Never Share Passwords or OTPs',
          message:
              'SafeMate staff and travelers will never ask for your verification codes, OTPs, or passwords. Sharing these may compromise your account.',
          suggestedReplies: [
            'I cannot share verification codes or passwords.',
            'Let us keep our conversation safe within SafeMate.',
          ],
        );
      }
    }

    // 2. Check for financial / money requests (WARNING)
    for (final kw in _financialKeywords) {
      if (lower.contains(kw)) {
        return const SafetyWarning(
          severity: SafetyWarningSeverity.warning,
          title: 'Financial Advisory',
          message:
              'SafeMate does not facilitate money transfers between companions. Never send advance deposits or wire money to people you have not met.',
          suggestedReplies: [
            'SafeMate recommends booking our own travel arrangements separately.',
            'I only pay directly at verified transport ticket counters.',
            'Let us discuss travel plans without exchanging money.',
          ],
        );
      }
    }

    // 3. Check for rushed off-platform migration (INFO)
    for (final kw in _offPlatformKeywords) {
      if (lower.contains(kw)) {
        return const SafetyWarning(
          severity: SafetyWarningSeverity.info,
          title: 'Stay Safe On Platform',
          message:
              'For your protection and emergency safety support, we advise keeping journey coordination within SafeMate until trust is established.',
          suggestedReplies: [
            'I prefer keeping our trip planning in SafeMate for now.',
            'Let us coordinate our journey schedule here.',
          ],
        );
      }
    }

    return null;
  }
}
