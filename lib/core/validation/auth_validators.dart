/// Form input validation utilities for SafeMate authentication.
/// Universal Engineering Rule #5 & #14: Client-side validation with clear, human-friendly messages.
class AuthValidators {
  const AuthValidators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  static final RegExp _phoneRegExp = RegExp(
    r'^\+[1-9]\d{7,14}$', // E.164 international phone standard
  );

  static final RegExp _digitsOnlyRegExp = RegExp(r'^\d+$');

  /// Validates email address format.
  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email address is required.';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. name@example.com).';
    }
    return null;
  }

  /// Validates password complexity: minimum 8 characters, 1 uppercase, 1 lowercase, 1 digit.
  static String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must include at least one uppercase letter.';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must include at least one lowercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must include at least one number.';
    }
    return null;
  }

  /// Validates E.164 international phone number format.
  static String? validatePhone(String? value) {
    final trimmed = value?.replaceAll(RegExp(r'[\s\-]'), '') ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required.';
    }
    if (!trimmed.startsWith('+')) {
      return 'Phone number must start with country code (e.g. +1 or +91).';
    }
    if (!_phoneRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid international phone number.';
    }
    return null;
  }

  /// Validates 6-digit numerical OTP token.
  static String? validateOtp(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Verification code is required.';
    }
    if (trimmed.length != 6 || !_digitsOnlyRegExp.hasMatch(trimmed)) {
      return 'Verification code must be exactly 6 digits.';
    }
    return null;
  }

  /// Validates user display name.
  static String? validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Full name or display name is required.';
    }
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters long.';
    }
    if (trimmed.length > 50) {
      return 'Name cannot exceed 50 characters.';
    }
    return null;
  }
}
