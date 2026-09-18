import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/services/safety_code.dart';

/// Pre-Journey Safety Screen with 6-point checklist & cryptographic meetup code exchange.
/// Universal Engineering Rule #11: Safety is a core product capability.
class PreJourneySafetyScreen extends StatefulWidget {
  final String? tripId;

  const PreJourneySafetyScreen({super.key, this.tripId});

  @override
  State<PreJourneySafetyScreen> createState() => _PreJourneySafetyScreenState();
}

class _PreJourneySafetyScreenState extends State<PreJourneySafetyScreen> {
  // 6-point checklist items
  final List<bool> _checklist = [false, false, false, false, false, false];

  static const List<Map<String, String>> _checklistItems = [
    {
      'title': '1. Verified Profile Check',
      'desc': 'Ensure companion has at least Phone or Identity verification badge active.',
    },
    {
      'title': '2. Public Daytime Meeting Point',
      'desc': 'Agree to meet inside a well-lit public transit station, gate, or information desk.',
    },
    {
      'title': '3. Trusted Contacts Informed',
      'desc': 'Verify your safety contacts are configured and notified of your departure.',
    },
    {
      'title': '4. Separate Bookings Maintained',
      'desc': 'Confirm you hold your own independent travel tickets and reservations.',
    },
    {
      'title': '5. Independent Emergency Backup',
      'desc': 'Have backup local transport plans, local emergency numbers, and a charged phone.',
    },
    {
      'title': '6. Secure Meetup Code Exchange',
      'desc': 'Exchange and verify 6-digit meetup codes upon meeting in person before departing.',
    },
  ];

  SafetyMeetupCode? _generatedCode;
  final _verifyCodeCtrl = TextEditingController();
  bool? _isCodeValid;

  @override
  void initState() {
    super.initState();
    _generateNewCode();
  }

  @override
  void dispose() {
    _verifyCodeCtrl.dispose();
    super.dispose();
  }

  void _generateNewCode() {
    setState(() {
      _generatedCode = SafetyCodeService.generateCode();
      _isCodeValid = null;
    });
  }

  void _verifyCompanionCode() {
    final entered = _verifyCodeCtrl.text.trim();
    if (entered.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a full 6-digit code')),
      );
      return;
    }

    if (_generatedCode == null) return;

    final isValid = SafetyCodeService.verifyCode(
      enteredCode: entered,
      meetupCode: _generatedCode!,
    );

    setState(() {
      _isCodeValid = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Journey Safety Check'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meetup Code Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Meetup Verification Code',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When you meet your companion in person, show them this code or verify theirs to ensure genuine identity.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_generatedCode != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _generatedCode!.code,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expires in 24 hours',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generatedCode!.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Meetup code copied to clipboard')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy Code'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _generateNewCode,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('New Code'),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Text(
                    'Verify Companion Code:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _verifyCodeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            hintText: 'Enter 6-digit code',
                            counterText: '',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _verifyCompanionCode,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Verify'),
                      ),
                    ],
                  ),
                  if (_isCodeValid != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_isCodeValid! ? AppColors.safetyActive : AppColors.safetyAlert)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_isCodeValid! ? AppColors.safetyActive : AppColors.safetyAlert)
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isCodeValid! ? Icons.check_circle : Icons.error_outline,
                            color: _isCodeValid! ? AppColors.safetyActive : AppColors.safetyAlert,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isCodeValid!
                                  ? 'Code verified! Companion identity confirmed.'
                                  : 'Code mismatch. Please double check with your companion.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isCodeValid!
                                    ? AppColors.safetyActive
                                    : AppColors.safetyAlert,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 6-point checklist
          Text(
            'Pre-Journey Safety Checklist',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Review these steps before departing together.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryLight),
          ),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: List.generate(_checklistItems.length, (index) {
                final item = _checklistItems[index];
                return CheckboxListTile(
                  value: _checklist[index],
                  activeColor: AppColors.primary,
                  title: Text(
                    item['title']!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    item['desc']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _checklist[index] = val ?? false;
                    });
                  },
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // All items checked celebration / ready button
          FilledButton.icon(
            onPressed: _checklist.every((c) => c)
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All safety checks confirmed! Have a wonderful and safe journey.'),
                        backgroundColor: AppColors.safetyActive,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.verified, size: 20),
            label: Text(
              _checklist.every((c) => c)
                  ? 'All Checks Completed — Ready to Travel'
                  : 'Complete All 6 Checks to Proceed',
            ),
          ),
        ],
      ),
    );
  }
}
