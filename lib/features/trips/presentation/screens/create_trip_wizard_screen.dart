/// Multi-step trip creation wizard for SafeMate.
/// Universal Engineering Rule #13: Calm, visual, progressive disclosure.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_button.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import 'package:safemate/features/profile/presentation/widgets/multi_select_chip.dart';
import 'package:safemate/features/profile/presentation/widgets/preference_choice_card.dart';
import '../../domain/models/trip_budget.dart';
import '../../domain/models/trip_purpose.dart';
import '../../domain/models/trip_transport.dart';
import '../../domain/models/trip_visibility.dart';
import '../controllers/trip_creation_controller.dart';
import '../controllers/trip_creation_state.dart';
import '../widgets/trip_date_picker_card.dart';

class CreateTripWizardScreen extends ConsumerStatefulWidget {
  const CreateTripWizardScreen({super.key});

  @override
  ConsumerState<CreateTripWizardScreen> createState() => _CreateTripWizardScreenState();
}

class _CreateTripWizardScreenState extends ConsumerState<CreateTripWizardScreen> {
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  static const _availableActivities = [
    'Sightseeing', 'Hiking & Treks', 'Photography', 'Food Walks',
    'Museums', 'Beaches', 'Cafe Hopping', 'Nature Walks',
    'Road Trips', 'Local Markets', 'Festivals & Music', 'Architecture',
  ];

  static const _availableDiets = [
    'Vegetarian', 'Vegan', 'Halal', 'Kosher', 'Gluten-Free', 'No Restrictions',
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(tripCreationControllerProvider);
    _originController = TextEditingController(text: state.trip.origin);
    _destinationController = TextEditingController(text: state.trip.destination);
    _titleController = TextEditingController(text: state.trip.title);
    _notesController = TextEditingController(text: state.preferences.notes ?? '');
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncControllersWithState() {
    final state = ref.read(tripCreationControllerProvider);
    if (_originController.text != state.trip.origin) {
      _originController.text = state.trip.origin;
    }
    if (_destinationController.text != state.trip.destination) {
      _destinationController.text = state.trip.destination;
    }
    if (_titleController.text != state.trip.title) {
      _titleController.text = state.trip.title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(tripCreationControllerProvider);
    final notifier = ref.read(tripCreationControllerProvider.notifier);

    _syncControllersWithState();

    return PopScope(
      canPop: state.currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (state.currentStep > 0) {
          notifier.previousStep();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Plan Your Journey',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (state.currentStep > 0) {
                notifier.previousStep();
              } else {
                context.go('/home');
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: state.isSaving
                  ? null
                  : () async {
                      final router = GoRouter.of(context);
                      final ok = await notifier.saveDraft();
                      if (ok && mounted) {
                        router.go('/home');
                      }
                    },

              child: state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Draft',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: (state.currentStep + 1) / 7.0,
                backgroundColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),

              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: AuthErrorBanner(message: state.errorMessage!),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: _buildCurrentStep(state, notifier, isDark),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (state.currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => notifier.previousStep(),
                          child: const Text('Back'),
                        ),
                      ),
                    if (state.currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AuthButton(
                        text: state.currentStep == 6 ? 'Review Journey' : 'Continue',
                        onPressed: () {
                          if (state.currentStep == 6) {
                            context.go('/trips/review');
                          } else {
                            notifier.nextStep();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    switch (state.currentStep) {
      case 0:
        return _buildStep0Location(state, notifier, isDark);
      case 1:
        return _buildStep1Dates(state, notifier, isDark);
      case 2:
        return _buildStep2TransportAndBudget(state, notifier, isDark);
      case 3:
        return _buildStep3StyleAndPurpose(state, notifier, isDark);
      case 4:
        return _buildStep4CompanionPreferences(state, notifier, isDark);
      case 5:
        return _buildStep5PrivacyAndCompanions(state, notifier, isDark);
      case 6:
        return _buildStep6PreReview(state, notifier, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 0: Origin & Destination ---
  Widget _buildStep0Location(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '01',
          title: 'Where are you going?',
          subtitle: 'Choose your starting point and journey destination.',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        AuthTextField(
          controller: _originController,
          label: 'Starting From (Origin) *',
          hintText: 'e.g. Hyderabad, India',
          prefixIcon: const Icon(Icons.my_location_outlined),
          onChanged: (val) => notifier.setOrigin(val),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _destinationController,
          label: 'Going To (Destination) *',
          hintText: 'e.g. Goa, India',
          prefixIcon: const Icon(Icons.location_on_outlined),
          onChanged: (val) => notifier.setDestination(val),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _titleController,
          label: 'Trip Title (Optional)',
          hintText: 'e.g. Goa Monsoon Coastal Escape',
          prefixIcon: const Icon(Icons.edit_road_outlined),
          onChanged: (val) => notifier.setTitle(val),
        ),
      ],
    );
  }

  // --- Step 1: Dates ---
  Widget _buildStep1Dates(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '02',
          title: 'When are you travelling?',
          subtitle: 'Select departure and return dates for this journey.',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        TripDatePickerCard(
          startDate: state.trip.startDate,
          endDate: state.trip.endDate,
          durationDays: state.trip.durationDays,
          onDateRangeSelected: (start, end) => notifier.setDateRange(start, end),
        ),
      ],
    );
  }

  // --- Step 2: Transport & Budget ---
  Widget _buildStep2TransportAndBudget(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '03',
          title: 'How are you travelling?',
          subtitle: 'Choose primary transit mode and general budget tier.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Transport Mode', isDark),
        const SizedBox(height: 12),
        ...TripTransport.values.map((mode) => PreferenceChoiceCard(
              title: mode.label,
              description: mode.description,
              isSelected: state.trip.transportMode == mode,
              onTap: () => notifier.setTransportMode(mode),
            )),
        const SizedBox(height: 24),
        _buildSectionTitle('General Budget Tier', isDark),
        const SizedBox(height: 12),
        ...TripBudgetTier.values.map((tier) => PreferenceChoiceCard(
              title: tier.label,
              description: tier.description,
              isSelected: state.trip.budgetTier == tier,
              onTap: () => notifier.setBudgetTier(tier),
            )),
      ],
    );
  }

  // --- Step 3: Trip Style & Purpose ---
  Widget _buildStep3StyleAndPurpose(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '04',
          title: "What's your trip style?",
          subtitle: 'Select your journey purpose and matching vibes.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Trip Purpose', isDark),
        const SizedBox(height: 12),
        ...TripPurpose.values.map((purpose) => PreferenceChoiceCard(
              title: purpose.label,
              description: purpose.description,
              isSelected: state.trip.tripPurpose == purpose,
              onTap: () => notifier.setTripPurpose(purpose),
            )),
        const SizedBox(height: 24),
        _buildSectionTitle('Trip Vibes (Select all that apply)', isDark),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TripVibe.values.map((vibe) {
            final isSelected = state.trip.tripStyles.contains(vibe.code);
            return MultiSelectChip(
              label: vibe.label,
              isSelected: isSelected,
              onSelected: () => notifier.toggleTripStyle(vibe.code),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Step 4: Companion Preferences ---
  Widget _buildStep4CompanionPreferences(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    final prefs = state.preferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '05',
          title: 'What companion fits this journey?',
          subtitle: 'Define criteria for your ideal travel companion on this trip.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Desired Travel Pace', isDark),
        const SizedBox(height: 8),
        ...TravelPace.values.map((pace) => PreferenceChoiceCard(
              title: pace.label,
              description: pace.description,
              isSelected: prefs.travelPace == pace,
              onTap: () => notifier.setCompanionPace(pace),
            )),
        const SizedBox(height: 20),
        _buildSectionTitle('Social Energy Preference', isDark),
        const SizedBox(height: 8),
        ...SocialPreference.values.map((social) => PreferenceChoiceCard(
              title: social.label,
              description: social.description,
              isSelected: prefs.socialEnergy == social,
              onTap: () => notifier.setCompanionSocial(social),
            )),
        const SizedBox(height: 20),
        _buildSectionTitle('Accommodation Preference', isDark),
        const SizedBox(height: 8),
        ...AccommodationStyle.values.map((acc) => PreferenceChoiceCard(
              title: acc.label,
              description: acc.description,
              isSelected: prefs.accommodationPreference == acc,
              onTap: () => notifier.setCompanionAccommodation(acc),
            )),
        const SizedBox(height: 20),
        _buildSectionTitle('Activities You Want to Share', isDark),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableActivities.map((act) {
            final isSelected = prefs.activityInterests.contains(act);
            return MultiSelectChip(
              label: act,
              isSelected: isSelected,
              onSelected: () => notifier.toggleCompanionActivity(act),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Dietary Openness', isDark),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableDiets.map((diet) {
            final isSelected = prefs.dietaryPreferences.contains(diet);
            return MultiSelectChip(
              label: diet,
              isSelected: isSelected,
              onSelected: () => notifier.toggleCompanionDiet(diet),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Step 5: Privacy & Visibility ---
  Widget _buildStep5PrivacyAndCompanions(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '06',
          title: 'Privacy & Group Size',
          subtitle: 'Choose how this journey is discovered by other verified travelers.',
          isDark: isDark,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Journey Visibility', isDark),
        const SizedBox(height: 12),
        ...TripVisibility.values.map((vis) => PreferenceChoiceCard(
              title: vis.label,
              description: vis.description,
              isSelected: state.trip.visibility == vis,
              onTap: () => notifier.setVisibility(vis),
            )),

        const SizedBox(height: 24),
        _buildSectionTitle('Max Companions (${state.trip.maxCompanions})', isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: state.trip.maxCompanions > 1
                  ? () => notifier.setMaxCompanions(state.trip.maxCompanions - 1)
                  : null,
            ),
            Text(
              '${state.trip.maxCompanions} companions',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: state.trip.maxCompanions < 10
                  ? () => notifier.setMaxCompanions(state.trip.maxCompanions + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 6: Pre-Review Confirmation ---
  Widget _buildStep6PreReview(
    TripCreationState state,
    TripCreationController notifier,
    bool isDark,
  ) {
    final trip = state.trip;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          stepNumber: '07',
          title: 'Ready to review?',
          subtitle: 'Check all journey details before publishing for companion matching.',
          isDark: isDark,
        ),
        const SizedBox(height: 24),
        Container(
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
                trip.title.isNotEmpty ? trip.title : 'Trip to ${trip.destination}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${trip.origin} → ${trip.destination}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Duration: ${trip.durationLabel}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Mode: ${trip.transportMode.label} • Purpose: ${trip.tripPurpose.label}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Visibility: ${trip.visibility.label}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tap "Review Journey" below to see the full companion matching summary and publish.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader({
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'STEP $stepNumber OF 07',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }
}
