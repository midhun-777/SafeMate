import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/sync/conflict_resolution_controller.dart';
import '../../../../core/sync/presentation/conflict_banner.dart';
import '../../../../core/sync/presentation/conflict_review_screen.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/domain/models/travel_personality.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/trip_creation_controller.dart';
import '../controllers/trips_list_controller.dart';
import '../controllers/trips_list_state.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_empty_state.dart';
import '../widgets/trip_lifecycle_action_dialog.dart';

/// Foundation authenticated route boundary screen.
/// Displays traveler identity, profile completion status, and journeys with lifecycle management.
class TripsHomeScreen extends ConsumerStatefulWidget {
  const TripsHomeScreen({super.key});

  @override
  ConsumerState<TripsHomeScreen> createState() => _TripsHomeScreenState();
}

class _TripsHomeScreenState extends ConsumerState<TripsHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripsListControllerProvider.notifier).loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final tripsState = ref.watch(tripsListControllerProvider);
    final tripsNotifier = ref.read(tripsListControllerProvider.notifier);

    final authProfile = authState.profile;
    final profile = (authProfile != null && authProfile.displayName.isNotEmpty)
        ? authProfile
        : profileState.profile;
    final session = authState.session;
    final completion = profileState.completion;

    final displayName = profile.displayName.isNotEmpty && profile.displayName != 'Traveler'
        ? profile.displayName
        : (session?.email.isNotEmpty == true
            ? session!.email.split('@').first
            : 'Traveler');

    final trustScore = profile.trustScore;
    final currentTrips = tripsState.currentTabTrips;
    final userId = authState.profile?.id ?? authState.session?.userId ?? '';
    final conflictsAsync = userId.isNotEmpty
        ? ref.watch(pendingConflictsProvider(userId))
        : const AsyncValue.data(<ConflictPresentationModel>[]);
    final conflicts = conflictsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafeMate',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            key: const Key('home_safety_center_button'),
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Safety Center',
            onPressed: () => context.push('/safety'),
          ),
          IconButton(
            key: const Key('home_connections_button'),
            icon: const Icon(Icons.people_outline),
            tooltip: 'Connections',
            onPressed: () => context.push('/connections'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Profile',
            onPressed: () => context.go('/profile/view'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(tripCreationControllerProvider.notifier).reset();
          context.push('/trips/create');
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Plan Journey'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => tripsNotifier.loadTrips(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Greeting & Trust Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $displayName',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.homeCity?.isNotEmpty == true
                                ? profile.homeCity!
                                : (session?.email.isNotEmpty == true
                                    ? session!.email
                                    : (session?.phone ?? 'Verified Traveler')),
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      key: const Key('home_trust_badge'),
                      onTap: () {
                        final uid = authState.profile?.id ?? authState.session?.userId;
                        if (uid != null) {
                          context.push('/profile/trust?userId=$uid');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Trust: $trustScore',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (conflicts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ConflictBanner(
                    conflictCount: conflicts.length,
                    onReviewPressed: () {
                      final controller = ref.read(conflictResolutionControllerProvider);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConflictReviewScreen(
                            conflicts: conflicts,
                            userId: userId,
                            controller: controller,
                            onAllResolved: () {
                              ref.invalidate(pendingConflictsProvider(userId));
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Profile Completion Banner (Phase 5 requirement)
                Container(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Traveler Identity: ${completion.percentage}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => context.go('/profile/setup'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              completion.isFullyComplete ? 'Edit Profile' : 'Complete Setup',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (completion.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariantLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      if (profile.travelStyles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: profile.travelStyles.take(3).map((code) {
                            final vibe = TripVibe.fromCode(code);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                vibe?.label ?? code,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onPrimaryContainer,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Journeys Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Journeys',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage your trips and companion criteria.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Segmented tab bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabChip(
                        label: 'Upcoming (${tripsState.upcomingTrips.length})',
                        isSelected: tripsState.currentTab == TripListTab.upcoming,
                        onTap: () => tripsNotifier.setTab(TripListTab.upcoming),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        label: 'Drafts (${tripsState.draftTrips.length})',
                        isSelected: tripsState.currentTab == TripListTab.drafts,
                        onTap: () => tripsNotifier.setTab(TripListTab.drafts),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        label: 'Past (${tripsState.pastTrips.length})',
                        isSelected: tripsState.currentTab == TripListTab.past,
                        onTap: () => tripsNotifier.setTab(TripListTab.past),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        label: 'Cancelled (${tripsState.cancelledTrips.length})',
                        isSelected: tripsState.currentTab == TripListTab.cancelled,
                        onTap: () => tripsNotifier.setTab(TripListTab.cancelled),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Error message banner
                if (tripsState.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),

                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tripsState.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => tripsNotifier.loadTrips(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Content Area: Loading / Empty / List
                if (tripsState.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (currentTrips.isEmpty)
                  _buildEmptyStateForTab(tripsState.currentTab, context)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentTrips.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final trip = currentTrips[index];
                      return TripCard(
                        trip: trip,
                        onTap: () => context.push('/trips/${trip.id}'),
                        onEdit: () {
                          ref.read(tripCreationControllerProvider.notifier).loadTrip(trip.id);
                          context.push('/trips/create');
                        },

                        onPause: () => tripsNotifier.pauseTrip(trip.id),
                        onResume: () => tripsNotifier.resumeTrip(trip.id),
                        onCancel: () async {
                          final confirmed = await TripLifecycleActionDialog.show(
                            context,
                            title: 'Cancel Journey?',
                            content:
                                'Cancelling this journey will remove it from companion discovery while preserving your travel record.',
                            confirmLabel: 'Cancel Journey',
                            isDestructive: true,
                          );
                          if (confirmed == true) {
                            await tripsNotifier.cancelTrip(trip.id);
                          }
                        },
                        onComplete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Complete Journey?'),
                              content: const Text(
                                'Marking this journey as completed preserves it in your travel history.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Complete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await tripsNotifier.completeTrip(trip.id);
                          }
                        },
                        onDeleteDraft: () async {
                          final confirmed = await TripLifecycleActionDialog.show(
                            context,
                            title: 'Delete Draft Journey?',
                            content:
                                'Are you sure you want to delete this unpublished draft? This action cannot be undone.',
                            confirmLabel: 'Delete Draft',
                            isDestructive: true,
                          );
                          if (confirmed == true) {
                            await tripsNotifier.deleteDraft(trip.id);
                          }
                        },
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariantLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),

        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateForTab(TripListTab tab, BuildContext context) {
    switch (tab) {
      case TripListTab.upcoming:
        return TripEmptyState(
          icon: Icons.luggage_outlined,
          title: 'No upcoming journeys',
          description:
              'Plan a trip to discover compatible companions along your route and travel together safely.',
          actionLabel: 'Plan Journey',
          onAction: () {
            ref.read(tripCreationControllerProvider.notifier).reset();
            context.push('/trips/create');
          },
        );
      case TripListTab.drafts:
        return TripEmptyState(
          icon: Icons.edit_note_outlined,
          title: 'No saved drafts',
          description:
              'Draft journeys you start but do not publish will appear here for later editing.',
        );
      case TripListTab.past:
        return TripEmptyState(
          icon: Icons.history_outlined,
          title: 'No past journeys',
          description:
              'Completed journeys from your travels will be preserved here in your travel journal.',
        );
      case TripListTab.cancelled:
        return TripEmptyState(
          icon: Icons.cancel_outlined,
          title: 'No cancelled journeys',
          description: 'Trips you cancel are safely archived here for your records.',
        );
    }
  }
}


