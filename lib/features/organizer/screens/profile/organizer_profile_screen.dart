import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/core/widgets/hipop_app_bar.dart';
import 'package:hipop/features/organizer/blocs/profile/organizer_profile_bloc.dart';
import 'package:hipop/features/organizer/blocs/profile/organizer_profile_event.dart';
import 'package:hipop/features/organizer/blocs/profile/organizer_profile_state.dart';
import 'package:hipop/features/organizer/widgets/organizer_settings_dropdown.dart';
import 'package:hipop/features/shared/models/user_feedback.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/shared/services/user/user_feedback_service.dart';
import 'package:hipop/features/shared/services/user/user_profile_service.dart';
import 'package:hipop/features/shared/widgets/debug_master_data_generator.dart';
import 'package:hipop/features/shared/widgets/debug_database_cleaner.dart';
import 'package:hipop/features/shared/widgets/debug_csv_market_importer.dart';
import 'package:hipop/features/shared/widgets/debug_premium_activator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/features/shared/models/universal_review.dart';
import 'package:hipop/features/tickets/screens/my_tickets_screen.dart';
import 'package:hipop/features/organizer/screens/earnings/organizer_earnings_screen.dart';
import 'package:hipop/features/shared/widgets/stripe_connect_widget.dart';

class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({super.key});

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  UserProfile? _userProfile;
  final UserProfileService _profileService = UserProfileService();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final profile = await _profileService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }
      } catch (e) {
        // Handle error silently or show error to user
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load profile when the widget builds for the first time
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<OrganizerProfileBloc>().add(
        LoadOrganizerProfile(userId: authState.user.uid),
      );
    }

    return BlocBuilder<OrganizerProfileBloc, OrganizerProfileState>(
      builder: (context, profileState) {
        final isCheckingPremium =
            profileState.status == OrganizerProfileStatus.initial ||
            profileState.status == OrganizerProfileStatus.loading;
        final hasPremiumAccess = profileState.hasPremiumAccess;

        return Scaffold(
          backgroundColor: HiPopColors.darkBackground,
          appBar: HiPopAppBar(
            title: 'Profile',
            userRole: 'organizer',
            centerTitle: true,
            actions: const [OrganizerSettingsDropdown()],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      Card(
                        color: HiPopColors.darkSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: HiPopColors.darkBorder.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              if (state is! Authenticated) {
                                return const SizedBox.shrink();
                              }
                              return Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundColor: HiPopColors.organizerAccent.withOpacity(0.2),
                                      backgroundImage: _userProfile?.profilePhotoUrl != null
                                          ? CachedNetworkImageProvider(_userProfile!.profilePhotoUrl!)
                                          : null,
                                      child: _userProfile?.profilePhotoUrl == null
                                          ? Icon(
                                              Icons.business,
                                              color: HiPopColors.organizerAccent,
                                              size: 25,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome Back!',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color: HiPopColors.darkTextPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _userProfile?.organizationName ??
                                            _userProfile?.displayName ??
                                            state.user.displayName ??
                                            state.user.email ??
                                            'Organizer',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: HiPopColors.darkTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.organizerAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick Actions Section
                    _buildProfileOption(
                      context,
                      'Pop Ups Nearby',
                      'Browse and explore local markets',
                      Icons.explore,
                      HiPopColors.vendorAccent,
                      () => context.go('/shopper?from=organizer'),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'My Tickets',
                      'View tickets you\'ve purchased',
                      Icons.confirmation_number,
                      HiPopColors.primaryDeepSage,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MyTicketsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'Earnings',
                      'View your market earnings and payouts',
                      Icons.attach_money,
                      HiPopColors.successGreen,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const OrganizerEarningsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Payment Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.organizerAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stripe Connect Widget for Organizers
                    const StripeConnectWidget(userType: 'organizer'),
                    const SizedBox(height: 24),
                    Text(
                      'Account Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.organizerAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Call Founder Button - styled like other options
                    _buildProfileOption(
                      context,
                      'Phone the Founder',
                      'Direct line to Jozo for immediate help',
                      Icons.phone,
                      HiPopColors.primaryDeepSage,
                      () => _callFounder(context),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'Edit Profile',
                      'Update your profile information',
                      Icons.edit,
                      HiPopColors.organizerAccent,
                      () => _navigateToEditProfile(context),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'Subscription Management',
                      isCheckingPremium
                          ? 'Loading subscription status...'
                          : (hasPremiumAccess
                              ? 'Manage your Premium subscription'
                              : 'Upgrade to Premium'),
                      Icons.credit_card,
                      hasPremiumAccess
                          ? HiPopColors.premiumGold
                          : HiPopColors.primaryDeepSage,
                      () => _navigateToSubscriptionManagement(context),
                      isPremium: hasPremiumAccess,
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'Change Password',
                      'Update your account password',
                      Icons.lock_outline,
                      HiPopColors.infoBlueGray,
                      () => _navigateToChangePassword(context),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileOption(
                      context,
                      'Help & Support',
                      'Get help, view policies, or contact us',
                      Icons.help_outline,
                      HiPopColors.accentMauve,
                      () => context.push('/support'),
                    ),
                    const SizedBox(height: 20),
                    _buildProfileOption(
                      context,
                      'Sign Out',
                      'Sign out of your account',
                      Icons.logout,
                      HiPopColors.errorPlum,
                      () => _signOut(context),
                    ),
                    // Debug Section - Only visible in debug mode
                    if (kDebugMode) ...[
                      const SizedBox(height: 32),
                      const Divider(
                        thickness: 1,
                        color: HiPopColors.lightBorder,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '🛠️ Debug Tools',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Debug mode only - These tools modify your database',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Debug Premium Activator
                      const DebugPremiumActivator(),
                      const SizedBox(height: 16),
                      _buildDebugOption(
                        context,
                        'Master Demo Setup',
                        'Create complete demo data: markets, vendors, posts, events, reviews',
                        Icons.add_circle_outline,
                        Colors.green,
                        () => _showDebugDataGenerator(context),
                      ),
                      const SizedBox(height: 12),
                      _buildDebugOption(
                        context,
                        'Import Markets from CSV',
                        'Import Community Market ATL Fall 2025 schedule (25+ markets)',
                        Icons.upload_file,
                        HiPopColors.warningAmber,
                        () => _showCsvMarketImporter(context),
                      ),
                      const SizedBox(height: 12),
                      _buildDebugOption(
                        context,
                        'Generate Mock Reviews',
                        'Add shopper and vendor reviews for this organizer account',
                        Icons.star,
                        HiPopColors.organizerAccent,
                        () => _generateMockReviews(context),
                      ),
                      const SizedBox(height: 12),
                      _buildDebugOption(
                        context,
                        'Delete All Data',
                        'Remove ALL data except 3 test accounts',
                        Icons.delete_forever,
                        Colors.red,
                        () => _showDebugDatabaseCleaner(context),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap, {
    bool isPremium = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HiPopColors.darkBorder.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon container on the left
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                // Title and description in the middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPremium) ...[
                            Icon(
                              Icons.diamond,
                              size: 16,
                              color: HiPopColors.premiumGold,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator on the right
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: HiPopColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) async {
    await context.push('/organizer/edit-profile');
    // Reload profile after returning from edit screen
    _loadUserProfile();
  }

  void _navigateToSubscriptionManagement(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.go('/subscription-management/${authState.user.uid}');
    }
  }

  void _navigateToChangePassword(BuildContext context) {
    context.pushNamed('organizerChangePassword');
  }

  Future<void> _callFounder(BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+13523271969');

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to make phone call. Phone: 352-327-1969'),
              backgroundColor: HiPopColors.errorPlum,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }

  void _showFeedbackDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    FeedbackCategory selectedCategory = FeedbackCategory.general;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: HiPopColors.darkSurface,
            title: const Text(
              'Send Feedback',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            content: SingleChildScrollView(
              child: StatefulBuilder(
                builder:
                    (context, setState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help us improve HiPOP! Your feedback goes directly to our team.',
                          style: TextStyle(
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category selection
                        const Text(
                          'Category:',
                          style: TextStyle(color: HiPopColors.darkTextPrimary),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<FeedbackCategory>(
                          value: selectedCategory,
                          style: const TextStyle(
                            color: HiPopColors.darkTextPrimary,
                          ),
                          dropdownColor: HiPopColors.darkSurface,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.darkBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.organizerAccent,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items:
                              FeedbackCategory.values.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                    _getCategoryDisplayName(category),
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedCategory = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Title
                        TextField(
                          controller: titleController,
                          style: const TextStyle(
                            color: HiPopColors.darkTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Title',
                            labelStyle: TextStyle(
                              color: HiPopColors.darkTextSecondary,
                            ),
                            hintText: 'Brief summary of your feedback',
                            hintStyle: TextStyle(
                              color: HiPopColors.darkTextTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.darkBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.organizerAccent,
                              ),
                            ),
                          ),
                          maxLength: 200,
                        ),
                        const SizedBox(height: 16),

                        // Description
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(
                            color: HiPopColors.darkTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: TextStyle(
                              color: HiPopColors.darkTextSecondary,
                            ),
                            hintText:
                                'Please provide details about your feedback',
                            hintStyle: TextStyle(
                              color: HiPopColors.darkTextTertiary,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.darkBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: HiPopColors.organizerAccent,
                              ),
                            ),
                          ),
                          maxLines: 4,
                          maxLength: 2000,
                        ),
                      ],
                    ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();

                  if (title.isEmpty || description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext);
                  _submitFeedback(
                    context,
                    selectedCategory,
                    title,
                    description,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.accentMauve,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Feedback'),
              ),
            ],
          ),
    );
  }

  String _getCategoryDisplayName(FeedbackCategory category) {
    switch (category) {
      case FeedbackCategory.bug:
        return 'Bug Report';
      case FeedbackCategory.feature:
        return 'Feature Request';
      case FeedbackCategory.improvement:
        return 'Improvement Suggestion';
      case FeedbackCategory.general:
        return 'General Feedback';
      case FeedbackCategory.tutorial:
        return 'Tutorial Feedback';
      case FeedbackCategory.support:
        return 'Support Request';
    }
  }

  Future<void> _submitFeedback(
    BuildContext context,
    FeedbackCategory category,
    String title,
    String description,
  ) async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) return;

      await UserFeedbackService.submitFeedback(
        userId: authState.user.uid,
        userType: 'market_organizer',
        userEmail: authState.user.email ?? '',
        userName: authState.user.displayName,
        category: category,
        title: title,
        description: description,
        metadata: {
          'screen': 'organizer_profile',
          'timestamp': DateTime.now().toIso8601String(),
          'appSection': 'organizer_settings',
        },
      );

      // Check if context is still valid before showing snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thank you for your feedback! We\'ll review it soon.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: HiPopColors.darkSurface,
            title: const Text(
              'Sign Out',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            content: const Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.read<AuthBloc>().add(LogoutEvent());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.errorPlum,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
  }

  Widget _buildDebugOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon on the left
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icon, color: iconColor, size: 24)),
                ),
                const SizedBox(width: 16),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Arrow indicator
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: HiPopColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDebugDataGenerator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: HiPopColors.darkBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Master Demo Data Generator',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: HiPopColors.darkTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: HiPopColors.darkBorder),
                const Expanded(child: DebugMasterDataGenerator()),
              ],
            ),
          ),
    );
  }

  void _showDebugDatabaseCleaner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: HiPopColors.darkBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Database Cleaner',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: HiPopColors.darkTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: HiPopColors.darkBorder),
                const Expanded(
                  child: SingleChildScrollView(child: DebugDatabaseCleaner()),
                ),
              ],
            ),
          ),
    );
  }

  void _showCsvMarketImporter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: HiPopColors.darkBackground,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkTextTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'CSV Market Importer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: HiPopColors.darkTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: HiPopColors.darkBorder),
                const Expanded(
                  child: SingleChildScrollView(child: DebugCsvMarketImporter()),
                ),
              ],
            ),
          ),
    );
  }

  static Future<void> _generateMockReviews(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Mock shopper/vendor reviews of this organizer
      final mockReviews = [
        UniversalReview(
          id: '',
          reviewerId: 'shopper_${DateTime.now().millisecondsSinceEpoch}_1',
          reviewerName: 'Sarah Johnson',
          reviewerType: 'shopper',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 7)),
          overallRating: 5.0,
          reviewText: 'Amazing market! Well organized and great variety of vendors. Will definitely be back!',
          createdAt: now.subtract(const Duration(days: 7)),
          isVerified: true,
          verificationMethod: 'qr',
        ),
        UniversalReview(
          id: '',
          reviewerId: 'vendor_${DateTime.now().millisecondsSinceEpoch}_1',
          reviewerName: 'Fresh Farms Produce',
          reviewerType: 'vendor',
          reviewerBusinessName: 'Fresh Farms Produce',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 7)),
          overallRating: 5.0,
          reviewText: 'Excellent organizer! Great communication and foot traffic. Best market I\'ve worked with.',
          createdAt: now.subtract(const Duration(days: 7)),
          isVerified: true,
          verificationMethod: 'registration',
        ),
        UniversalReview(
          id: '',
          reviewerId: 'shopper_${DateTime.now().millisecondsSinceEpoch}_2',
          reviewerName: 'Mike Chen',
          reviewerType: 'shopper',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 14)),
          overallRating: 4.5,
          reviewText: 'Great atmosphere and selection. Wish there was more parking.',
          createdAt: now.subtract(const Duration(days: 14)),
          isVerified: true,
          verificationMethod: 'qr',
        ),
        UniversalReview(
          id: '',
          reviewerId: 'vendor_${DateTime.now().millisecondsSinceEpoch}_2',
          reviewerName: 'Artisan Bakery Co.',
          reviewerType: 'vendor',
          reviewerBusinessName: 'Artisan Bakery Co.',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 14)),
          overallRating: 5.0,
          reviewText: 'Professional and responsive organizer. Setup was smooth and sales were fantastic!',
          createdAt: now.subtract(const Duration(days: 14)),
          isVerified: true,
          verificationMethod: 'registration',
        ),
        UniversalReview(
          id: '',
          reviewerId: 'shopper_${DateTime.now().millisecondsSinceEpoch}_3',
          reviewerName: 'Emily Rodriguez',
          reviewerType: 'shopper',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 21)),
          overallRating: 5.0,
          reviewText: 'Love this market! Family friendly and great local products.',
          createdAt: now.subtract(const Duration(days: 21)),
          isVerified: true,
          verificationMethod: 'qr',
        ),
        UniversalReview(
          id: '',
          reviewerId: 'vendor_${DateTime.now().millisecondsSinceEpoch}_3',
          reviewerName: 'Handmade Crafts',
          reviewerType: 'vendor',
          reviewerBusinessName: 'Handmade Crafts',
          reviewedId: user.uid,
          reviewedName: 'This Organizer',
          reviewedType: 'organizer',
          eventDate: now.subtract(const Duration(days: 21)),
          overallRating: 4.5,
          reviewText: 'Good market with steady customers. Would appreciate more vendor communication.',
          createdAt: now.subtract(const Duration(days: 21)),
          isVerified: true,
          verificationMethod: 'registration',
        ),
      ];

      // Add reviews to Firestore
      for (final review in mockReviews) {
        await db.collection('universal_reviews').add(review.toFirestore());
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${mockReviews.length} mock reviews!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating reviews: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    }
  }
}
