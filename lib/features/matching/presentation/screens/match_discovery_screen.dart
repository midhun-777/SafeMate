/// Main companion discovery dashboard for a published journey.
/// Universal Engineering Rule #13: Calm, visual, trustworthy design.
/// Universal Engineering Rule #14: Responsive states (loading, empty, error, content).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:safemate/features/trips/domain/models/trip_transport.dart';
import '../controllers/match_discovery_controller.dart';
import '../widgets/match_card.dart';
import '../widgets/match_empty_state.dart';

class MatchDiscoveryScreen extends ConsumerStatefulWidget {
  final String tripId;

  const MatchDiscoveryScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<MatchDiscoveryScreen> createState() => _MatchDiscoveryScreenState();
}

class _MatchDiscoveryScreenState extends ConsumerState<MatchDiscoveryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(matchDiscoveryControllerProvider(widget.tripId).notifier).loadMoreMatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(matchDiscoveryControllerProvider(widget.tripId));
    final notifier = ref.read(matchDiscoveryControllerProvider(widget.tripId).notifier);
    final targetTrip = state.targetTrip;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Companion Discovery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalculate Matches',
            onPressed: () => notifier.loadMatches(refresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Journey Context Banner
            if (targetTrip != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flight_takeoff, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${targetTrip.origin} → ${targetTrip.destination}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Finding compatible travelers for your journey',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Filter Chips Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: const Text('All (60%+)'),
                    selected: state.minScoreFilter == 60,
                    onSelected: (_) => notifier.setMinScoreFilter(60),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Strong (75%+)'),
                    selected: state.minScoreFilter == 75,
                    onSelected: (_) => notifier.setMinScoreFilter(75),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Excellent (90%+)'),
                    selected: state.minScoreFilter == 90,
                    onSelected: (_) => notifier.setMinScoreFilter(90),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      state.transportFilter?.label ?? 'Transport',
                    ),
                    selected: state.transportFilter != null,
                    onSelected: (_) {
                      if (state.transportFilter != null) {
                        notifier.setTransportFilter(null);
                      } else {
                        // Toggle through popular transit mode
                        notifier.setTransportFilter(TripTransport.train);
                      }
                    },
                  ),
                ],
              ),
            ),

            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: AuthErrorBanner(message: state.errorMessage!),
              ),

            // Content Area
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => notifier.loadMatches(refresh: true),
                      child: state.filteredMatches.isEmpty
                          ? MatchEmptyState(
                              onRefresh: () => notifier.loadMatches(refresh: true),
                              onAdjustFilters: () => notifier.clearFilters(),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: state.filteredMatches.length +
                                  (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= state.filteredMatches.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                }

                                final match = state.filteredMatches[index];
                                return MatchCard(
                                  match: match,
                                  onTap: () {
                                    context.push('/trips/${widget.tripId}/matches/${match.id}');
                                  },
                                  onDismiss: () {
                                    notifier.dismissMatch(match.id);
                                  },
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
