import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';

import '../models/user_profile.dart';
import '../widgets/common/support_contact_widget.dart';
import '../../../core/theme/hipop_colors.dart';

class AccountVerificationPendingScreen extends StatelessWidget {
  const AccountVerificationPendingScreen({super.key});

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
          return Scaffold(
            appBar: AppBar(title: const Text('Account Status')),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check verification status and show appropriate screen
        switch (userProfile.verificationStatus) {
          case VerificationStatus.approved:
            // Redirect to appropriate dashboard
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (userProfile.userType == 'vendor') {
                context.go('/vendor');
              } else if (userProfile.userType == 'market_organizer') {
                context.go('/organizer');
              } else {
                context.go('/');
              }
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          
          case VerificationStatus.rejected:
            return _buildRejectedScreen(context, userProfile);
          
          case VerificationStatus.pending:
            return _buildPendingScreen(context, userProfile);
        }
      },
    );
  }

  Widget _buildPendingScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';
    final title = isVendor ? 'Vendor Account Under Review' : 'Market Organizer Account Under Review';
    final businessName = isVendor 
        ? (userProfile.businessName ?? userProfile.displayName ?? 'Your Business')
        : (userProfile.organizationName ?? userProfile.displayName ?? 'Your Organization');
    final colorScheme = isVendor ? HiPopColors.vendorAccent : HiPopColors.organizerAccent;

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colorScheme,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HiPopColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity( 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      size: 64,
                      color: colorScheme,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Under Review',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVendor 
                          ? 'Thanks for submitting your vendor profile! We\'re currently reviewing your account to ensure quality and authenticity.'
                          : 'Thanks for submitting your market organizer profile! We\'re currently reviewing your account to verify your organization and experience.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.withOpacity( 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isVendor ? Icons.business : Icons.account_balance,
                                color: colorScheme,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  businessName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: HiPopColors.darkTextPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.email, color: colorScheme),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userProfile.email,
                                  style: TextStyle(color: colorScheme),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.person, color: colorScheme),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${isVendor ? 'Vendor' : 'Market Organizer'} Account',
                                  style: TextStyle(color: colorScheme),
                                ),
                              ),
                            ],
                          ),
                          if (userProfile.verificationRequestedAt != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.schedule, color: colorScheme),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Submitted ${_formatDate(userProfile.verificationRequestedAt!)}',
                                    style: TextStyle(color: colorScheme),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'What\'s Next?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVendor
                          ? '• We\'ll review your business information\n'
                            '• Verify your contact details\n'
                            '• You\'ll receive an email when approved\n'
                            '• This usually takes 1-2 business days'
                          : '• We\'ll review your organization information\n'
                            '• Verify your market management experience\n'
                            '• You\'ll receive an email when approved\n'
                            '• This usually takes 1-2 business days',
                      style: TextStyle(color: HiPopColors.darkTextSecondary),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SupportContactWidgetFactory.forAccountVerification(
                userProfile: userProfile,
                primaryColor: colorScheme,
                compact: true,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _signOut(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HiPopColors.darkTextPrimary,
                        side: BorderSide(color: HiPopColors.darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _refresh(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(BuildContext context, UserProfile userProfile) {
    final isVendor = userProfile.userType == 'vendor';
    final title = isVendor ? 'Vendor Account Review' : 'Market Organizer Account Review';

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: HiPopColors.errorPlum,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HiPopColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity( 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cancel,
                      size: 64,
                      color: HiPopColors.errorPlum,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Account Not Approved',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.errorPlum,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVendor
                          ? 'Unfortunately, we weren\'t able to approve your vendor account at this time.'
                          : 'Unfortunately, we weren\'t able to approve your market organizer account at this time.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (userProfile.verificationNotes != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HiPopColors.errorPlum.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: HiPopColors.errorPlum.withOpacity( 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Notes:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.errorPlum,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              userProfile.verificationNotes!,
                              style: TextStyle(color: HiPopColors.errorPlum),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SupportContactWidgetFactory.forAccountRejection(
                      userProfile: userProfile,
                      compact: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HiPopColors.darkTextPrimary,
                    side: BorderSide(color: HiPopColors.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    // Reload user profile to check for verification status updates
    context.read<AuthBloc>().add(ReloadUserEvent());
  }

}