/// Detailed "Why this match?" screen displaying explainable scoring components and mismatch notes.
/// Universal Engineering Rule #6: Explainable recommendations, respectful language, zero secret formulas.
/// Universal Engineering Rule #13: Calm, visual, trustworthy design.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/core/services/analytics_service.dart';
import 'package:safemate/features/auth/presentation/controllers/auth_controller.dart';
import 'package:safemate/features/connections/presentation/widgets/connect_request_dialog.dart';
import '../../domain/models/compatibility_score.dart';
import '../../domain/models/match_result.dart';
import '../controllers/match_discovery_controller.dart';

class MatchDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String matchId;
  final MatchResult? initialMatch;

  const MatchDetailScreen({
    super.key,
    required this.tripId,
    required this.matchId,
    this.initialMatch,
  });

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent('why_match_opened', parameters: {
        'trip_id': widget.tripId,
        'match_id': widget.matchId,
      });
    });
  }

  String _formatDate(DateTime date) => DateFormat('EEE, MMM d, yyyy').format(date);

  Color _getScoreColor(MatchQualityBand band) {
    switch (band) {
      case MatchQualityBand.excellent:
        return AppColors.safetyActive;
      case MatchQualityBand.strong:
        return AppColors.primary;
      case MatchQualityBand.good:
        return AppColors.secondary;
      case MatchQualityBand.low:
        return AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(matchDiscoveryControllerProvider(widget.tripId));

    // Find the match in state or use initially supplied match
    final match = widget.initialMatch ??
        state.matches.cast<dynamic>().firstWhere(
              (m) => m.id == widget.matchId,
              orElse: () => null,
            );

    if (match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match Details')),
        body: const Center(child: Text('Match information unavailable.')),
      );
    }

    final candidate = match.candidate;
    final score = match.score;
    final scoreColor = _getScoreColor(score.band);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Why This Match?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Compatibility Score Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Text(
                        '${score.total}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${score.band.label} Estimate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score.band.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Traveler Identity Card (Passport summary)
              _buildSectionCard(
                title: 'Traveler Passport',
                isDark: isDark,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: candidate.avatarUrl != null
                          ? NetworkImage(candidate.avatarUrl!)
                          : null,
                      child: candidate.avatarUrl == null
                          ? Text(
                              candidate.displayName.isNotEmpty
                                  ? candidate.displayName.substring(0, 1).toUpperCase()
                                  : 'T',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                candidate.displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (candidate.isIdentityVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified, size: 16, color: AppColors.safetyActive),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            candidate.homeCity.isNotEmpty
                                ? candidate.homeCity
                                : 'Verified SafeMate Traveler',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.safetyActive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Trust Score: ${candidate.trustScore}/100',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.safetyActive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Component Compatibility Breakdown
              _buildSectionCard(
                title: 'Compatibility Breakdown',
                isDark: isDark,
                child: Column(
                  children: [
                    _buildScoreBar('Route & Destination (25%)', score.components.routeScore, isDark),
                    _buildScoreBar('Travel Dates (20%)', score.components.dateScore, isDark),
                    _buildScoreBar('Transport Mode (10%)', score.components.transportScore, isDark),
                    _buildScoreBar('Budget Compatibility (10%)', score.components.budgetScore, isDark),
                    _buildScoreBar('Journey Purpose (10%)', score.components.purposeScore, isDark),
                    _buildScoreBar('Travel Style & Pace (10%)', score.components.styleScore, isDark),
                    _buildScoreBar('Companion Criteria (10%)', score.components.preferenceScore, isDark),
                    _buildScoreBar('Daily Schedule (5%)', score.components.scheduleScore, isDark),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Positive Match Reasons
              if (match.reasons.isNotEmpty)
                _buildSectionCard(
                  title: 'Why You Match',
                  isDark: isDark,
                  child: Column(
                    children: match.reasons.map<Widget>((reason) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reason.type.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reason.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reason.explanation,
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
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              if (match.mismatches.isNotEmpty) ...[
                const SizedBox(height: 20),
                // 5. Transparent Differences
                _buildSectionCard(
                  title: 'Some Preferences Differ',
                  isDark: isDark,
                  child: Column(
                    children: match.mismatches.map<Widget>((diff) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                diff.note,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 6. Journey Details Comparison Card
              _buildSectionCard(
                title: 'Journey Comparison',
                isDark: isDark,
                child: Column(
                  children: [
                    _buildDetailRow('Origin', candidate.origin, isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Destination', candidate.destination, isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Departure', _formatDate(candidate.startDate), isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Return', _formatDate(candidate.endDate), isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Transport', candidate.trip.transportMode.label, isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Budget Tier', candidate.trip.budgetTier.label, isDark),
                    const Divider(height: 16),
                    _buildDetailRow('Trip Purpose', candidate.trip.tripPurpose.label, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            key: const Key('match_detail_connect_button'),
            onPressed: () {
              final authState = ref.read(authControllerProvider);
              final currentUserId = authState.profile?.id ?? authState.session?.userId ?? '';
              ConnectRequestDialog.show(
                context,
                candidateUserId: candidate.candidateUserId,
                candidateName: candidate.displayName,
                destination: candidate.destination,
                userTripId: widget.tripId,
                candidateTripId: candidate.candidateTripId,
                currentUserId: currentUserId,
              );
            },
            icon: const Icon(Icons.person_add_outlined),
            label: Text('Connect with ${candidate.displayName}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                '$score%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 80
                    ? AppColors.safetyActive
                    : score >= 60
                        ? AppColors.primary
                        : AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }
}
