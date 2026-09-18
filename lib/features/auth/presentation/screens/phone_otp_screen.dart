import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/validation/auth_validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

/// Phone Number and SMS OTP verification screen.
/// Adheres to E.164 phone format and 6-digit token verification.
class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isCodeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!_phoneFormKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).signInWithOtp(
          phone: _phoneController.text.trim(),
        );

    if (success && mounted) {
      setState(() {
        _isCodeSent = true;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    ref.read(authControllerProvider.notifier).clearError();
    if (!_otpFormKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).verifyPhoneOtp(
          phone: _phoneController.text.trim(),
          token: _otpController.text.trim(),
        );

    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isCodeSent) {
              setState(() {
                _isCodeSent = false;
                _otpController.clear();
              });
            } else {
              context.go('/auth/welcome');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isCodeSent ? 'Enter Verification Code' : 'Phone Verification',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isCodeSent
                    ? 'We sent a 6-digit verification code to ${_phoneController.text}.'
                    : 'Enter your phone number with country code to receive a one-time verification code.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),

              // Error banner
              if (authState.errorMessage != null) ...[
                AuthErrorBanner(
                  message: authState.errorMessage!,
                  onDismiss: () =>
                      ref.read(authControllerProvider.notifier).clearError(),
                ),
                const SizedBox(height: 20),
              ],

              if (!_isCodeSent) ...[
                // Phone entry form
                Form(
                  key: _phoneFormKey,
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hintText: '+1 415 555 2671',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        validator: AuthValidators.validatePhone,
                        onFieldSubmitted: (_) => _handleSendOtp(),
                        onChanged: (_) =>
                            ref.read(authControllerProvider.notifier).clearError(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Standard SMS rates may apply. Use the international format starting with +.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthButton(
                        text: 'Send Verification Code',
                        isLoading: authState.isLoading,
                        onPressed: _handleSendOtp,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // OTP entry form
                Form(
                  key: _otpFormKey,
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _otpController,
                        label: '6-Digit Code',
                        hintText: '123456',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                        validator: AuthValidators.validateOtp,
                        onFieldSubmitted: (_) => _handleVerifyOtp(),
                        onChanged: (_) =>
                            ref.read(authControllerProvider.notifier).clearError(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isCodeSent = false;
                                _otpController.clear();
                              });
                            },
                            child: const Text(
                              'Change Phone Number',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: authState.isLoading ? null : _handleSendOtp,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AuthButton(
                        text: 'Verify and Continue',
                        isLoading: authState.isLoading,
                        onPressed: _handleVerifyOtp,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Back to Email sign in
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth/sign-in'),
                  child: Text(
                    'Use Email Instead',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
