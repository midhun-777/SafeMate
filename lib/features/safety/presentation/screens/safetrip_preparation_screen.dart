import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../trips/domain/models/trip.dart';
import '../../../trips/presentation/controllers/trips_list_controller.dart';
import '../../domain/models/safetrip_models.dart';
import '../controllers/safety_controllers.dart';
import '../controllers/safetrip_controller.dart';

/// Screen 01 & 02: SafeTrip Preparation & Explicit Activation Consent.
/// Universal Engineering Rule #11 & Rule #10: Consent must be explicit, transparent, and auditable.
class SafeTripPreparationScreen extends ConsumerStatefulWidget {
  final String tripId;

  const SafeTripPreparationScreen({super.key, required this.tripId});

  @override
  ConsumerState<SafeTripPreparationScreen> createState() =>
      _SafeTripPreparationScreenState();
}

class _SafeTripPreparationScreenState
    extends ConsumerState<SafeTripPreparationScreen> {
  bool _shareStatusWithContact = true;
  bool _shareApproximateLocation = false;
  bool _sendCheckinReminders = true;
  String? _selectedContactId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final tripsState = ref.read(tripsListControllerProvider);
    final trip = tripsState.trips.where((t) => t.id == widget.tripId).firstOrNull;

    if (trip != null) {
      await ref.read(safeTripControllerProvider.notifier).loadOrCreateSafeTripForTrip(
            trip: trip,
          );
    }

    // Pre-select first active trusted contact if available
    final contactsState = ref.read(trustedContactsControllerProvider);
    if (contactsState.contacts.isNotEmpty) {
      setState(() {
        _selectedContactId = contactsState.contacts.first.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsState = ref.watch(tripsListControllerProvider);
    final trip = tripsState.trips.where((t) => t.id == widget.tripId).firstOrNull;

    final safeTripState = ref.watch(safeTripControllerProvider);
    final contactsState = ref.watch(trustedContactsControllerProvider);

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('SafeTrip Preparation')),
        body: const Center(child: Text('Journey information not found.')),
      );
    }

    final selectedContact = contactsState.contacts
        .where((c) => c.id == _selectedContactId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeTrip Preparation'),
      ),
      body: safeTripState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Journey Header Summary Card
                  _buildJourneySummaryCard(context, trip),
                  const SizedBox(height: 20),

                  // Trusted Contact Card
                  _buildTrustedContactCard(context, selectedContact, contactsState.contacts),
                  const SizedBox(height: 20),

                  // Transparent Consent Checklist
                  _buildConsentSection(context),
                  const SizedBox(height: 20),

                  // Transparency Policy Box
                  _buildTransparencyBox(context),
                  const SizedBox(height: 24),

                  // Activate Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text(
                      'Activate SafeTrip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showActivationConfirmation(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Return to Trip Details'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildJourneySummaryCard(BuildContext context, Trip trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: AppColors.secondaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${trip.origin} → ${trip.destination}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Departure', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      trip.startDate.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Expected Arrival', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      trip.endDate.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustedContactCard(
    BuildContext context,
    dynamic selectedContact,
    List<dynamic> allContacts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_pin_outlined, color: AppColors.secondaryTeal),
                SizedBox(width: 8),
                Text(
                  'Designated Trusted Contact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selectedContact != null) ...[
              Text(
                '${selectedContact.contactName} (${selectedContact.relationship})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                selectedContact.phoneNumber,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else ...[
              const Text(
                'No trusted contact selected yet.',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
              TextButton(
                onPressed: () => context.push('/safety/trusted-contacts'),
                child: const Text('Add Trusted Contact in Safety Center'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConsentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sharing & Safety Permissions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose exactly what SafeMate shares during your journey:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Consent 1: Status sharing
        SwitchListTile(
          value: _shareStatusWithContact,
          activeThumbColor: AppColors.secondaryTeal,
          title: const Text(
            'Share journey status with trusted contact',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Notifies contact when SafeTrip starts, check-ins succeed, and when you arrive.',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (val) => setState(() => _shareStatusWithContact = val),
        ),

        // Consent 2: Approximate Location
        SwitchListTile(
          value: _shareApproximateLocation,
          activeThumbColor: AppColors.secondaryTeal,
          title: const Text(
            'Share approximate location (~20km)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Shares approximate transit region with trusted contact only while trip is active.',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (val) => setState(() => _shareApproximateLocation = val),
        ),

        // Consent 3: Reminders
        SwitchListTile(
          value: _sendCheckinReminders,
          activeThumbColor: AppColors.secondaryTeal,
          title: const Text(
            'Send periodic check-in reminders',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Prompt you at regular intervals with calm "I\'m OK" check-in notifications.',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (val) => setState(() => _sendCheckinReminders = val),
        ),
      ],
    );
  }

  Widget _buildTransparencyBox(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: AppColors.secondaryTeal),
              SizedBox(width: 8),
              Text(
                'SafeTrip Privacy Promise',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bulletPoint('WHAT: Journey status & optional approximate area.'),
          _bulletPoint('WITH WHOM: Only your designated trusted contact.'),
          _bulletPoint('WHEN: Starts upon explicit activation, ends automatically on arrival.'),
          _bulletPoint('CONTROL: You can revoke location sharing or stop SafeTrip at any time.'),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _showActivationConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm SafeTrip Activation'),
        content: Text(
          'You are activating SafeTrip for this journey.\n\n'
          '• Status Sharing: ${_shareStatusWithContact ? "Enabled" : "Off"}\n'
          '• Approximate Location: ${_shareApproximateLocation ? "Enabled (~20km)" : "Off"}\n'
          '• Check-in Reminders: ${_sendCheckinReminders ? "Enabled" : "Off"}\n\n'
          'You remain in complete control and can stop sharing whenever you wish.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.secondaryTeal),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleActivateSafeTrip();
            },
            child: const Text('Activate Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleActivateSafeTrip() async {
    final consent = JourneyConsent(
      shareStatusWithTrustedContact: _shareStatusWithContact,
      shareApproximateLocation: _shareApproximateLocation,
      sendCheckinReminders: _sendCheckinReminders,
      consentedAt: DateTime.now(),
    );

    final success = await ref
        .read(safeTripControllerProvider.notifier)
        .activateSafeTrip(consent: consent);

    if (!mounted) return;
    if (success) {
      final journeyId =
          ref.read(safeTripControllerProvider).currentTrip?.id;
      if (journeyId != null) {
        context.pushReplacement('/safetrip/$journeyId');
      }
    }
  }
}
