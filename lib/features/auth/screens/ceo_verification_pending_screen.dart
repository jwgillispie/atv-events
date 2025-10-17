import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

/// Full-screen CEO verification pending with Hipop branding
class CeoVerificationPendingScreen extends StatelessWidget {
  const CeoVerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account Status')),
            body: const Center(
              child: Text('Please sign in to view your account status'),
            ),
          );
        }

        final userProfile = state.userProfile;
        if (userProfile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check verification status and redirect if approved
        if (userProfile.verificationStatus == VerificationStatus.approved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Show welcome dialog then navigate to dashboard
            _showWelcomeDialog(context, userProfile);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Show pending or rejected screen
        if (userProfile.verificationStatus == VerificationStatus.rejected) {
          return _buildRejectedScreen(context, userProfile);
        }

        return _buildPendingScreen(context, userProfile);
      },
    );
  }

  Widget _buildPendingScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';
    final colorScheme = isVendor
        ? HiPopColors.vendorAccent
        : HiPopColors.organizerAccent;

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hipop Logo
                Image.asset(
                  'assets/hipop_logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colorScheme.withAlpha(50),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 60,
                      color: colorScheme,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Pending icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    size: 48,
                    color: colorScheme,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Account Under Review',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  isVendor
                      ? 'Thanks for joining Hipop! We\'re reviewing your vendor profile to ensure quality for our marketplace community.'
                      : 'Thanks for joining Hipop! We\'re reviewing your organizer profile to verify your organization and experience.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: HiPopColors.darkTextSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.withAlpha(80),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.person_outline,
                        'Account Type',
                        isVendor ? 'Vendor' : 'Market Organizer',
                        colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.email_outlined,
                        'Email',
                        userProfile.email,
                        colorScheme,
                      ),
                      if (userProfile.verificationRequestedAt != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.schedule,
                          'Submitted',
                          _formatDate(userProfile.verificationRequestedAt!),
                          colorScheme,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // What's next section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: colorScheme, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'What happens next?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildChecklistItem('We review your profile', true),
                      _buildChecklistItem('Verify your information', true),
                      _buildChecklistItem('Send approval email', false),
                      _buildChecklistItem('You start creating popups!', false),
                      const SizedBox(height: 8),
                      Text(
                        '⏱️ Usually takes 1-2 business days',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _refresh(context),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Status'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme,
                          side: BorderSide(color: colorScheme),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _signOut(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.darkTextSecondary,
                          side: BorderSide(color: HiPopColors.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Support link
                TextButton(
                  onPressed: () => context.go('/support'),
                  child: Text(
                    'Need help? Contact Support',
                    style: TextStyle(
                      color: colorScheme,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hipop Logo
                Image.asset(
                  'assets/hipop_logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: HiPopColors.errorPlum.withAlpha(50),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 50,
                      color: HiPopColors.errorPlum,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HiPopColors.errorPlum.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_outlined,
                    size: 48,
                    color: HiPopColors.errorPlum,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Application Not Approved',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.errorPlum,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  isVendor
                      ? 'Unfortunately, we weren\'t able to approve your vendor application at this time.'
                      : 'Unfortunately, we weren\'t able to approve your organizer application at this time.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: HiPopColors.darkTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (userProfile.verificationNotes != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HiPopColors.errorPlum.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HiPopColors.errorPlum.withAlpha(60),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.feedback_outlined,
                              color: HiPopColors.errorPlum,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Review Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.errorPlum,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userProfile.verificationNotes!,
                          style: const TextStyle(
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                // Support button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/support'),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.accentMauve,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sign out button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.darkTextSecondary,
                      side: BorderSide(color: HiPopColors.darkBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(String text, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: completed
                ? HiPopColors.successGreen
                : HiPopColors.darkTextSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: completed
                  ? HiPopColors.darkTextPrimary
                  : HiPopColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _signOut(BuildContext context) {
    context.read<AuthBloc>().add(LogoutEvent());
    context.go('/auth');
  }

  void _refresh(BuildContext context) {
    context.read<AuthBloc>().add(ReloadUserEvent());
  }

  void _showWelcomeDialog(BuildContext context, UserProfile userProfile) {
    // Use existing welcome notification dialog
    // Navigate directly to dashboard (welcome dialog shows automatically there)
    if (userProfile.userType == 'vendor') {
      context.go('/vendor');
    } else if (userProfile.userType == 'market_organizer') {
      context.go('/organizer');
    }
  }
}
