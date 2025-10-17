import 'package:url_launcher/url_launcher.dart';
import 'package:atv_events/features/shared/services/utilities/url_launcher_service.dart';
import 'package:atv_events/features/shared/models/user_profile.dart';

/// Support contact context types
enum SupportContext {
  accountVerification,
  vendorVerification,
  marketOrganizerVerification,
  general,
  technicalIssue,
  accountRejection,
}

/// Service for handling support contact functionality
class SupportService {
  static const String _supportEmail = 'hipopmarkets@gmail.com';
  static const String _supportPhone = '+1-555-HIPOP-1'; // Placeholder - replace with actual number

  /// Launch email to support with context-specific subject and body
  static Future<void> contactSupportByEmail({
    required SupportContext context,
    UserProfile? userProfile,
    String? additionalDetails,
  }) async {
    try {
      final subject = _getEmailSubject(context);
      final body = _getEmailBody(context, userProfile, additionalDetails);
      
      final encodedSubject = Uri.encodeComponent(subject);
      final encodedBody = Uri.encodeComponent(body);
      final mailtoUrl = 'mailto:$_supportEmail?subject=$encodedSubject&body=$encodedBody';
      
      await _launchMailtoUrl(mailtoUrl);
    } catch (e) {
      rethrow;
    }
  }

  /// Launch phone call to support (if available)
  static Future<void> contactSupportByPhone() async {
    try {
      await UrlLauncherService.launchPhone(_supportPhone);
    } catch (e) {
      rethrow;
    }
  }


  /// Get context-specific email subject
  static String _getEmailSubject(SupportContext context) {
    switch (context) {
      case SupportContext.accountVerification:
        return 'Account Verification Support Request';
      case SupportContext.vendorVerification:
        return 'Vendor Account Verification Support';
      case SupportContext.marketOrganizerVerification:
        return 'Market Organizer Verification Support';
      case SupportContext.accountRejection:
        return 'Account Rejection Inquiry';
      case SupportContext.technicalIssue:
        return 'Technical Support Request';
      case SupportContext.general:
        return 'HiPop Support Request';
    }
  }

  /// Get context-specific email body with user details
  static String _getEmailBody(
    SupportContext context, 
    UserProfile? userProfile,
    String? additionalDetails,
  ) {
    final buffer = StringBuffer();
    
    // Context-specific greeting and description
    switch (context) {
      case SupportContext.accountVerification:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I am writing regarding my account verification status.');
        buffer.writeln('My account is currently pending verification and I would like to inquire about the process or provide additional information if needed.');
        break;
      case SupportContext.vendorVerification:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I am writing regarding my vendor account verification.');
        buffer.writeln('I submitted my vendor profile for review and would like to check on the status or provide any additional information that might be needed.');
        break;
      case SupportContext.marketOrganizerVerification:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I am writing regarding my market organizer account verification.');
        buffer.writeln('I submitted my market organizer profile for review and would like to check on the status or provide any additional information that might be needed.');
        break;
      case SupportContext.accountRejection:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I am writing regarding my account verification that was not approved.');
        buffer.writeln('I would like to understand the reasons for the rejection and discuss what steps I can take to address any concerns.');
        break;
      case SupportContext.technicalIssue:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I am experiencing a technical issue with the HiPop app.');
        break;
      case SupportContext.general:
        buffer.writeln('Hello HiPop Support Team,');
        buffer.writeln('');
        buffer.writeln('I have a question or need assistance with HiPop.');
        break;
    }
    
    buffer.writeln('');
    
    // Add user information if available
    if (userProfile != null) {
      buffer.writeln('Account Information:');
      buffer.writeln('• Email: ${userProfile.email}');
      
      if (userProfile.displayName != null) {
        buffer.writeln('• Name: ${userProfile.displayName}');
      }
      
      if (userProfile.businessName != null) {
        buffer.writeln('• Business Name: ${userProfile.businessName}');
      }
      
      if (userProfile.organizationName != null) {
        buffer.writeln('• Organization: ${userProfile.organizationName}');
      }
      
      buffer.writeln('• Account Type: ${_getUserTypeDisplay(userProfile.userType)}');
      buffer.writeln('• Verification Status: ${_getVerificationStatusDisplay(userProfile.verificationStatus)}');
      
      if (userProfile.verificationRequestedAt != null) {
        buffer.writeln('• Verification Requested: ${userProfile.verificationRequestedAt!.toIso8601String()}');
      }
      
      if (userProfile.verificationNotes != null) {
        buffer.writeln('• Review Notes: ${userProfile.verificationNotes}');
      }
      
      buffer.writeln('');
    }
    
    // Add additional details if provided
    if (additionalDetails != null && additionalDetails.isNotEmpty) {
      buffer.writeln('Additional Details:');
      buffer.writeln(additionalDetails);
      buffer.writeln('');
    }
    
    buffer.writeln('Thank you for your time and assistance.');
    buffer.writeln('');
    buffer.writeln('Best regards,');
    if (userProfile?.displayName != null) {
      buffer.writeln(userProfile!.displayName);
    }
    
    return buffer.toString();
  }

  /// Convert user type to display string
  static String _getUserTypeDisplay(String userType) {
    switch (userType) {
      case 'vendor':
        return 'Vendor';
      case 'market_organizer':
        return 'Market Organizer';
      case 'shopper':
        return 'Shopper';
      default:
        return userType;
    }
  }

  /// Convert verification status to display string
  static String _getVerificationStatusDisplay(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'Pending Review';
      case VerificationStatus.approved:
        return 'Approved';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  /// Internal method to launch mailto URLs
  static Future<void> _launchMailtoUrl(String mailtoUrl) async {
    try {
      final uri = Uri.parse(mailtoUrl);
      await launchUrl(uri);
    } catch (e) {
      rethrow;
    }
  }
}