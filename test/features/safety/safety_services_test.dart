import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/features/safety/domain/services/ai_safety_rule_engine.dart';
import 'package:safemate/features/safety/domain/services/safety_code.dart';

void main() {
  group('SafetyCodeService', () {
    test('Generates valid 6-digit numeric meetup code with 24-hour TTL', () {
      final meetupCode = SafetyCodeService.generateCode();

      expect(meetupCode.code.length, 6);
      expect(int.tryParse(meetupCode.code), isNotNull);
      expect(meetupCode.isExpired, isFalse);
      expect(meetupCode.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('Verifies entered code successfully against correct code', () {
      final code = SafetyCodeService.generateCode();
      final result = SafetyCodeService.verifyCode(
        enteredCode: code.code,
        meetupCode: code,
      );
      expect(result, isTrue);
    });

    test('Rejects incorrect code', () {
      final code = SafetyCodeService.generateCode();
      final wrongCode = code.code == '123456' ? '654321' : '123456';
      final result = SafetyCodeService.verifyCode(
        enteredCode: wrongCode,
        meetupCode: code,
      );
      expect(result, isFalse);
    });

    test('Rejects expired code', () {
      final expiredCode = SafetyMeetupCode(
        code: '987654',
        generatedAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 24)),
      );

      final result = SafetyCodeService.verifyCode(
        enteredCode: '987654',
        meetupCode: expiredCode,
      );
      expect(result, isFalse);
    });
  });

  group('AiSafetyRuleEngine', () {
    test('Flags credential/OTP extraction attempt as CRITICAL', () {
      final warning = AiSafetyRuleEngine.analyzeMessage(
        'Please send me the OTP verification code you just got on SMS',
      );

      expect(warning, isNotNull);
      expect(warning!.severity, SafetyWarningSeverity.critical);
      expect(warning.title, 'Never Share Passwords or OTPs');
      expect(warning.suggestedReplies.isNotEmpty, isTrue);
    });

    test('Flags advance money/wire transfer requests as WARNING', () {
      final warning = AiSafetyRuleEngine.analyzeMessage(
        'Can you send money via GPay me for the hotel advance payment?',
      );

      expect(warning, isNotNull);
      expect(warning!.severity, SafetyWarningSeverity.warning);
      expect(warning.title, 'Financial Advisory');
      expect(warning.suggestedReplies, contains(
        'SafeMate recommends booking our own travel arrangements separately.',
      ));
    });

    test('Flags off-platform pressure as INFO', () {
      final warning = AiSafetyRuleEngine.analyzeMessage(
        'Delete safemate and text me on whatsapp right now',
      );

      expect(warning, isNotNull);
      expect(warning!.severity, SafetyWarningSeverity.info);
      expect(warning.title, 'Stay Safe On Platform');
    });

    test('Returns null for safe travel-coordinating messages', () {
      final warning = AiSafetyRuleEngine.analyzeMessage(
        'Hi! I will meet you at the platform 3 waiting lounge at 10:00 AM.',
      );

      expect(warning, isNull);
    });
  });
}
