import 'package:flutter_test/flutter_test.dart';
import 'package:safemate/core/validation/auth_validators.dart';

void main() {
  group('AuthValidators Tests', () {
    group('Email Validation', () {
      test('accepts valid email addresses', () {
        expect(AuthValidators.validateEmail('traveler@example.com'), isNull);
        expect(AuthValidators.validateEmail('user.name+tag@sub.domain.org'), isNull);
        expect(AuthValidators.validateEmail('first_last@company.co'), isNull);
      });

      test('rejects empty or whitespace email', () {
        expect(AuthValidators.validateEmail(null), isNotNull);
        expect(AuthValidators.validateEmail(''), isNotNull);
        expect(AuthValidators.validateEmail('   '), isNotNull);
      });

      test('rejects invalid email formats', () {
        expect(AuthValidators.validateEmail('invalid-email'), isNotNull);
        expect(AuthValidators.validateEmail('missing@domain'), isNotNull);
        expect(AuthValidators.validateEmail('@nodomain.com'), isNotNull);
        expect(AuthValidators.validateEmail('spaces in@email.com'), isNotNull);
      });
    });

    group('Password Validation', () {
      test('accepts valid passwords meeting all criteria', () {
        expect(AuthValidators.validatePassword('SafeTravel1!'), isNull);
        expect(AuthValidators.validatePassword('P@ssword2026'), isNull);
        expect(AuthValidators.validatePassword('SecureRoute99'), isNull);
      });

      test('rejects passwords shorter than 8 characters', () {
        expect(AuthValidators.validatePassword('Pass1'), contains('8 characters'));
      });

      test('rejects passwords without uppercase letters', () {
        expect(AuthValidators.validatePassword('safepassword1'), contains('uppercase'));
      });

      test('rejects passwords without lowercase letters', () {
        expect(AuthValidators.validatePassword('SAFEPASSWORD1'), contains('lowercase'));
      });

      test('rejects passwords without numbers', () {
        expect(AuthValidators.validatePassword('SafePassword'), contains('number'));
      });

      test('rejects empty password', () {
        expect(AuthValidators.validatePassword(''), contains('required'));
        expect(AuthValidators.validatePassword(null), contains('required'));
      });
    });

    group('Phone Number Validation', () {
      test('accepts valid E.164 phone numbers', () {
        expect(AuthValidators.validatePhone('+14155552671'), isNull);
        expect(AuthValidators.validatePhone('+919876543210'), isNull);
        expect(AuthValidators.validatePhone('+447911123456'), isNull);
      });

      test('rejects phone numbers without plus prefix', () {
        expect(AuthValidators.validatePhone('14155552671'), contains('country code'));
      });

      test('rejects phone numbers with too few digits', () {
        expect(AuthValidators.validatePhone('+123'), isNotNull);
      });

      test('rejects empty or whitespace phone number', () {
        expect(AuthValidators.validatePhone(''), contains('required'));
        expect(AuthValidators.validatePhone(null), contains('required'));
      });
    });

    group('OTP Validation', () {
      test('accepts valid 6-digit codes', () {
        expect(AuthValidators.validateOtp('123456'), isNull);
        expect(AuthValidators.validateOtp('000000'), isNull);
        expect(AuthValidators.validateOtp('999999'), isNull);
      });

      test('rejects codes with length other than 6', () {
        expect(AuthValidators.validateOtp('12345'), contains('6 digits'));
        expect(AuthValidators.validateOtp('1234567'), contains('6 digits'));
      });

      test('rejects non-numeric characters', () {
        expect(AuthValidators.validateOtp('12a456'), contains('6 digits'));
        expect(AuthValidators.validateOtp('abcdef'), contains('6 digits'));
      });

      test('rejects empty code', () {
        expect(AuthValidators.validateOtp(''), contains('required'));
        expect(AuthValidators.validateOtp(null), contains('required'));
      });
    });

    group('Display Name Validation', () {
      test('accepts valid display names', () {
        expect(AuthValidators.validateDisplayName('Alex Morgan'), isNull);
        expect(AuthValidators.validateDisplayName('Li'), isNull);
      });

      test('rejects empty or single character names', () {
        expect(AuthValidators.validateDisplayName(''), contains('required'));
        expect(AuthValidators.validateDisplayName('A'), contains('2 characters'));
      });

      test('rejects names exceeding 50 characters', () {
        final longName = 'A' * 51;
        expect(AuthValidators.validateDisplayName(longName), contains('cannot exceed 50'));
      });
    });
  });
}
