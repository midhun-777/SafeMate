import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safemate/core/constants/app_colors.dart';
import 'package:safemate/core/validation/auth_validators.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_button.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:safemate/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:safemate/features/profile/domain/models/profile_visibility.dart';
import 'package:safemate/features/profile/domain/models/travel_personality.dart';
import 'package:safemate/features/profile/domain/models/travel_preferences.dart';
import '../controllers/profile_controller.dart';
import '../widgets/multi_select_chip.dart';
import '../widgets/preference_choice_card.dart';
import '../widgets/profile_photo_picker.dart';
import '../widgets/profile_progress_bar.dart';

/// Multi-step visual onboarding & profile setup wizard for SafeMate.
/// Universal Engineering Rule #13: Calm, visual, one meaningful concept at a time.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();

  static const List<String> _popularLanguages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Mandarin',
    'Hindi',
    'Italian',
    'Portuguese',
    'Arabic',
  ];

  static const List<String> _transportModes = [
    'Flight',
    'Train',
    'Bus',
    'Road Trip',
    'Bike',
    'Boat / Ferry',
  ];

  static const List<String> _dietaryOptions = [
    'Flexible Diet',
    'Vegetarian',
    'Vegan',
    'Halal',
    'Gluten-Free',
    'Dairy-Free',
  ];

  static const List<String> _activityOptions = [
    'Nature Walks',
    'Mountain Treks',
    'Beaches & Coastal',
    'Historic Sights',
    'Museums & Arts',
    'Local Markets',
    'Street Food',
    'Photography',
    'Cafes & Reading',
    'Nightlife & Music',
    'Wellness & Yoga',
    'Cycling',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(profileControllerProvider);
      _nameController.text = state.profile.displayName;
      _bioController.text = state.profile.bio ?? '';
      _cityController.text = state.profile.homeCity ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndExit() async {
    final success = await ref.read(profileControllerProvider.notifier).saveDraft();
    if (success && mounted) {
      context.go('/home');
    }
  }

  void _handleContinue() {
    final state = ref.read(profileControllerProvider);

    // Validate minimum on step 0
    if (state.currentStep == 0) {
      final nameErr = AuthValidators.validateDisplayName(_nameController.text);
      if (nameErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nameErr)),
        );
        return;
      }
      ref.read(profileControllerProvider.notifier).setDisplayName(_nameController.text);
      ref.read(profileControllerProvider.notifier).setBio(_bioController.text);
      ref.read(profileControllerProvider.notifier).setHomeCity(_cityController.text);
    }

    if (state.currentStep < 3) {
      ref.read(profileControllerProvider.notifier).nextStep();
    } else {
      // Advance to review screen
      context.go('/profile/review');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileState = ref.watch(profileControllerProvider);

    if (profileState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final stepTitles = [
      'Basic Identity',
      'Travel Personality',
      'Travel Preferences',
      'Privacy Settings',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveler Profile'),
        actions: [
          TextButton(
            onPressed: profileState.isSaving ? null : _handleSaveAndExit,
            child: profileState.isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save & Exit',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: ProfileProgressBar(
                currentStep: profileState.currentStep,
                totalSteps: 4,
                stepTitle: stepTitles[profileState.currentStep],
                completion: profileState.completion,
              ),
            ),
            const Divider(height: 1),
            if (profileState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AuthErrorBanner(
                  message: profileState.errorMessage!,
                  onDismiss: () =>
                      ref.read(profileControllerProvider.notifier).clearMessage(),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildCurrentStepView(profileState.currentStep, isDark),
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                  if (profileState.currentStep > 0) ...[
                    Expanded(
                      flex: 1,
                      child: AuthButton(
                        text: 'Back',
                        isSecondary: true,
                        onPressed: () => ref
                            .read(profileControllerProvider.notifier)
                            .previousStep(),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: AuthButton(
                      text: profileState.currentStep == 3
                          ? 'Review Profile'
                          : 'Continue',
                      onPressed: _handleContinue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepView(int step, bool isDark) {
    switch (step) {
      case 0:
        return _buildStep0Identity(isDark);
      case 1:
        return _buildStep1Personality(isDark);
      case 2:
        return _buildStep2Preferences(isDark);
      case 3:
        return _buildStep3Privacy(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 0: Basic Identity ---
  Widget _buildStep0Identity(bool isDark) {
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who are you traveling as?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Set up the foundational details other verified travelers will see.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 24),
        ProfilePhotoPicker(
          avatarUrl: state.profile.avatarUrl,
          isUploading: state.isUploadingPhoto,
          onPickPhoto: () async {
            // Mock picker upload for development or test
            await notifier.uploadProfilePhoto(
              bytes: [137, 80, 78, 71, 13, 10, 26, 10], // Sample PNG header
              filename: 'avatar.png',
            );
          },
          onRemovePhoto: () => notifier.removeProfilePhoto(),
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _nameController,
          label: 'Display Name *',
          hintText: 'e.g. Alex Morgan',
          onChanged: (val) => notifier.setDisplayName(val),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _cityController,
          label: 'Home City / Region (Optional)',
          hintText: 'e.g. Seattle, WA or London, UK',
          onChanged: (val) => notifier.setHomeCity(val),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _bioController,
          label: 'Short Bio (Optional)',
          hintText: 'Share a little about how you explore and what you value in a travel mate.',
          textInputAction: TextInputAction.done,
          onChanged: (val) => notifier.setBio(val),
        ),
        const SizedBox(height: 24),
        Text(
          'Languages Spoken',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularLanguages.map((lang) {
            final isSelected = state.profile.languages.contains(lang);
            return MultiSelectChip(
              label: lang,
              isSelected: isSelected,
              onSelected: () => notifier.toggleLanguage(lang),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Step 1: Travel Personality ---
  Widget _buildStep1Personality(bool isDark) {
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of trips do you imagine?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select trip styles that feel most like you. You can pick multiple.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),
        ...TripVibe.values.map((vibe) {
          final isSelected = state.profile.travelStyles.contains(vibe.code);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: PreferenceChoiceCard(
              title: vibe.label,
              description: vibe.description,
              isSelected: isSelected,
              onTap: () => notifier.toggleTravelStyle(vibe.code),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'How do you like traveling?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...TravelPace.values.map((pace) {
          final isSelected = state.preferences.travelPace == pace;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: PreferenceChoiceCard(
              title: pace.label,
              description: pace.description,
              isSelected: isSelected,
              onTap: () => notifier.setTravelPace(pace),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'Daily Rhythm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...ScheduleStyle.values.where((s) => s != ScheduleStyle.notSpecified).map((schedule) {
          final isSelected = state.preferences.schedulePreference == schedule;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: PreferenceChoiceCard(
              title: schedule.label,
              description: schedule.description,
              isSelected: isSelected,
              onTap: () => notifier.setScheduleStyle(schedule),
            ),
          );
        }),
      ],
    );
  }

  // --- Step 2: Travel Preferences ---
  Widget _buildStep2Preferences(bool isDark) {
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Travel Preferences',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Structure your comfort zones for route and companion compatibility.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Budget Tier',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        ...BudgetTier.values.where((b) => b != BudgetTier.notSpecified).map((tier) {
          final isSelected = state.preferences.budgetTier == tier;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: PreferenceChoiceCard(
              title: tier.label,
              description: tier.description,
              isSelected: isSelected,
              onTap: () => notifier.setBudgetTier(tier),
            ),
          );
        }),
        const SizedBox(height: 20),
        Text(
          'Preferred Transport Modes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _transportModes.map((mode) {
            final isSelected = state.preferences.preferredTransport.contains(mode);
            return MultiSelectChip(
              label: mode,
              isSelected: isSelected,
              onSelected: () => notifier.toggleTransport(mode),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Accommodation Comfort',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        ...AccommodationStyle.values.where((a) => a != AccommodationStyle.notSpecified).map((acc) {
          final isSelected = state.preferences.accommodationPreference == acc;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: PreferenceChoiceCard(
              title: acc.label,
              description: acc.description,
              isSelected: isSelected,
              onTap: () => notifier.setAccommodation(acc),
            ),
          );
        }),
        const SizedBox(height: 24),
        Text(
          'Activity Interests',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityOptions.map((act) {
            final isSelected = state.preferences.activityInterests.contains(act);
            return MultiSelectChip(
              label: act,
              isSelected: isSelected,
              onSelected: () => notifier.toggleActivityInterest(act),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Dietary Preferences',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dietaryOptions.map((diet) {
            final isSelected = state.preferences.dietaryPreferences.contains(diet);
            return MultiSelectChip(
              label: diet,
              isSelected: isSelected,
              onSelected: () => notifier.toggleDietary(diet),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Step 3: Privacy Settings ---
  Widget _buildStep3Privacy(bool isDark) {
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Privacy & Discovery',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Control who can see your traveler profile and match with your routes.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 24),
        ...ProfileVisibility.values.map((vis) {
          final isSelected = state.profile.visibility == vis;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: PreferenceChoiceCard(
              title: vis.label,
              description: vis.description,
              isSelected: isSelected,
              onTap: () => notifier.setVisibility(vis),
            ),
          );
        }),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.security_outlined,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SafeMate Privacy Shield',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your email, phone number, and exact location are never displayed to anyone. Only broad city regions and factual trust signals are visible.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
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
      ],
    );
  }
}
