import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/safetrip_models.dart';
import '../controllers/safety_controllers.dart';
import '../controllers/safetrip_controller.dart';
import '../widgets/companion_review_dialog.dart';
import '../widgets/location_sharing_dialog.dart';
import '../widgets/need_help_dialog.dart';

/// Screen 03: SafeTrip Active Experience.
/// Signature screen for SafeMate real-time journey safety.
/// Universal Engineering Rule #11 & Rule #43: Calm, reassuring, human, premium, trustworthy.
class SafeTripActiveScreen extends ConsumerStatefulWidget {
  final String journeyId;

  const SafeTripActiveScreen({super.key, required this.journeyId});

  @override
  ConsumerState<SafeTripActiveScreen> createState() =>
      _SafeTripActiveScreenState();
}

class _SafeTripActiveScreenState extends ConsumerState<SafeTripActiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(safeTripControllerProvider.notifier).loadSafeTrip(widget.journeyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(safeTripControllerProvider);
    final trip = state.currentTrip;

    if (state.isLoading && trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('SafeTrip')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('SafeTrip journey not found.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      );
    }

    final contactsState = ref.watch(trustedContactsControllerProvider);
    final trustedContact = contactsState.contacts
        .where((c) => c.id == trip.trustedContactId)
        .firstOrNull;

    final isSharingLocation = state.activeLocationSession != null &&
        state.activeLocationSession!.isActive;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('SafeTrip Active'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Journey Copilot',
            onPressed: () => context.push('/trips/${trip.tripId}/copilot'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Journey Timeline',
            onPressed: () => context.push('/safetrip/${trip.id}/timeline'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Active Journey Header Card
            _buildActiveHeaderCard(context, trip),
            const SizedBox(height: 18),

            // Next Check-in Card (with prominent "I'm OK" button)
            _buildCheckinCard(context, trip),
            const SizedBox(height: 18),

            // Location Sharing Card
            _buildLocationSharingCard(context, isSharingLocation),
            const SizedBox(height: 18),

            // Trusted Contact Card
            _buildTrustedContactCard(context, trustedContact),
            const SizedBox(height: 24),

            // Action Buttons: Need Help & Arrived
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline, color: AppColors.secondaryTeal),
                    label: const Text('Need Help?'),
                    onPressed: () => _openNeedHelp(context, trustedContact),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('I\'ve Arrived'),
                    onPressed: () => _confirmArrivalDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stop SafeTrip option
            Center(
              child: TextButton(
                onPressed: () => _confirmStopSafeTrip(context),
                child: const Text(
                  'Stop SafeTrip',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveHeaderCard(BuildContext context, SafeTrip trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryTeal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'JOURNEY ACTIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.secondaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Journey Destination',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trip.tripId,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expected Arrival', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    trip.expectedArrivalTime.toLocal().toString().substring(11, 16),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Check-in Interval', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    'Every ${trip.checkinIntervalMinutes} min',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinCard(BuildContext context, SafeTrip trip) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nextDeadline = trip.nextCheckinDeadline;
    final minutesLeft = nextDeadline != null
        ? nextDeadline.difference(DateTime.now()).inMinutes
        : trip.checkinIntervalMinutes;

    final displayMinutes = minutesLeft > 0 ? minutesLeft : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Next Check-in',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  displayMinutes > 0 ? 'Due in $displayMinutes min' : 'Due Now',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trip.lastCheckinAt != null
                ? 'Last confirmed: ${trip.lastCheckinAt!.toLocal().toString().substring(11, 16)}'
                : 'Initial check-in pending',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check, size: 22),
            label: const Text(
              'I\'M OK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await ref.read(safeTripControllerProvider.notifier).recordCheckin();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ You are marked safe for this check-in.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSharingCard(BuildContext context, bool isSharing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            color: isSharing ? AppColors.secondaryTeal : Colors.grey,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approximate Location',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  isSharing ? 'Shared (~20km area) with contact' : 'Sharing is currently OFF',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSharing ? AppColors.secondaryTeal : Colors.grey,
                    fontWeight: isSharing ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: AppColors.secondaryTeal),
            ),
            onPressed: () => _openLocationDialog(context),
            child: Text(isSharing ? 'Manage' : 'Share'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedContactCard(BuildContext context, dynamic contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.secondaryTeal, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trusted Contact Connected',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  contact != null
                      ? '${contact.contactName} (${contact.relationship})'
                      : 'Authorized emergency contact on file',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openNeedHelp(BuildContext context, dynamic contact) {
    showDialog(
      context: context,
      builder: (ctx) => NeedHelpDialog(
        trustedContactName: contact?.contactName,
        trustedContactPhone: contact?.phoneNumber,
        onShareStatus: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status update shared with trusted contact.')),
          );
        },
      ),
    );
  }

  void _openLocationDialog(BuildContext context) {
    final session = ref.read(safeTripControllerProvider).activeLocationSession;
    showDialog(
      context: context,
      builder: (ctx) => LocationSharingDialog(
        currentSession: session,
        onStart: (mode, duration) {
          ref.read(safeTripControllerProvider.notifier).startLocationSharing(
                mode: mode,
                duration: duration,
              );
        },
        onStop: () {
          ref.read(safeTripControllerProvider.notifier).stopLocationSharing();
        },
      ),
    );
  }

  void _confirmArrivalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Arrival'),
        content: const Text(
          'Confirm that you have arrived safely at your destination?\n\n'
          '• Your trusted contact will receive an arrival update.\n'
          '• Temporary location sharing will stop automatically.\n'
          '• You can leave a structured companion review.',
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
              _handleConfirmArrival();
            },
            child: const Text('Yes, I\'ve Arrived'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmArrival() async {
    final success = await ref
        .read(safeTripControllerProvider.notifier)
        .confirmArrival();

    if (!mounted) return;
    if (success) {
      // Prompt companion review if companion attached
      final companionId =
          ref.read(safeTripControllerProvider).currentTrip?.companionUserId;
      if (companionId != null) {
        await _showCompanionReviewPrompt(companionId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrival confirmed safely! Journey complete.'),
          ),
        );
        context.go('/home');
      }
    }
  }

  Future<void> _showCompanionReviewPrompt(String companionId) async {
    final ownerId = ref.read(safeTripControllerProvider).currentTrip?.ownerId ?? '';
    await showDialog(
      context: context,
      builder: (ctx) => CompanionReviewDialog(
        tripId: widget.journeyId,
        reviewerId: ownerId,
        revieweeId: companionId,
        revieweeName: 'Travel Companion',
      ),
    );
    if (!mounted) return;
    context.go('/home');
  }

  void _confirmStopSafeTrip(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop SafeTrip?'),
        content: const Text(
          'Stopping SafeTrip will cancel scheduled check-in reminders and immediately terminate location sharing.\n\nAre you sure you want to stop this journey early?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Active'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleStopSafeTrip();
            },
            child: const Text('Stop SafeTrip'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStopSafeTrip() async {
    await ref
        .read(safeTripControllerProvider.notifier)
        .cancelJourney('Cancelled by traveler');
    if (!mounted) return;
    context.go('/home');
  }
}
