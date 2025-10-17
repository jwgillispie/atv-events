import 'package:flutter/material.dart';
import 'package:atv_events/features/shared/services/communication/support_service.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// A reusable widget for displaying support contact options
class SupportContactWidget extends StatelessWidget {
  final SupportContext context;
  final UserProfile? userProfile;
  final String? title;
  final String? subtitle;
  final Color? primaryColor;
  final bool showEmailOption;
  final bool showPhoneOption;
  final bool compact;

  const SupportContactWidget({
    super.key,
    required this.context,
    this.userProfile,
    this.title,
    this.subtitle,
    this.primaryColor,
    this.showEmailOption = true,
    this.showPhoneOption = false, // Phone disabled by default
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = primaryColor ?? Theme.of(context).primaryColor;
    
    if (compact) {
      return _buildCompactWidget(colorScheme);
    }
    
    return _buildFullWidget(colorScheme);
  }

  Widget _buildCompactWidget(Color colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HiPopColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.support_agent,
                color: colorScheme,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? 'Need Help?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildContactOptions(colorScheme, compact: true),
        ],
      ),
    );
  }

  Widget _buildFullWidget(Color colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.support_agent,
                  color: colorScheme,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'Need Help?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildContactOptions(colorScheme),
        ],
      ),
    );
  }

  Widget _buildContactOptions(Color colorScheme, {bool compact = false}) {
    final options = <Widget>[];
    
    if (showEmailOption) {
      options.add(_buildContactOption(
        icon: Icons.email_outlined,
        title: 'Email Support',
        subtitle: 'Get help via email with detailed response',
        onTap: () => _handleEmailContact(),
        colorScheme: colorScheme,
        compact: compact,
      ));
    }
    
    
    if (showPhoneOption) {
      options.add(_buildContactOption(
        icon: Icons.phone_outlined,
        title: 'Phone Support',
        subtitle: 'Speak with our support team',
        onTap: () => _handlePhoneContact(),
        colorScheme: colorScheme,
        compact: compact,
      ));
    }
    
    if (compact) {
      return Row(
        children: options
            .map((option) => Expanded(child: option))
            .expand((widget) => [widget, const SizedBox(width: 8)])
            .take(options.length * 2 - 1)
            .toList(),
      );
    }
    
    return Column(
      children: options
          .expand((widget) => [widget, const SizedBox(height: 12)])
          .take(options.length * 2 - 1)
          .toList(),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color colorScheme,
    bool compact = false,
  }) {
    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HiPopColors.darkBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: colorScheme,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: HiPopColors.darkTextPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HiPopColors.darkBorder),
          color: HiPopColors.darkSurface.withOpacity( 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: colorScheme,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: HiPopColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: HiPopColors.darkTextTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _handleEmailContact() async {
    try {
      await SupportService.contactSupportByEmail(
        context: context,
        userProfile: userProfile,
      );
    } catch (e) {
      // Could show a snackbar or dialog here for error handling
    }
  }


  void _handlePhoneContact() async {
    try {
      await SupportService.contactSupportByPhone();
    } catch (e) {
      // Could show a snackbar or dialog here for error handling
    }
  }
}

/// Factory constructors for common support contexts
class SupportContactWidgetFactory {
  /// Widget for account verification pending contexts
  static SupportContactWidget forAccountVerification({
    required UserProfile userProfile,
    Color? primaryColor,
    bool compact = false,
  }) {
    final isVendor = userProfile.userType == 'vendor';
    final isOrganizer = userProfile.userType == 'market_organizer';
    
    SupportContext supportContext;
    String title;
    String subtitle;
    
    if (isVendor) {
      supportContext = SupportContext.vendorVerification;
      title = 'Questions About Your Vendor Review?';
      subtitle = 'We\'re here to help with your vendor verification process';
    } else if (isOrganizer) {
      supportContext = SupportContext.marketOrganizerVerification;
      title = 'Questions About Your Organizer Review?';
      subtitle = 'We\'re here to help with your market organizer verification';
    } else {
      supportContext = SupportContext.accountVerification;
      title = 'Questions About Your Account Review?';
      subtitle = 'We\'re here to help with your account verification process';
    }
    
    return SupportContactWidget(
      context: supportContext,
      userProfile: userProfile,
      title: title,
      subtitle: subtitle,
      primaryColor: primaryColor,
      compact: compact,
    );
  }

  /// Widget for account rejection contexts
  static SupportContactWidget forAccountRejection({
    required UserProfile userProfile,
    Color? primaryColor,
    bool compact = false,
  }) {
    return SupportContactWidget(
      context: SupportContext.accountRejection,
      userProfile: userProfile,
      title: 'Account Not Approved?',
      subtitle: 'Let\'s discuss how we can help resolve this',
      primaryColor: primaryColor ?? HiPopColors.errorPlum,
      compact: compact,
    );
  }
}