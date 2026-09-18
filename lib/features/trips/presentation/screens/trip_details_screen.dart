/// Full trip details screen with lifecycle management controls.
/// Universal Engineering Rule #11: Deterministic state machine and safe cancellation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_button.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import '../../domain/models/trip.dart';
import '../../domain/models/trip_status.dart';
import '../../domain/models/trip_visibility.dart';
import '../controllers/trip_creation_controller.dart';
import '../controllers/trips_list_controller.dart';
import '../widgets/trip_lifecycle_action_dialog.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  final String tripId;
  const TripDetailsScreen({super.key, required this.tripId});

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  Trip? _trip;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrip();
  }

  Future<void> _fetchTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final repo = ref.read(tripRepositoryProvider);
    try {
      final trip = await repo.getTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _trip = trip;
          _isLoading = false;
          if (trip == null) {
            _errorMessage = 'Journey not found.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load journey details.';
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.draft:
        return Colors.orange;
      case TripStatus.published:
        return AppColors.primary;
      case TripStatus.paused:
        return Colors.amber.shade700;
      case TripStatus.cancelled:
        return AppColors.error;
      case TripStatus.completed:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final listNotifier = ref.read(tripsListControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _trip?.destination.isNotEmpty == true
              ? 'Trip to ${_trip!.destination}'
              : 'Journey Details',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null || _trip == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage ?? 'Journey not found.',
                          style: TextStyle(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('Back to My Trips'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(context, _trip!, isDark, listNotifier),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Trip trip,
    bool isDark,
    TripsListController listNotifier,
  ) {
    final statusColor = _getStatusColor(trip.status);
    final prefs = trip.preferences;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Visibility Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS: ${trip.status.label.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.status.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                if (trip.visibility == TripVisibility.private)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Text(
                      '🔒 Private',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Title & Route
          Text(
            trip.title.isNotEmpty ? trip.title : 'Trip to ${trip.destination}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trip.origin} → ${trip.destination}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_formatDate(trip.startDate)} → ${_formatDate(trip.endDate)} (${trip.durationLabel})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          if (trip.isPublished || trip.isPaused) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/trips/${trip.id}/matches'),
                icon: const Icon(Icons.people_outline),
                label: const Text(
                  'Find Travel Companions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/trips/${trip.id}/safetrip-prep'),
                icon: const Icon(Icons.shield_outlined, color: AppColors.secondaryTeal),
                label: const Text(
                  'SafeTrip Real-Time Safety',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondaryTeal),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.secondaryTeal, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/trips/${trip.id}/copilot?destination=${Uri.encodeComponent(trip.destination)}',
                ),
                icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                label: const Text(
                  'Journey Copilot (AI)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Overview Details
          _buildCard(
            title: 'Journey Attributes',
            isDark: isDark,
            child: Column(
              children: [
                _buildRow('Transport Mode', trip.transportMode.label, isDark),
                const SizedBox(height: 8),
                _buildRow('Budget Tier', trip.budgetTier.label, isDark),
                if (trip.estimatedBudget != null) ...[
                  const SizedBox(height: 8),
                  _buildRow('Estimated Budget', '${trip.currency} ${trip.estimatedBudget!.toStringAsFixed(0)}', isDark),
                ],
                const SizedBox(height: 8),
                _buildRow('Trip Purpose', trip.tripPurpose.label, isDark),
                const SizedBox(height: 8),
                _buildRow('Max Companions', '${trip.maxCompanions} travelers', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trip Vibes
          if (trip.tripStyles.isNotEmpty) ...[
            _buildCard(
              title: 'Trip Vibes',
              isDark: isDark,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trip.tripStyles.map((code) {
                  final vibe = TripVibe.fromCode(code);
                  return Chip(
                    label: Text(vibe?.label ?? code),
                    backgroundColor: AppColors.primaryContainer,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Companion Criteria
          if (prefs != null) ...[
            _buildCard(
              title: 'Companion Preferences',
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow('Travel Pace', prefs.travelPace.label, isDark),
                  const SizedBox(height: 8),
                  _buildRow('Social Dynamic', prefs.socialEnergy.label, isDark),
                  const SizedBox(height: 8),
                  _buildRow('Accommodation', prefs.accommodationPreference.label, isDark),
                  if (prefs.activityInterests.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildRow('Shared Activities', prefs.activityInterests.join(', '), isDark),
                  ],
                  if (prefs.dietaryPreferences.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildRow('Diet Openness', prefs.dietaryPreferences.join(', '), isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Lifecycle Action Controls
          _buildLifecycleActions(context, trip, listNotifier),
        ],
      ),
    );
  }

  Widget _buildLifecycleActions(
    BuildContext context,
    Trip trip,
    TripsListController listNotifier,
  ) {
    if (trip.isCancelled || trip.isCompleted) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (trip.isDraft) ...[
          AuthButton(
            text: 'Continue Editing Draft',
            onPressed: () {
              ref.read(tripCreationControllerProvider.notifier).loadTrip(trip.id);
              context.go('/trips/create');
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final confirmed = await TripLifecycleActionDialog.show(
                context,
                title: 'Delete Draft Journey?',
                content: 'Are you sure you want to permanently delete this unpublished draft?',
                confirmLabel: 'Delete Draft',
                isDestructive: true,
              );
              if (confirmed == true) {
                await listNotifier.deleteDraft(trip.id);
                if (context.mounted) context.go('/home');
              }
            },
            child: const Text('Delete Draft'),
          ),
        ],
        if (trip.isPublished) ...[
          AuthButton(
            text: 'Pause Companion Matching',
            onPressed: () async {
              final ok = await listNotifier.pauseTrip(trip.id);
              if (ok) _fetchTrip();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final ok = await listNotifier.completeTrip(trip.id);
              if (ok) _fetchTrip();
            },
            child: const Text('Mark Journey as Completed'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final confirmed = await TripLifecycleActionDialog.show(
                context,
                title: 'Cancel Journey?',
                content: 'Are you sure you want to cancel this journey? Historical record will be safely preserved.',
                confirmLabel: 'Cancel Journey',
                isDestructive: true,
              );
              if (confirmed == true) {
                final ok = await listNotifier.cancelTrip(trip.id);
                if (ok) _fetchTrip();
              }
            },
            child: const Text('Cancel Journey'),
          ),
        ],
        if (trip.isPaused) ...[
          AuthButton(
            text: 'Resume Companion Matching',
            onPressed: () async {
              final ok = await listNotifier.resumeTrip(trip.id);
              if (ok) _fetchTrip();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () async {
              final confirmed = await TripLifecycleActionDialog.show(
                context,
                title: 'Cancel Journey?',
                content: 'Are you sure you want to cancel this journey?',
                confirmLabel: 'Cancel Journey',
                isDestructive: true,
              );
              if (confirmed == true) {
                final ok = await listNotifier.cancelTrip(trip.id);
                if (ok) _fetchTrip();
              }
            },
            child: const Text('Cancel Journey'),
          ),
        ],
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
